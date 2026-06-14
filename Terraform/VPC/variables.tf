variable "aws_region" {
  description = "AWS region where the VPC will be created."
  type        = string
  default     = "ap-south-1"
}

variable "name" {
  description = "Name prefix used for VPC resources."
  type        = string
  default     = "redrose"

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "environment" {
  description = "Environment tag value, for example dev, staging, or prod."
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. If not supplied, Terraform uses this production-safe default."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_count" {
  description = "Number of public subnets to create. Subnets are spread across exactly 3 availability zones."
  type        = number
  default     = 3

  validation {
    condition     = var.public_subnet_count >= 0 && var.public_subnet_count <= 12 && floor(var.public_subnet_count) == var.public_subnet_count
    error_message = "public_subnet_count must be a whole number from 0 to 12."
  }
}

variable "private_subnet_count" {
  description = "Number of private subnets to create. Subnets are spread across exactly 3 availability zones."
  type        = number
  default     = 3

  validation {
    condition     = var.private_subnet_count >= 0 && var.private_subnet_count <= 12 && floor(var.private_subnet_count) == var.private_subnet_count
    error_message = "private_subnet_count must be a whole number from 0 to 12."
  }
}

variable "subnet_newbits" {
  description = "Additional subnet bits for automatic subnet CIDR calculation. With the default /16 VPC and 8 new bits, subnets are /24."
  type        = number
  default     = 8

  validation {
    condition     = var.subnet_newbits >= 1 && var.subnet_newbits <= 12 && floor(var.subnet_newbits) == var.subnet_newbits
    error_message = "subnet_newbits must be a whole number from 1 to 12."
  }
}

variable "enable_nat_gateway" {
  description = "Whether private subnets should route outbound internet traffic through NAT gateways."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all private subnets. Set false for one NAT gateway per AZ when enable_nat_gateway is true."
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Whether to create VPC endpoints."
  type        = bool
  default     = true
}

variable "gateway_vpc_endpoints" {
  description = "Gateway VPC endpoint service short names to create, for example s3 and dynamodb."
  type        = set(string)
  default     = ["s3"]
}

variable "interface_vpc_endpoints" {
  description = "Interface VPC endpoint service short names to create, for example ecr.api, ecr.dkr, logs, sts, ec2, elasticloadbalancing, kms, secretsmanager."
  type        = set(string)
  default     = []
}

variable "vpc_endpoint_private_dns_enabled" {
  description = "Whether private DNS is enabled for interface VPC endpoints."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention in days for VPC flow logs."
  type        = number
  default     = 90
}

variable "flow_log_traffic_type" {
  description = "Traffic type captured by VPC flow logs."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be ACCEPT, REJECT, or ALL."
  }
}

variable "enable_dns_hostnames" {
  description = "Whether DNS hostnames are enabled in the VPC. Keep enabled for EKS and private endpoints."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Whether DNS support is enabled in the VPC. Keep enabled for EKS and private endpoints."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
