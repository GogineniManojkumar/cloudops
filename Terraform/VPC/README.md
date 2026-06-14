# AWS VPC Terraform

Production-oriented Terraform for an AWS VPC with public/private subnets across exactly three availability zones.

## What It Creates

- VPC with DNS support and DNS hostnames enabled
- Public subnets with one shared public route table and an internet gateway
- Private subnets with one shared private route table
- Optional NAT gateway routing for private subnets
- Optional gateway and interface VPC endpoints
- Optional VPC flow logs to CloudWatch Logs
- Consistent default tags and resource `Name` tags
- Outputs for VPC, subnet, route table, NAT, endpoint, and flow log IDs

The configuration is suitable as a base VPC for EKS later: DNS is enabled, three AZs are always selected, and private subnet support is included. EKS-specific discovery tags are intentionally not added.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

To use custom values:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform plan
```

If `vpc_cidr` is not supplied, the default is `10.0.0.0/16`.

## Important Variables

| Variable | Default | Notes |
| --- | --- | --- |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `public_subnet_count` | `3` | Public subnet CIDRs are calculated automatically |
| `private_subnet_count` | `3` | Private subnet CIDRs are calculated automatically |
| `subnet_newbits` | `8` | `/16` VPC plus `8` creates `/24` subnets |
| `enable_nat_gateway` | `false` | Opt in because NAT gateways add cost |
| `single_nat_gateway` | `true` | Set `false` for one NAT per AZ |
| `enable_vpc_endpoints` | `false` | Creates selected gateway/interface endpoints |
| `enable_flow_logs` | `false` | Sends VPC flow logs to CloudWatch Logs |

## Notes

- Terraform variables cannot both prompt and have a default. This module chooses defaults for safe unattended use. To force a prompt, remove the default from `vpc_cidr`.
- The module always selects the first three available AZ names in the region.
- For high availability production workloads, set `single_nat_gateway = false`; this creates one NAT gateway in each selected AZ.
- Interface endpoints are placed in private subnets and allow HTTPS from the VPC CIDR.
