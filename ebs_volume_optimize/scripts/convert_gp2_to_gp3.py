#!/usr/bin/env python3
"""Convert gp2 EBS volumes to gp3.

Defaults to dry-run. Pass --execute to make changes.
"""

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


def gp2_baseline_iops(size_gib: int) -> int:
    return min(max(size_gib * 3, 100), 16000)


def discover_gp2_volumes(region: str | None, profile: str | None) -> list[dict[str, Any]]:
    args = ["ec2", "describe-volumes", "--filters", "Name=volume-type,Values=gp2"]
    if region:
        args.extend(["--region", region])
    if profile:
        args.extend(["--profile", profile])
    return run_aws(args).get("Volumes", [])


def describe_selected(volume_ids: list[str], region: str | None, profile: str | None) -> list[dict[str, Any]]:
    args = ["ec2", "describe-volumes", "--volume-ids", *volume_ids]
    if region:
        args.extend(["--region", region])
    if profile:
        args.extend(["--profile", profile])
    return run_aws(args).get("Volumes", [])


def modify_volume(
    volume_id: str,
    region: str | None,
    profile: str | None,
    dry_run: bool,
    iops: int | None,
    throughput: int | None,
) -> None:
    args = ["ec2", "modify-volume", "--volume-id", volume_id, "--volume-type", "gp3"]
    if iops:
        args.extend(["--iops", str(iops)])
    if throughput:
        args.extend(["--throughput", str(throughput)])
    if dry_run:
        args.append("--dry-run")
    if region:
        args.extend(["--region", region])
    if profile:
        args.extend(["--profile", profile])

    label = "DRY-RUN" if dry_run else "CONVERT"
    cmd = ["aws", *args, "--output", "json"]
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("ERROR: aws CLI not found. Install AWS CLI v2 and configure credentials.")
    except subprocess.CalledProcessError as exc:
        if dry_run and "DryRunOperation" in exc.stderr:
            print(f"{label}: {volume_id} would be converted")
            return
        sys.stderr.write(exc.stderr)
        sys.exit(exc.returncode)
    if result.stdout:
        json.loads(result.stdout)
    print(f"{label}: {volume_id} submitted")


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert gp2 EBS volumes to gp3.")
    parser.add_argument("--region", help="AWS region. Uses AWS config default if omitted.")
    parser.add_argument("-p", "--profile", help="AWS profile. Uses AWS config default or AWS_PROFILE if omitted.")
    parser.add_argument("--volume-id", action="append", dest="volume_ids", help="Volume ID to convert. Repeatable.")
    parser.add_argument("--all-gp2", action="store_true", help="Convert all gp2 volumes in the region.")
    parser.add_argument("--execute", action="store_true", help="Actually modify volumes. Default is dry-run.")
    parser.add_argument(
        "--preserve-gp2-iops",
        action="store_true",
        help="Set gp3 IOPS to gp2 baseline when gp2 baseline is above gp3 default 3000.",
    )
    parser.add_argument("--throughput", type=int, help="Optional gp3 throughput in MiB/s, 125-1000.")
    args = parser.parse_args()

    if not args.all_gp2 and not args.volume_ids:
        sys.exit("ERROR: provide --volume-id vol-... or --all-gp2")

    volumes = discover_gp2_volumes(args.region, args.profile) if args.all_gp2 else describe_selected(args.volume_ids, args.region, args.profile)
    gp2_volumes = [vol for vol in volumes if vol.get("VolumeType") == "gp2"]
    if not gp2_volumes:
        print("No gp2 volumes selected.")
        return

    dry_run = not args.execute
    for vol in gp2_volumes:
        iops = None
        if args.preserve_gp2_iops:
            baseline = gp2_baseline_iops(int(vol["Size"]))
            if baseline > 3000:
                iops = baseline
        modify_volume(vol["VolumeId"], args.region, args.profile, dry_run, iops, args.throughput)

    if dry_run:
        print("\nDry-run only. Re-run with --execute to convert.")


if __name__ == "__main__":
    main()
