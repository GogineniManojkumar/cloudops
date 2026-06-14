output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Private EKS Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded cluster certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Custom cluster security group ID."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Custom node security group ID."
  value       = aws_security_group.nodes.id
}

output "cluster_iam_role_arn" {
  description = "Custom EKS control plane IAM role ARN."
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arns" {
  description = "Custom IAM role ARNs for managed node groups."
  value       = { for name, role in aws_iam_role.node : name => role.arn }
}

output "oidc_provider" {
  description = "EKS OIDC provider issuer URL for IRSA."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "irsa_role_arns" {
  description = "IRSA IAM role ARNs keyed by role name."
  value       = { for name, role in aws_iam_role.irsa : name => role.arn }
}

output "eks_managed_node_groups" {
  description = "EKS managed node group metadata."
  value       = { for name, node_group in aws_eks_node_group.this : name => node_group }
}
