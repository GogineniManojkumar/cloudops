#!/usr/bin/env python3
"""Check EBS volume modification status after gp2 to gp3 conversion."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from typing import Any


def run_aws(args: list[str]) -> Any:
    cmd = ["aws", *args, "--output", "json"]
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("ERROR: aws CLI not found. Install AWS CLI v2 and configure credentials.")
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr)
        sys.exit(exc.returncode)
    return json.loads(result.stdout or "{}")


def list_regions(profile: str | None) -> list[str]:
    args = ["ec2", "describe-regions", "--query", "Regions[].RegionName"]
    if profile:
        args.extend(["--profile", profile])
    return sorted(run_aws(args))


def print_table(rows: list[dict[str, Any]]) -> None:
    if not rows:
        print("No matching volume modification records found.")
        return
    headers = [
        "volume_id",
        "region",
        "modification_state",
        "progress",
        "original_type",
        "target_type",
        "target_iops",
        "target_throughput",
        "start_time",
        "end_time",
    ]
    widths = {h: max(len(h), *(len(str(row.get(h, ""))) for row in rows)) for h in headers}
    print("  ".join(h.ljust(widths[h]) for h in headers))
    print("  ".join("-" * widths[h] for h in headers))
    for row in rows:
        print("  ".join(str(row.get(h, "")).ljust(widths[h]) for h in headers))


def main() -> None:
    parser = argparse.ArgumentParser(description="Check EBS volume modification status.")
    parser.add_argument("--region", help="AWS region. Uses AWS config default if omitted.")
    parser.add_argument("--all-regions", action="store_true", help="Check every enabled AWS region.")
    parser.add_argument("-p", "--profile", help="AWS profile. Uses AWS config default or AWS_PROFILE if omitted.")
    parser.add_argument("--volume-id", action="append", dest="volume_ids", help="Volume ID to check. Repeatable.")
    args = parser.parse_args()

    if args.all_regions and args.region:
        sys.exit("ERROR: use either --region or --all-regions, not both")

    rows = []
    regions = list_regions(args.profile) if args.all_regions else [args.region]
    for region in regions:
        aws_args = ["ec2", "describe-volumes-modifications"]
        if args.volume_ids:
            aws_args.extend(["--volume-ids", *args.volume_ids])
        if region:
            aws_args.extend(["--region", region])
        if args.profile:
            aws_args.extend(["--profile", args.profile])

        data = run_aws(aws_args)
        for item in data.get("VolumesModifications", []):
            rows.append(
                {
                    "volume_id": item.get("VolumeId", ""),
                    "region": region or "",
                    "modification_state": item.get("ModificationState", ""),
                    "progress": item.get("Progress", ""),
                    "original_type": item.get("OriginalVolumeType", ""),
                    "target_type": item.get("TargetVolumeType", ""),
                    "target_iops": item.get("TargetIops", ""),
                    "target_throughput": item.get("TargetThroughput", ""),
                    "start_time": item.get("StartTime", ""),
                    "end_time": item.get("EndTime", ""),
                }
            )
    print_table(rows)


if __name__ == "__main__":
    main()
