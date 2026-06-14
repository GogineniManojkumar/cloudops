variable "aws_region" {
  description = "AWS region where the EKS cluster will be created."
  type        = string
}

variable "project" {
  description = "Project name used for naming and tagging resources."
  type        = string
}

variable "environment" {
  description = "Environment name used for naming and tagging resources."
  type        = string
}

variable "cluster_name" {
  description = "Short cluster name suffix."
  type        = string
  default     = "eks"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID where the cluster and node groups will run."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes."
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Optional private subnet IDs for the EKS control plane ENIs. Defaults to private_subnet_ids."
  type        = list(string)
  default     = []
}

variable "cluster_endpoint_private_access" {
  description = "Whether the Kubernetes API private endpoint is enabled."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Whether the Kubernetes API public endpoint is enabled. Production default is private-only."
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint when public access is enabled."
  type        = list(string)
  default     = []
}

variable "cluster_endpoint_private_access_cidrs" {
  description = "Trusted private CIDR blocks allowed to reach the custom cluster security group on TCP/443."
  type        = list(string)
  default     = []
}

variable "cluster_egress_cidr_blocks" {
  description = "CIDR blocks for control plane egress."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_egress_cidr_blocks" {
  description = "CIDR blocks for worker node egress."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_cluster_security_group_rules" {
  description = "Additional ingress rules for the custom cluster security group."
  type = map(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = {}
}

variable "additional_node_security_group_rules" {
  description = "Additional ingress rules for the custom node security group."
  type = map(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = {}
}

variable "authentication_mode" {
  description = "EKS access authentication mode. API is preferred for modern clusters."
  type        = string
  default     = "API"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be CONFIG_MAP, API, or API_AND_CONFIG_MAP."
  }
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the Terraform caller cluster-admin access through an EKS access entry."
  type        = bool
  default     = true
}

variable "access_entries" {
  description = "Additional EKS access entries keyed by friendly name."
  type        = any
  default     = {}
}

variable "cluster_enabled_log_types" {
  description = "EKS control plane log types to send to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "CloudWatch log retention for EKS control plane logs."
  type        = number
  default     = 90
}

variable "create_kms_key" {
  description = "Create a KMS key for Kubernetes secret envelope encryption."
  type        = bool
  default     = true
}

variable "cluster_encryption_key_arn" {
  description = "Existing KMS key ARN for secret encryption when create_kms_key is false."
  type        = string
  default     = null
}

variable "kms_key_deletion_window_in_days" {
  description = "KMS key deletion window for the module-created key."
  type        = number
  default     = 30
}

variable "cluster_addons" {
  description = "EKS managed add-ons."
  type        = any
  default = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = null
      configuration_values     = "{\"env\":{\"ENABLE_PREFIX_DELEGATION\":\"true\",\"WARM_PREFIX_TARGET\":\"1\"}}"
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}

variable "eks_managed_node_group_defaults" {
  description = "Defaults merged into every EKS managed node group."
  type        = any
  default     = {}
}

variable "eks_managed_node_groups" {
  description = "EKS managed node groups keyed by node group name."
  type        = any
  default = {
    system = {
      name           = "system"
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      labels = {
        workload = "system"
      }
      taints = {
        critical = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
    general = {
      name           = "general"
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      instance_types = ["m6i.large", "m6a.large", "m5.large"]
      capacity_type  = "SPOT"
      labels = {
        workload = "general"
      }
    }
  }
}

variable "additional_node_role_policy_arns" {
  description = "Additional IAM policy ARNs attached to every node group role."
  type        = list(string)
  default     = []
}

variable "irsa_roles" {
  description = "IRSA roles to create, keyed by friendly name."
  type = map(object({
    namespace            = string
    service_account_name = string
    policy_arns          = list(string)
  }))
  default = {}
}

variable "tags" {
  description = "Additional tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
