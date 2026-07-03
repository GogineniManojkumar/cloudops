# Terraform Kyverno install

This Terraform configuration installs Kyverno with Helm and manages the cluster security policies as `kubernetes_manifest` resources.

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

By default, the providers use `~/.kube/config` and the current kubeconfig context. Set `kubeconfig_context` in `terraform.tfvars` when you want to target a specific EKS cluster context.

## Main policy settings

| Variable | Purpose |
| --- | --- |
| `policy_validation_failure_action` | Use `Audit` for rollout testing or `Enforce` to block violations. |
| `excluded_namespaces` | Namespaces excluded from workload, Service, and Ingress policies. |
| `excluded_namespace_names` | Namespace objects excluded from namespace label policies. |
| `allowed_namespace_environments` | Allowed values for the namespace `environment` label. |
| `approved_image_registries` | Image registry patterns allowed for Pods. |
| `loadbalancer_approval_annotation` | Annotation required for `Service` resources of type `LoadBalancer`. |
| `blocked_ingress_hosts` | Ingress host values denied by policy. |
| `required_pod_labels` | Labels that must be present on every Pod. |
| `generate_policy_synchronize` | Whether generated NetworkPolicy/ResourceQuota/LimitRange defaults are kept in sync (overwriting manual edits) or generated once. |
| `default_resource_quota` | Hard limits for the generated per-namespace `ResourceQuota`. |
| `default_limit_range` | Default container CPU/memory request and limit values for the generated per-namespace `LimitRange`. |
| `kyverno_values` | Helm values passed to the Kyverno chart. |

For existing clusters, start with:

```hcl
policy_validation_failure_action = "Audit"
```

After the policy reports are clean, switch to:

```hcl
policy_validation_failure_action = "Enforce"
```

