# AWS VPC Terraform Design Document

## Overview

This Terraform configuration provisions a production-ready AWS VPC foundation. It creates a VPC with public and private subnets across three availability zones, internet access for public workloads, optional outbound internet access for private workloads through NAT Gateway, optional VPC endpoints, optional VPC flow logs, and consistent tagging across supported resources.

The design is suitable as a base network for future EKS usage because it keeps DNS support enabled, uses three availability zones, supports private subnets, and provides optional endpoints for common AWS services. EKS-specific subnet tags are intentionally not included yet, so the VPC can remain generic until an EKS cluster is added.

## Architecture

The module always selects three available AWS availability zones in the configured region. Public and private subnet CIDR ranges are calculated automatically from the VPC CIDR using Terraform's `cidrsubnet` function.

By default, the VPC CIDR is:

```hcl
10.0.0.0/16
```

With the default `subnet_newbits = 8`, each subnet becomes a `/24`. For example, if the VPC CIDR is `10.20.0.0/16`, Terraform can automatically allocate subnet CIDRs such as:

```text
Public subnet 1   10.20.0.0/24
Public subnet 2   10.20.1.0/24
Public subnet 3   10.20.2.0/24
Private subnet 1  10.20.3.0/24
Private subnet 2  10.20.4.0/24
Private subnet 3  10.20.5.0/24
```

Actual subnet assignment depends on the values of `public_subnet_count`, `private_subnet_count`, `vpc_cidr`, and `subnet_newbits`.

## Resources Created

The configuration creates the following core resources:

- AWS VPC with DNS support and DNS hostnames enabled
- Three selected availability zones
- Public subnets with public IP assignment enabled
- Private subnets with public IP assignment disabled
- Internet Gateway for public internet access
- One public route table shared by all public subnets
- One private route table by default, or one private route table per AZ when high-availability NAT is selected
- Optional NAT Gateway and Elastic IP resources
- Optional gateway VPC endpoints such as S3
- Optional interface VPC endpoints such as ECR, CloudWatch Logs, and STS
- Optional security group for interface VPC endpoints
- Optional CloudWatch Log Group, IAM Role, IAM Policy, and VPC Flow Log
- Guard resources using Terraform preconditions for safer validation

## Routing Design

Public subnets are associated with one public route table. This route table sends `0.0.0.0/0` traffic to the Internet Gateway.

Private subnets are associated with private route tables. NAT routing is not enabled by default because NAT Gateway has hourly and data-processing cost. When `enable_nat_gateway = true`, private subnet outbound internet access is enabled.

There are two NAT modes:

```hcl
enable_nat_gateway = true
single_nat_gateway = true
```

This creates one NAT Gateway and routes all private subnet outbound internet traffic through it. This is cheaper but less highly available.

```hcl
enable_nat_gateway = true
single_nat_gateway = false
```

This creates one NAT Gateway per selected AZ and private route tables are mapped by AZ. This is preferred for production high availability, but it costs more.

## VPC Endpoints

VPC endpoints can be enabled with:

```hcl
enable_vpc_endpoints = true
```

Gateway endpoints are used for services such as S3 and DynamoDB. The default gateway endpoint list includes S3:

```hcl
gateway_vpc_endpoints = ["s3"]
```

Interface endpoints can be added for services that benefit from private connectivity. Common examples for EKS or container workloads are:

```hcl
interface_vpc_endpoints = [
  "ecr.api",
  "ecr.dkr",
  "logs",
  "sts"
]
```

Interface endpoints are created in private subnets and use a security group that allows HTTPS traffic from the VPC CIDR.

## Flow Logs

VPC flow logs are optional and disabled by default:

```hcl
enable_flow_logs = false
```

When enabled, Terraform creates a CloudWatch Log Group, IAM Role, IAM policy, and VPC Flow Log. The default flow log traffic type is `ALL`, and the default retention period is 90 days.

```hcl
enable_flow_logs        = true
flow_log_traffic_type   = "ALL"
flow_log_retention_days = 90
```

Flow logs are useful for security investigations, network troubleshooting, and compliance evidence.

## Tagging Strategy

The provider applies default tags to supported resources:

```hcl
Project     = var.name
Environment = var.environment
ManagedBy   = "terraform"
Terraform   = "true"
```

Additional tags can be supplied using:

```hcl
additional_tags = {
  Owner      = "platform"
  CostCenter = "shared"
}
```

Each major resource also receives a meaningful `Name` tag based on the configured `name` and `environment` values.

## Important Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `aws_region` | `ap-south-1` | AWS region for deployment |
| `name` | `redrose` | Name prefix for VPC resources |
| `environment` | `prod` | Environment tag value |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `public_subnet_count` | `3` | Number of public subnets |
| `private_subnet_count` | `3` | Number of private subnets |
| `subnet_newbits` | `8` | Controls calculated subnet size |
| `enable_nat_gateway` | `false` | Enables private outbound internet through NAT |
| `single_nat_gateway` | `true` | Uses one NAT Gateway instead of one per AZ |
| `enable_vpc_endpoints` | `true` | Enables selected VPC endpoints |
| `enable_flow_logs` | `false` | Enables VPC flow logs |

## Example Configuration

Create a `terraform.tfvars` file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Example production-style values:

```hcl
aws_region  = "us-east-1"
name        = "sample"
environment = "prod"

vpc_cidr             = "10.20.0.0/16"
public_subnet_count  = 3
private_subnet_count = 3
subnet_newbits       = 8

enable_nat_gateway = true
single_nat_gateway = false

enable_vpc_endpoints = true
gateway_vpc_endpoints = [
  "s3"
]
interface_vpc_endpoints = [
  "ecr.api",
  "ecr.dkr",
  "logs",
  "sts"
]

enable_flow_logs        = true
flow_log_retention_days = 90

additional_tags = {
  Owner      = "platform"
  CostCenter = "shared"
}
```

## Deployment Steps

Initialize Terraform:

```bash
terraform init
```

Review the execution plan:

```bash
terraform plan
```

Apply the changes:

```bash
terraform apply
```

Destroy the VPC when it is no longer needed:

```bash
terraform destroy
```

## Validation and Safety

The configuration includes validation rules and preconditions for common mistakes:

- VPC CIDR must be valid
- Public and private subnet counts must be whole numbers between 0 and 12
- Total subnet count must fit inside the selected `subnet_newbits`
- NAT Gateway requires at least one public subnet
- One NAT Gateway per AZ requires at least three public subnets
- Interface VPC endpoints require at least one private subnet
- Flow log traffic type must be `ACCEPT`, `REJECT`, or `ALL`

## Best Practice Notes

For cost-sensitive environments, keep `enable_nat_gateway = false` or use `single_nat_gateway = true`. For production high availability, use `single_nat_gateway = false`.

For private workloads such as EKS nodes, prefer private subnets and enable the AWS service endpoints required by the workload. This reduces dependency on NAT Gateway for AWS API traffic.

Keep DNS support and DNS hostnames enabled. Many AWS services, private endpoints, and future EKS workloads depend on these settings.

Commit `.terraform.lock.hcl` so provider versions remain reproducible. Do not commit `.terraform/`, state files, or real `.tfvars` files containing environment-specific or sensitive values.
