variable "aws_region" {
  description = "AWS region where the existing EKS cluster is running."
  type        = string
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster."
  type        = string
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace for Karpenter."
  type        = string
  default     = "kube-system"
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version. Check https://karpenter.sh/docs/ before upgrading."
  type        = string
  default     = "1.13.0"
}

variable "enable_irsa" {
  description = "Create an IAM role for the Karpenter service account using the cluster OIDC provider."
  type        = bool
  default     = true
}

variable "existing_karpenter_controller_role_arn" {
  description = "Existing IAM role ARN for the Karpenter service account. Used when enable_irsa is false."
  type        = string
  default     = null
}

variable "node_role_auth_mode" {
  description = "How Karpenter node IAM role is authorized to join EKS. Valid values: access_entry, aws_auth_configmap, none."
  type        = string
  default     = "access_entry"

  validation {
    condition     = contains(["access_entry", "aws_auth_configmap", "none"], var.node_role_auth_mode)
    error_message = "node_role_auth_mode must be one of: access_entry, aws_auth_configmap, none."
  }
}

variable "cluster_primary_security_group_tags" {
  description = "Tags to add to the EKS cluster primary security group so EC2NodeClass can discover it."
  type        = map(string)
  default     = {}
}

variable "subnet_selector_tags" {
  description = "Tags used by EC2NodeClass to discover private subnets for Karpenter nodes. Defaults to karpenter.sh/discovery=<cluster_name>."
  type        = map(string)
  default     = null
}

variable "security_group_selector_tags" {
  description = "Tags used by EC2NodeClass to discover node security groups. Defaults to karpenter.sh/discovery=<cluster_name>."
  type        = map(string)
  default     = null
}

variable "ami_alias" {
  description = "AMI alias for EC2NodeClass. Use al2023@latest for quick starts, or pin an alias such as al2023@v20260203 for production."
  type        = string
  default     = "al2023@latest"
}

variable "capacity_types" {
  description = "Allowed Karpenter capacity types."
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "instance_categories" {
  description = "Allowed EC2 instance categories for the default NodePool."
  type        = list(string)
  default     = ["c", "m", "r"]
}

variable "instance_generation_gt" {
  description = "Minimum EC2 instance generation, exclusive."
  type        = string
  default     = "2"
}

variable "nodepool_cpu_limit" {
  description = "Total CPU limit for the default Karpenter NodePool."
  type        = string
  default     = "1000"
}

variable "node_expire_after" {
  description = "Maximum lifetime for Karpenter nodes."
  type        = string
  default     = "720h"
}

variable "consolidate_after" {
  description = "How long Karpenter waits before consolidating empty or underutilized nodes."
  type        = string
  default     = "1m"
}

variable "controller_cpu_request" {
  description = "CPU request for the Karpenter controller."
  type        = string
  default     = "1"
}

variable "controller_memory_request" {
  description = "Memory request for the Karpenter controller."
  type        = string
  default     = "1Gi"
}

variable "controller_cpu_limit" {
  description = "CPU limit for the Karpenter controller."
  type        = string
  default     = "1"
}

variable "controller_memory_limit" {
  description = "Memory limit for the Karpenter controller."
  type        = string
  default     = "1Gi"
}

variable "enable_zonal_shift" {
  description = "Pass settings.enableZonalShift to Karpenter."
  type        = bool
  default     = false
}
