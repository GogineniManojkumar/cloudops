output "kyverno_namespace" {
  description = "Namespace where Kyverno is installed."
  value       = kubernetes_namespace.kyverno.metadata[0].name
}

output "cluster_policy_names" {
  description = "Kyverno ClusterPolicy resources managed by this Terraform configuration."
  value = [
    for policy in kubernetes_manifest.cluster_security_policies :
    policy.manifest.metadata.name
  ]
}

