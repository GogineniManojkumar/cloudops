resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = var.kyverno_namespace
  }
}

resource "helm_release" "kyverno" {
  name       = "kyverno"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = var.kyverno_chart_version

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 600

  values = [
    yamlencode(var.kyverno_values)
  ]
}

resource "kubernetes_manifest" "cluster_security_policies" {
  for_each = local.rendered_policies

  manifest = each.value

  depends_on = [
    helm_release.kyverno
  ]
}

