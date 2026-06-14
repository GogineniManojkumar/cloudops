resource "aws_iam_role" "cluster" {
  name                  = "${local.name}-cluster-role"
  description           = "Custom IAM role for the ${local.name} EKS control plane."
  assume_role_policy    = data.aws_iam_policy_document.eks_cluster_assume_role.json
  force_detach_policies = true

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
  ])

  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

resource "aws_iam_role" "node" {
  for_each = var.eks_managed_node_groups

  name                  = "${local.name}-${each.key}-node-role"
  description           = "Custom IAM role for the ${local.name} ${each.key} EKS managed node group."
  assume_role_policy    = data.aws_iam_policy_document.eks_node_assume_role.json
  force_detach_policies = true

  tags = merge(local.tags, {
    NodeGroup = each.key
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = {
    for attachment in flatten([
      for node_group_name in keys(var.eks_managed_node_groups) : [
        for policy_arn in local.node_role_policy_arns : {
          key             = "${node_group_name}-${basename(policy_arn)}"
          node_group_name = node_group_name
          policy_arn      = policy_arn
        }
      ]
    ]) : attachment.key => attachment
  }

  role       = aws_iam_role.node[each.value.node_group_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_policy" "cluster_envelope_encryption" {
  count = var.create_kms_key ? 0 : 1

  name        = "${local.name}-cluster-envelope-encryption"
  description = "Allows the EKS control plane to use the supplied KMS key for Kubernetes secret encryption."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.cluster_encryption_key_arn
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster_envelope_encryption" {
  count = var.create_kms_key ? 0 : 1

  role       = aws_iam_role.cluster.name
  policy_arn = aws_iam_policy.cluster_envelope_encryption[0].arn
}
