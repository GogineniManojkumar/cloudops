resource "helm_release" "karpenter_crd" {
  name                = "karpenter-crd"
  namespace           = var.karpenter_namespace
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter-crd"
  version             = var.karpenter_chart_version
  create_namespace    = true
  wait                = true
  atomic              = true
  repository_username = ""
  repository_password = ""
}

resource "helm_release" "karpenter" {
  name                = "karpenter"
  namespace           = var.karpenter_namespace
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = var.karpenter_chart_version
  create_namespace    = true
  wait                = true
  atomic              = true
  repository_username = ""
  repository_password = ""

  values = [
    yamlencode({
      serviceAccount = {
        annotations = local.controller_role_arn == null ? {} : {
          "eks.amazonaws.com/role-arn" = local.controller_role_arn
        }
      }
      settings = {
        clusterName       = var.cluster_name
        interruptionQueue = aws_sqs_queue.karpenter_interruption.name
        enableZonalShift  = var.enable_zonal_shift
      }
      controller = {
        resources = {
          requests = {
            cpu    = var.controller_cpu_request
            memory = var.controller_memory_request
          }
          limits = {
            cpu    = var.controller_cpu_limit
            memory = var.controller_memory_limit
          }
        }
      }
    })
  ]

  depends_on = [
    helm_release.karpenter_crd,
    aws_iam_role_policy_attachment.karpenter_controller,
    aws_iam_role_policy_attachment.karpenter_node,
  ]
}
