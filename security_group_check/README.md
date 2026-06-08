# AWS Security Group Usage Scanner

A small command-line tool to find AWS resources that are using a given security group.

## What it does
- Scans AWS resources across one or all enabled regions
- Checks common services for security group attachments
- Prints results as a table, JSON, or simple text
- Optionally writes output to a file

## Key features
- Supports EC2 network interfaces, load balancers, RDS, Lambda, ElastiCache, Redshift, EFS, OpenSearch, MSK, and ECS
- Uses AWS SDK credentials/profile chain
- Simple CLI with optional region and service filtering

## Requirements
- Python 3
- `boto3`
- `rich`

Install dependencies:

```bash
pip install -r requirements.txt
```

## Quick start

```bash
python sg_usage_scan.py --sg-id sg-0123456789abcdef0 --region us-east-1
```

## Output modes
- `--format table` (default) for a rich summary table
- `--format json` for structured JSON output
- `--format txt` for plain text output

## Notes
- Use `--all-regions` to scan all enabled AWS regions
- Use `--profile` to select an AWS CLI profile
- Use `--services` to limit scanning to selected service groups
