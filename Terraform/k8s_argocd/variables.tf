variable "cluster_host" {
  description = "Kubernetes API server endpoint, for example https://example.gr7.us-east-1.eks.amazonaws.com."
  type        = string
}

variable "cluster_token" {
  description = "Bearer token used to authenticate with the Kubernetes API server."
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded Kubernetes cluster CA certificate. Leave null only when your cluster endpoint uses publicly trusted TLS."
  type        = string
  default     = null
  sensitive   = true
}

variable "namespace" {
  description = "Kubernetes namespace where Argo CD will be installed."
  type        = string
  default     = "argocd"
}

variable "create_namespace" {
  description = "Whether the Helm release should create the namespace."
  type        = bool
  default     = true
}

variable "release_name" {
  description = "Helm release name for Argo CD."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the argo-cd Helm chart to install. Leave null to let Helm use the latest available chart at apply time."
  type        = string
  default     = null
}

variable "service_type" {
  description = "Kubernetes service type for the Argo CD API server."
  type        = string
  default     = "ClusterIP"

  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "service_type must be one of ClusterIP, NodePort, or LoadBalancer."
  }
}

variable "server_host" {
  description = "Optional hostname for Argo CD ingress and server URL, for example argocd.example.com."
  type        = string
  default     = null
}

variable "enable_ingress" {
  description = "Whether to enable ingress for the Argo CD API server."
  type        = bool
  default     = false
}

variable "ingress_class_name" {
  description = "Ingress class name to use when ingress is enabled."
  type        = string
  default     = "nginx"
}

variable "tls_secret_name" {
  description = "Optional TLS secret name for Argo CD ingress."
  type        = string
  default     = null
}

variable "admin_password_bcrypt" {
  description = "Optional bcrypt hash for the initial Argo CD admin password. Generate with `argocd account bcrypt --password <password>`."
  type        = string
  default     = null
  sensitive   = true
}

variable "admin_password_mtime" {
  description = "Password modification timestamp used by Argo CD when admin_password_bcrypt is set."
  type        = string
  default     = "2026-01-01T00:00:00Z"
}

variable "values" {
  description = "Additional Helm values to merge into the Argo CD chart values."
  type        = any
  default     = {}
}

variable "set_values" {
  description = "Additional Helm set values. Use this for simple scalar overrides."
  type = list(object({
    name  = string
    value = string
    type  = optional(string, "auto")
  }))
  default = []
}

variable "timeout" {
  description = "Time in seconds to wait for the Helm release to become ready."
  type        = number
  default     = 600
}
