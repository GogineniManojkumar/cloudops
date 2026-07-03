variable "kubeconfig_path" {
  description = "Path to the kubeconfig file Terraform should use."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubeconfig context for the target cluster. Set to null to use the current context."
  type        = string
  default     = null
}

variable "kyverno_namespace" {
  description = "Namespace where Kyverno will be installed."
  type        = string
  default     = "kyverno"
}

variable "kyverno_chart_version" {
  description = "Kyverno Helm chart version. Set to null to use the latest chart available from the repo."
  type        = string
  default     = null
}

variable "kyverno_values" {
  description = "Additional Helm values for the Kyverno chart."
  type        = any
  default = {
    admissionController = {
      replicas = 2
    }
    backgroundController = {
      replicas = 2
    }
    cleanupController = {
      replicas = 1
    }
    reportsController = {
      replicas = 1
    }
  }
}

variable "policy_validation_failure_action" {
  description = "Kyverno validation action for generated policies. Use Audit first if you are introducing these to an existing cluster."
  type        = string
  default     = "Enforce"

  validation {
    condition     = contains(["Audit", "Enforce"], var.policy_validation_failure_action)
    error_message = "policy_validation_failure_action must be Audit or Enforce."
  }
}

variable "excluded_namespaces" {
  description = "Namespaces excluded from workload, service, and ingress policy enforcement."
  type        = list(string)
  default = [
    "kube-system",
    "kube-public",
    "kube-node-lease",
    "kyverno",
  ]
}

variable "excluded_namespace_names" {
  description = "Namespace objects excluded from namespace label guardrails."
  type        = list(string)
  default = [
    "default",
    "kube-system",
    "kube-public",
    "kube-node-lease",
    "kyverno",
  ]
}

variable "allowed_namespace_environments" {
  description = "Allowed values for the namespace environment label."
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "approved_image_registries" {
  description = "Kyverno image patterns allowed by the approved registry policy."
  type        = list(string)
  default = [
    "*.dkr.ecr.*.amazonaws.com/*",
    "public.ecr.aws/*",
  ]
}

variable "loadbalancer_approval_annotation" {
  description = "Annotation required to allow Service resources of type LoadBalancer."
  type        = string
  default     = "security.example.com/exposure-approved"
}

variable "blocked_ingress_hosts" {
  description = "Ingress host values that are denied."
  type        = list(string)
  default = [
    "*.example.com",
    "*",
  ]
}

variable "required_pod_labels" {
  description = "Labels that must be present on Pods for ownership and cost attribution."
  type        = list(string)
  default = [
    "app",
    "team",
  ]
}

variable "generate_policy_synchronize" {
  description = "Whether generated namespace defaults (NetworkPolicy, ResourceQuota, LimitRange) are kept in sync with the policy, overwriting manual edits. Leave false so namespace owners can tune the generated defaults."
  type        = bool
  default     = false
}

variable "default_resource_quota" {
  description = "Hard limits applied via a generated ResourceQuota in every non-excluded namespace."
  type        = map(string)
  default = {
    "requests.cpu"    = "4"
    "requests.memory" = "8Gi"
    "limits.cpu"      = "8"
    "limits.memory"   = "16Gi"
    "pods"            = "50"
  }
}

variable "default_limit_range" {
  description = "Default container CPU/memory request and limit values applied via a generated LimitRange in every non-excluded namespace."
  type = object({
    default_cpu            = string
    default_memory         = string
    default_request_cpu    = string
    default_request_memory = string
  })
  default = {
    default_cpu            = "500m"
    default_memory         = "512Mi"
    default_request_cpu    = "100m"
    default_request_memory = "128Mi"
  }
}
