locals {
  base_values = {
    server = {
      service = {
        type = var.service_type
      }

      ingress = {
        enabled          = var.enable_ingress
        ingressClassName = var.ingress_class_name
        hosts            = var.server_host == null ? [] : [var.server_host]
        tls = var.tls_secret_name == null || var.server_host == null ? [] : [
          {
            secretName = var.tls_secret_name
            hosts      = [var.server_host]
          }
        ]
      }
    }

    configs = {
      params = {
        "server.insecure" = var.enable_ingress
      }
      cm = var.server_host == null ? {} : {
        url = "https://${var.server_host}"
      }
      secret = var.admin_password_bcrypt == null ? {} : {
        argocdServerAdminPassword      = var.admin_password_bcrypt
        argocdServerAdminPasswordMtime = var.admin_password_mtime
      }
    }
  }
}

resource "helm_release" "argocd" {
  name             = var.release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = var.create_namespace
  atomic           = true
  cleanup_on_fail  = true
  timeout          = var.timeout

  values = [
    yamlencode(local.base_values),
    yamlencode(var.values)
  ]

  dynamic "set" {
    for_each = var.set_values

    content {
      name  = set.value.name
      value = set.value.value
      type  = set.value.type
    }
  }
}
