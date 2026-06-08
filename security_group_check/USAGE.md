# Usage

## Basic command

```bash
python sg_usage_scan.py --sg-id <security-group-id> --region <region>
```

Example:

```bash
python sg_usage_scan.py --sg-id sg-0abc123def456ghij --region us-east-1
```

## Scan all enabled regions

```bash
python sg_usage_scan.py --sg-id sg-0abc123def456ghij --all-regions
```

## Use a specific AWS profile

```bash
python sg_usage_scan.py --sg-id sg-0abc123def456ghij --region us-east-1 --profile my-profile
```

## Set output format

```bash
python sg_usage_scan.py --sg-id sg-0abc123def456ghij --region us-east-1 --format json
```

## Write results to a file

```bash
python sg_usage_scan.py --sg-id sg-0abc123def456ghij --region us-east-1 --output-file result.txt
```

If `--output-file` ends with `.json`, the file is written in JSON format.

## Scan only selected services

```bash
python sg_usage_scan.py --sg-id sg-0abc123def456ghij --region us-east-1 --services ec2 elbv2 rds
```

Available services:
- `ec2`
- `elbv2`
- `elb`
- `rds`
- `lambda`
- `elasticache`
- `redshift`
- `efs`
- `opensearch`
- `msk`
- `ecs`

## Logging and verbosity

```bash
python sg_usage_scan.py --sg-id sg-0abc123def456ghij --region us-east-1 --verbose
```

Logs are written by default to `sg-usage-scanner.log`, or you can set a custom path with `--log-file`.
