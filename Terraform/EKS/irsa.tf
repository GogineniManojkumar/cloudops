data "aws_iam_policy_document" "irsa_assume_role" {
  for_each = var.irsa_roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = var.irsa_roles

  name                  = "${local.name}-${each.key}-irsa"
  description           = "IRSA role for ${each.value.namespace}/${each.value.service_account_name} in ${local.name}."
  assume_role_policy    = data.aws_iam_policy_document.irsa_assume_role[each.key].json
  force_detach_policies = true

  tags = merge(local.tags, {
    Namespace      = each.value.namespace
    ServiceAccount = each.value.service_account_name
  })
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = {
    for attachment in flatten([
      for role_name, role in var.irsa_roles : [
        for policy_arn in role.policy_arns : {
          key        = "${role_name}-${basename(policy_arn)}"
          role_name  = role_name
          policy_arn = policy_arn
        }
      ]
    ]) : attachment.key => attachment
  }

  role       = aws_iam_role.irsa[each.value.role_name].name
  policy_arn = each.value.policy_arn
}
