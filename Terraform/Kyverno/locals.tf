locals {
  policy_template_vars = {
    validation_failure_action        = var.policy_validation_failure_action
    excluded_namespaces              = var.excluded_namespaces
    excluded_namespace_names         = var.excluded_namespace_names
    allowed_namespace_environments   = join(" | ", var.allowed_namespace_environments)
    approved_image_registries        = join(" | ", var.approved_image_registries)
    loadbalancer_approval_annotation = var.loadbalancer_approval_annotation
    blocked_ingress_hosts            = var.blocked_ingress_hosts
    required_pod_labels              = var.required_pod_labels
    generate_policy_synchronize      = var.generate_policy_synchronize
    default_resource_quota           = var.default_resource_quota
    default_limit_range              = var.default_limit_range
  }

  policy_template_files = {
    namespace_guardrails           = "${path.module}/policy-templates/namespace-guardrails.yaml.tftpl"
    pod_security_restricted        = "${path.module}/policy-templates/pod-security-restricted.yaml.tftpl"
    service_and_ingress_guardrails = "${path.module}/policy-templates/service-and-ingress-guardrails.yaml.tftpl"
    workload_hardening             = "${path.module}/policy-templates/workload-hardening.yaml.tftpl"
    namespace_generators           = "${path.module}/policy-templates/namespace-generators.yaml.tftpl"
  }

  rendered_policies = {
    for name, template_path in local.policy_template_files :
    name => yamldecode(templatefile(template_path, local.policy_template_vars))
  }
}

