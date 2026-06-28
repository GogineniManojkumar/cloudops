output "release_name" {
  description = "Name of the Argo CD Helm release."
  value       = helm_release.argocd.name
}

output "namespace" {
  description = "Namespace where Argo CD is installed."
  value       = helm_release.argocd.namespace
}

output "chart_version" {
  description = "Installed Argo CD chart version."
  value       = helm_release.argocd.version
}

output "server_url" {
  description = "Argo CD server URL when server_host is provided."
  value       = var.server_host == null ? null : "https://${var.server_host}"
}

output "admin_initial_password_command" {
  description = "Command to read the generated initial admin password when admin_password_bcrypt is not set."
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
