locals {
  name = "${var.project}-${var.environment}-${var.cluster_name}"

  tags = merge(
    var.tags,
    {
      Project     = var.project
      Environment = var.environment
      Cluster     = local.name
    }
  )

  node_role_policy_arns = distinct(concat(
    [
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
    ],
    var.additional_node_role_policy_arns
  ))

  control_plane_subnet_ids = length(var.control_plane_subnet_ids) > 0 ? var.control_plane_subnet_ids : var.private_subnet_ids

  cluster_encryption_key_arn = var.create_kms_key ? aws_kms_key.cluster[0].arn : var.cluster_encryption_key_arn

  eks_managed_node_groups = {
    for name, config in var.eks_managed_node_groups : name => merge(
      {
        ami_type                          = "AL2_x86_64"
        capacity_type                     = "ON_DEMAND"
        disk_size                         = 50
        force_update_version              = false
        instance_types                    = ["m6i.large"]
        labels                            = {}
        max_size                          = 3
        min_size                          = 1
        desired_size                      = 1
        subnet_ids                        = var.private_subnet_ids
        tags                              = {}
        taints                            = {}
        update_max_unavailable            = null
        update_max_unavailable_percentage = 33
        vpc_security_group_ids            = []
      },
      var.eks_managed_node_group_defaults,
      config,
      {
        vpc_security_group_ids = distinct(concat(
          [aws_security_group.nodes.id],
          try(var.eks_managed_node_group_defaults.vpc_security_group_ids, []),
          try(config.vpc_security_group_ids, [])
        ))
      }
    )
  }

  addon_defaults = {
    addon_version            = null
    before_compute           = false
    configuration_values     = null
    most_recent              = true
    preserve                 = true
    resolve_conflicts_create = "OVERWRITE"
    resolve_conflicts_update = "PRESERVE"
    service_account_role_arn = null
    tags                     = {}
  }

  cluster_addons = {
    for name, config in var.cluster_addons : name => merge(local.addon_defaults, config)
  }

  access_entries = var.access_entries

  access_policy_associations = {
    for association in flatten([
      for entry_name, entry in local.access_entries : [
        for association_name, association in try(entry.policy_associations, {}) : {
          key          = "${entry_name}-${association_name}"
          entry_name   = entry_name
          policy_arn   = association.policy_arn
          access_scope = association.access_scope
        }
      ]
    ]) : association.key => association
  }
}
