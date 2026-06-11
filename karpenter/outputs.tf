output "karpenter_controller_role_arn" {
  description = "IAM role ARN used by the Karpenter controller service account."
  value       = local.controller_role_arn
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN used by EC2 instances launched by Karpenter."
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name configured for Karpenter interruption handling."
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "karpenter_nodepool_name" {
  description = "Default Karpenter NodePool name."
  value       = kubectl_manifest.node_pool_default.name
}
