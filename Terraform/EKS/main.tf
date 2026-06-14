resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.name}/cluster"
  retention_in_days = var.cloudwatch_log_group_retention_in_days

  tags = local.tags
}

resource "aws_eks_cluster" "this" {
  name     = local.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  enabled_cluster_log_types = var.cluster_enabled_log_types

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  }

  encryption_config {
    provider {
      key_arn = local.cluster_encryption_key_arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = local.control_plane_subnet_ids
  }

  tags = local.tags

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy_attachment.cluster_envelope_encryption,
  ]
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(local.tags, {
    Name = "${local.name}-irsa"
  })
}

resource "aws_eks_addon" "before_compute" {
  for_each = {
    for name, addon in local.cluster_addons : name => addon
    if addon.before_compute
  }

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = try(data.aws_eks_addon_version.this[each.key].version, each.value.addon_version)
  configuration_values        = each.value.configuration_values
  preserve                    = each.value.preserve
  resolve_conflicts_on_create = each.value.resolve_conflicts_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_update
  service_account_role_arn    = each.value.service_account_role_arn
  tags                        = merge(local.tags, each.value.tags)
}

resource "aws_launch_template" "node" {
  for_each = local.eks_managed_node_groups

  name_prefix            = "${local.name}-${each.key}-"
  update_default_version = true
  vpc_security_group_ids = each.value.vpc_security_group_ids

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.tags, each.value.tags, {
      Name = "${local.name}-${each.key}"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(local.tags, each.value.tags, {
      Name = "${local.name}-${each.key}"
    })
  }

  tags = merge(local.tags, each.value.tags, {
    Name = "${local.name}-${each.key}-lt"
  })
}

resource "aws_eks_node_group" "this" {
  for_each = local.eks_managed_node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = try(each.value.name, each.key)
  node_role_arn   = aws_iam_role.node[each.key].arn
  subnet_ids      = each.value.subnet_ids

  ami_type             = each.value.ami_type
  capacity_type        = each.value.capacity_type
  force_update_version = each.value.force_update_version
  instance_types       = each.value.instance_types
  labels               = each.value.labels
  version              = try(each.value.version, var.cluster_version)

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable            = each.value.update_max_unavailable
    max_unavailable_percentage = each.value.update_max_unavailable == null ? each.value.update_max_unavailable_percentage : null
  }

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = try(taint.value.value, null)
      effect = taint.value.effect
    }
  }

  tags = merge(local.tags, each.value.tags, {
    Name = "${local.name}-${each.key}"
  })

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }

  depends_on = [
    aws_eks_addon.before_compute,
    aws_iam_role_policy_attachment.node,
    aws_security_group_rule.cluster_ingress_from_nodes,
    aws_security_group_rule.node_ingress_from_cluster,
  ]
}

resource "aws_eks_addon" "after_compute" {
  for_each = {
    for name, addon in local.cluster_addons : name => addon
    if !addon.before_compute
  }

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = try(data.aws_eks_addon_version.this[each.key].version, each.value.addon_version)
  configuration_values        = each.value.configuration_values
  preserve                    = each.value.preserve
  resolve_conflicts_on_create = each.value.resolve_conflicts_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_update
  service_account_role_arn    = each.value.service_account_role_arn
  tags                        = merge(local.tags, each.value.tags)

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_access_entry" "this" {
  for_each = local.access_entries

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  type          = try(each.value.type, "STANDARD")
  user_name     = try(each.value.user_name, null)

  tags = local.tags
}

resource "aws_eks_access_policy_association" "this" {
  for_each = local.access_policy_associations

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.access_entries[each.value.entry_name].principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = try(each.value.access_scope.namespaces, null)
  }

  depends_on = [aws_eks_access_entry.this]
}
