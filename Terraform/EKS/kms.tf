resource "aws_kms_key" "cluster" {
  count = var.create_kms_key ? 1 : 0

  description             = "EKS secret encryption key for ${local.name}"
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms[0].json

  tags = merge(local.tags, {
    Name = "${local.name}-eks-secrets"
  })
}

resource "aws_kms_alias" "cluster" {
  count = var.create_kms_key ? 1 : 0

  name          = "alias/${local.name}-eks-secrets"
  target_key_id = aws_kms_key.cluster[0].key_id
}
