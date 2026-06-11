data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "this" {
  count = var.enable_irsa ? 1 : 0
  url   = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

data "kubernetes_config_map_v1" "aws_auth" {
  count = var.node_role_auth_mode == "aws_auth_configmap" ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

locals {
  account_id              = data.aws_caller_identity.current.account_id
  partition               = data.aws_partition.current.partition
  oidc_provider_arn       = var.enable_irsa ? data.aws_iam_openid_connect_provider.this[0].arn : null
  oidc_provider_url       = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
  discovery_tags          = { "karpenter.sh/discovery" = var.cluster_name }
  subnet_selector_tags    = coalesce(var.subnet_selector_tags, local.discovery_tags)
  security_group_tags     = coalesce(var.security_group_selector_tags, local.discovery_tags)
  controller_role_arn     = var.enable_irsa ? aws_iam_role.karpenter_controller[0].arn : var.existing_karpenter_controller_role_arn
  node_role_name          = "KarpenterNodeRole-${var.cluster_name}"
  interruption_queue_name = var.cluster_name
  existing_auth_map_roles = var.node_role_auth_mode == "aws_auth_configmap" ? try(yamldecode(data.kubernetes_config_map_v1.aws_auth[0].data.mapRoles), []) : []
  node_role_auth_map_roles = yamlencode(concat(local.existing_auth_map_roles, [{
    rolearn  = aws_iam_role.karpenter_node.arn
    username = "system:node:{{EC2PrivateDNSName}}"
    groups   = ["system:bootstrappers", "system:nodes"]
  }]))
}
