# EBS gp2 to gp3 Audit and Conversion

Small AWS CLI based scripts for finding gp2 EBS volumes, estimating gp3 storage savings, converting selected volumes, and checking conversion status.

## Requirements

- AWS CLI v2 installed and configured
- IAM permissions for:
  - `ec2:DescribeVolumes`
  - `ec2:DescribeInstances`
  - `ec2:ModifyVolume`
  - `ec2:DescribeVolumesModifications`
  - `pricing:GetProducts`
  - `ssm:GetParameter`

## Audit gp2 Volumes

```bash
python3 scripts/audit_gp2_volumes.py --region ap-south-1 --csv gp2-audit.csv
```

Use a named AWS profile:

```bash
python3 scripts/audit_gp2_volumes.py --profile prod --region ap-south-1 --csv gp2-audit.csv
```

Scan all enabled regions:

```bash
python3 scripts/audit_gp2_volumes.py --profile prod --all-regions --csv gp2-audit.csv
```

The audit shows volume ID, name, size, status, availability zone, encryption, gp2 baseline IOPS, attached instance ID/name/state/type, device, and estimated yearly storage savings if converted to gp3.

Pricing is pulled dynamically from the AWS Pricing API per region when possible. The script resolves the AWS region code to the Pricing API location name using AWS public SSM region metadata, then fetches gp2 and gp3 storage prices for that location.

If Pricing API or SSM access is unavailable, the script falls back to:

- gp2: `$0.10` per GiB-month
- gp3: `$0.08` per GiB-month

You can skip AWS Pricing API and use fallback/manual pricing:

```bash
python3 scripts/audit_gp2_volumes.py --region ap-south-1 --no-aws-pricing
```

Override pricing manually:

```bash
python3 scripts/audit_gp2_volumes.py --region ap-south-1 --gp2-price 0.114 --gp3-price 0.0912
```

You can also use environment variables:

```bash
GP2_GB_MONTH=0.114 GP3_GB_MONTH=0.0912 python3 scripts/audit_gp2_volumes.py --region ap-south-1
```

## Convert gp2 to gp3

The conversion script is dry-run by default.

```bash
python3 scripts/convert_gp2_to_gp3.py --region ap-south-1 --volume-id vol-0123456789abcdef0
```

With a named profile:

```bash
python3 scripts/convert_gp2_to_gp3.py --profile prod --region ap-south-1 --volume-id vol-0123456789abcdef0
```

Run the real conversion with `--execute`:

```bash
python3 scripts/convert_gp2_to_gp3.py --profile prod --region ap-south-1 --volume-id vol-0123456789abcdef0 --execute
```

Convert every gp2 volume in the selected region:

```bash
python3 scripts/convert_gp2_to_gp3.py --region ap-south-1 --all-gp2 --execute
```

For volumes larger than 1 TiB, gp2 baseline IOPS can be above gp3's default 3000 IOPS. To keep gp3 IOPS at the gp2 baseline when needed:

```bash
python3 scripts/convert_gp2_to_gp3.py --region ap-south-1 --all-gp2 --preserve-gp2-iops --execute
```

## Check Conversion Status

```bash
python3 scripts/check_gp3_conversion_status.py --region ap-south-1
```

With a named profile:

```bash
python3 scripts/check_gp3_conversion_status.py --profile prod --region ap-south-1
```

Check all enabled regions:

```bash
python3 scripts/check_gp3_conversion_status.py --profile prod --all-regions
```

Or for specific volumes:

```bash
python3 scripts/check_gp3_conversion_status.py --region ap-south-1 --volume-id vol-0123456789abcdef0
```

## Notes

- EBS volume modification is online, but validate application performance and snapshot/backup requirements before bulk changes.
- The audit's saving estimate is storage-only. Extra gp3 IOPS or throughput settings can change the final monthly cost.
- Use `--profile PROFILE_NAME` or `-p PROFILE_NAME` on any script if you need a non-default AWS profile. You can also rely on `AWS_PROFILE`.
