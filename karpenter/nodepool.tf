resource "kubectl_manifest" "ec2_node_class_default" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      role = aws_iam_role.karpenter_node.name
      amiSelectorTerms = [{
        alias = var.ami_alias
      }]
      subnetSelectorTerms = [{
        tags = local.subnet_selector_tags
      }]
      securityGroupSelectorTerms = [{
        tags = local.security_group_tags
      }]
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "node_pool_default" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = var.capacity_types
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = var.instance_categories
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = [var.instance_generation_gt]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = kubectl_manifest.ec2_node_class_default.name
          }
          expireAfter = var.node_expire_after
        }
      }
      limits = {
        cpu = var.nodepool_cpu_limit
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = var.consolidate_after
      }
    }
  })

  depends_on = [kubectl_manifest.ec2_node_class_default]
}
