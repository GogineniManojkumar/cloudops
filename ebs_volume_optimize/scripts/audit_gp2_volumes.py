#!/usr/bin/env python3
"""Audit gp2 EBS volumes and estimate gp3 annual storage savings.

Requires AWS CLI v2 configured with credentials. No boto3 dependency.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import subprocess
import sys
from typing import Any


DEFAULT_GP2_GB_MONTH = 0.10
DEFAULT_GP3_GB_MONTH = 0.08
DEFAULT_PRICING_REGION = "us-east-1"


def env_float(name: str) -> float | None:
    value = os.getenv(name)
    if value in {None, ""}:
        return None
    try:
        return float(value)
    except ValueError:
        sys.exit(f"ERROR: {name} must be a number, got {value!r}")


def run_aws(args: list[str]) -> Any:
    cmd = ["aws", *args, "--output", "json"]
    return run_aws_command(cmd)


def run_aws_command(cmd: list[str]) -> Any:
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("ERROR: aws CLI not found. Install AWS CLI v2 and configure credentials.")
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr)
        sys.exit(exc.returncode)
    return json.loads(result.stdout or "{}")


def try_run_aws(args: list[str]) -> Any:
    cmd = ["aws", *args, "--output", "json"]
    try:
        return run_aws_command(cmd)
    except SystemExit as exc:
        raise RuntimeError(f"aws command failed: {' '.join(cmd)}") from exc


def list_regions(profile: str | None) -> list[str]:
    args = ["ec2", "describe-regions", "--query", "Regions[].RegionName"]
    if profile:
        args.extend(["--profile", profile])
    return sorted(run_aws(args))


def region_location(region: str, profile: str | None, pricing_region: str) -> str:
    args = [
        "ssm",
        "get-parameter",
        "--name",
        f"/aws/service/global-infrastructure/regions/{region}/longName",
        "--query",
        "Parameter.Value",
        "--region",
        pricing_region,
    ]
    if profile:
        args.extend(["--profile", profile])
    location = try_run_aws(args)
    if not isinstance(location, str) or not location:
        raise RuntimeError(f"could not resolve pricing location for region {region}")
    return location


def ebs_storage_price(volume_type: str, location: str, profile: str | None, pricing_region: str) -> float:
    args = [
        "pricing",
        "get-products",
        "--service-code",
        "AmazonEC2",
        "--region",
        pricing_region,
        "--filters",
        "Type=TERM_MATCH,Field=productFamily,Value=Storage",
        f"Type=TERM_MATCH,Field=volumeApiName,Value={volume_type}",
        f"Type=TERM_MATCH,Field=location,Value={location}",
    ]
    if profile:
        args.extend(["--profile", profile])

    data = try_run_aws(args)
    for item in data.get("PriceList", []):
        product = json.loads(item) if isinstance(item, str) else item
        for term in product.get("terms", {}).get("OnDemand", {}).values():
            for dimension in term.get("priceDimensions", {}).values():
                unit = dimension.get("unit", "")
                usd = dimension.get("pricePerUnit", {}).get("USD")
                description = dimension.get("description", "").lower()
                if usd is not None and unit in {"GB-Mo", "GB-month"} and "storage" in description:
                    return float(usd)
    raise RuntimeError(f"could not find {volume_type} GB-month price for {location}")


def resolve_prices(
    region: str | None,
    profile: str | None,
    pricing_region: str,
    gp2_price: float | None,
    gp3_price: float | None,
    use_aws_pricing: bool,
) -> tuple[float, float, str]:
    if gp2_price is not None and gp3_price is not None:
        return gp2_price, gp3_price, "manual"

    if not region:
        return (
            gp2_price if gp2_price is not None else DEFAULT_GP2_GB_MONTH,
            gp3_price if gp3_price is not None else DEFAULT_GP3_GB_MONTH,
            "default",
        )

    if use_aws_pricing:
        try:
            location = region_location(region, profile, pricing_region)
            resolved_gp2 = ebs_storage_price("gp2", location, profile, pricing_region)
            resolved_gp3 = ebs_storage_price("gp3", location, profile, pricing_region)
            return (
                gp2_price if gp2_price is not None else resolved_gp2,
                gp3_price if gp3_price is not None else resolved_gp3,
                f"aws-pricing:{location}",
            )
        except RuntimeError as exc:
            print(f"WARNING: {exc}. Falling back to configured/default prices.", file=sys.stderr)

    return (
        gp2_price if gp2_price is not None else DEFAULT_GP2_GB_MONTH,
        gp3_price if gp3_price is not None else DEFAULT_GP3_GB_MONTH,
        "fallback",
    )


def volume_name(tags: list[dict[str, str]] | None) -> str:
    for tag in tags or []:
        if tag.get("Key") == "Name":
            return tag.get("Value", "")
    return ""


def gp2_baseline_iops(size_gib: int) -> int:
    return min(max(size_gib * 3, 100), 16000)


def instance_map(region: str | None, profile: str | None) -> dict[str, dict[str, str]]:
    args = ["ec2", "describe-instances"]
    if region:
        args.extend(["--region", region])
    if profile:
        args.extend(["--profile", profile])
    data = run_aws(args)
    instances: dict[str, dict[str, str]] = {}
    for reservation in data.get("Reservations", []):
        for inst in reservation.get("Instances", []):
            instances[inst["InstanceId"]] = {
                "instance_state": inst.get("State", {}).get("Name", ""),
                "instance_name": volume_name(inst.get("Tags")),
                "instance_type": inst.get("InstanceType", ""),
            }
    return instances


def build_rows(
    region: str | None,
    profile: str | None,
    gp2_price: float,
    gp3_price: float,
    pricing_source: str,
) -> list[dict[str, Any]]:
    args = [
        "ec2",
        "describe-volumes",
        "--filters",
        "Name=volume-type,Values=gp2",
    ]
    if region:
        args.extend(["--region", region])
    if profile:
        args.extend(["--profile", profile])

    volumes = run_aws(args).get("Volumes", [])
    instances = instance_map(region, profile)
    rows: list[dict[str, Any]] = []

    for vol in volumes:
        size = int(vol["Size"])
        gp2_annual = size * gp2_price * 12
        gp3_annual = size * gp3_price * 12
        annual_saving = gp2_annual - gp3_annual
        attachments = vol.get("Attachments", [])
        if attachments:
            for att in attachments:
                instance_id = att.get("InstanceId", "")
                inst = instances.get(instance_id, {})
                rows.append(
                    {
                        "volume_id": vol["VolumeId"],
                        "region": region or "",
                        "name": volume_name(vol.get("Tags")),
                        "size_gib": size,
                        "state": vol.get("State", ""),
                        "az": vol.get("AvailabilityZone", ""),
                        "encrypted": vol.get("Encrypted", False),
                        "gp2_baseline_iops": gp2_baseline_iops(size),
                        "attached_instance_id": instance_id,
                        "attached_instance_name": inst.get("instance_name", ""),
                        "attached_instance_state": inst.get("instance_state", ""),
                        "attached_instance_type": inst.get("instance_type", ""),
                        "device": att.get("Device", ""),
                        "attachment_state": att.get("State", ""),
                        "gp2_annual_usd": round(gp2_annual, 2),
                        "gp3_annual_usd": round(gp3_annual, 2),
                        "gp2_gib_month_usd": gp2_price,
                        "gp3_gib_month_usd": gp3_price,
                        "pricing_source": pricing_source,
                        "estimated_annual_saving_usd": round(annual_saving, 2),
                    }
                )
        else:
            rows.append(
                {
                    "volume_id": vol["VolumeId"],
                    "region": region or "",
                    "name": volume_name(vol.get("Tags")),
                    "size_gib": size,
                    "state": vol.get("State", ""),
                    "az": vol.get("AvailabilityZone", ""),
                    "encrypted": vol.get("Encrypted", False),
                    "gp2_baseline_iops": gp2_baseline_iops(size),
                    "attached_instance_id": "",
                    "attached_instance_name": "",
                    "attached_instance_state": "",
                    "attached_instance_type": "",
                    "device": "",
                    "attachment_state": "",
                    "gp2_annual_usd": round(gp2_annual, 2),
                    "gp3_annual_usd": round(gp3_annual, 2),
                    "gp2_gib_month_usd": gp2_price,
                    "gp3_gib_month_usd": gp3_price,
                    "pricing_source": pricing_source,
                    "estimated_annual_saving_usd": round(annual_saving, 2),
                }
            )
    return rows


def print_table(rows: list[dict[str, Any]]) -> None:
    if not rows:
        print("No gp2 volumes found.")
        return
    headers = [
        "volume_id",
        "region",
        "name",
        "size_gib",
        "state",
        "az",
        "gp2_baseline_iops",
        "attached_instance_id",
        "attached_instance_name",
        "attached_instance_state",
        "device",
        "gp2_gib_month_usd",
        "gp3_gib_month_usd",
        "pricing_source",
        "estimated_annual_saving_usd",
    ]
    widths = {h: max(len(h), *(len(str(row[h])) for row in rows)) for h in headers}
    print("  ".join(h.ljust(widths[h]) for h in headers))
    print("  ".join("-" * widths[h] for h in headers))
    for row in rows:
        print("  ".join(str(row[h]).ljust(widths[h]) for h in headers))
    total = sum(
        float(next(row for row in rows if row["volume_id"] == volume_id)["estimated_annual_saving_usd"])
        for volume_id in {row["volume_id"] for row in rows}
    )
    print(f"\nTotal estimated annual storage saving: ${total:,.2f}")


def write_csv(rows: list[dict[str, Any]], path: str) -> None:
    if not rows:
        return
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit gp2 EBS volumes and estimate gp3 savings.")
    parser.add_argument("--region", help="AWS region. Uses AWS config default if omitted.")
    parser.add_argument("--all-regions", action="store_true", help="Scan every enabled AWS region.")
    parser.add_argument("-p", "--profile", help="AWS profile. Uses AWS config default or AWS_PROFILE if omitted.")
    parser.add_argument("--gp2-price", type=float, default=env_float("GP2_GB_MONTH"), help="Manual gp2 USD per GiB-month override.")
    parser.add_argument("--gp3-price", type=float, default=env_float("GP3_GB_MONTH"), help="Manual gp3 USD per GiB-month override.")
    parser.add_argument("--pricing-region", default=DEFAULT_PRICING_REGION, help="AWS Pricing API region. Default: us-east-1.")
    parser.add_argument("--no-aws-pricing", action="store_true", help="Skip AWS Pricing API and use manual/default prices.")
    parser.add_argument("--csv", help="Optional path to write CSV output.")
    args = parser.parse_args()

    if args.all_regions and args.region:
        sys.exit("ERROR: use either --region or --all-regions, not both")

    regions = list_regions(args.profile) if args.all_regions else [args.region]
    rows: list[dict[str, Any]] = []
    for region in regions:
        gp2_price, gp3_price, pricing_source = resolve_prices(
            region,
            args.profile,
            args.pricing_region,
            args.gp2_price,
            args.gp3_price,
            not args.no_aws_pricing,
        )
        if region:
            print(
                f"Pricing for {region}: gp2=${gp2_price:.5f}/GiB-month, "
                f"gp3=${gp3_price:.5f}/GiB-month ({pricing_source})",
                file=sys.stderr,
            )
        rows.extend(build_rows(region, args.profile, gp2_price, gp3_price, pricing_source))
    print_table(rows)
    if args.csv:
        write_csv(rows, args.csv)
        print(f"Wrote CSV: {args.csv}")


if __name__ == "__main__":
    main()
