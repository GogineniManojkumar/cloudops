# Terraform Kubernetes Argo CD

Terraform module to install Argo CD on Kubernetes using the official `argo-cd` Helm chart.

## Usage With Token

Create a `terraform.tfvars` file:

```hcl
cluster_host           = "https://your-kubernetes-api-server"
cluster_token          = "your-service-account-token"
cluster_ca_certificate = "base64-encoded-cluster-ca-certificate"

namespace    = "argocd"
release_name = "argocd"
```

The providers in this module use the token values directly, so no kubeconfig file is required.

## With Ingress

```hcl
enable_ingress     = true
ingress_class_name = "nginx"
server_host        = "argocd.example.com"
tls_secret_name    = "argocd-tls"
```

## With Custom Values

```hcl
values = {
  controller = {
    replicas = 1
  }

  repoServer = {
    replicas = 2
  }
}
```

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| `cluster_host` | Kubernetes API server endpoint. | n/a |
| `cluster_token` | Bearer token for Kubernetes API authentication. | n/a |
| `cluster_ca_certificate` | Base64-encoded Kubernetes cluster CA certificate. | `null` |
| `namespace` | Kubernetes namespace where Argo CD will be installed. | `argocd` |
| `create_namespace` | Whether Helm should create the namespace. | `true` |
| `release_name` | Helm release name. | `argocd` |
| `chart_version` | Argo CD Helm chart version. | `null` |
| `service_type` | Argo CD server service type. | `ClusterIP` |
| `enable_ingress` | Enable Argo CD server ingress. | `false` |
| `ingress_class_name` | Ingress class name. | `nginx` |
| `server_host` | Hostname for ingress and Argo CD URL. | `null` |
| `tls_secret_name` | TLS secret name for ingress. | `null` |
| `admin_password_bcrypt` | Optional bcrypt hash for the admin password. | `null` |
| `values` | Extra Helm values merged into the chart. | `{}` |
| `set_values` | Extra scalar Helm set overrides. | `[]` |

## Outputs

| Name | Description |
| --- | --- |
| `release_name` | Name of the Helm release. |
| `namespace` | Namespace where Argo CD is installed. |
| `chart_version` | Installed chart version. |
| `server_url` | Argo CD server URL when `server_host` is provided. |
| `admin_initial_password_command` | Command to fetch the generated initial admin password. |

## Apply

```bash
terraform init
terraform plan
terraform apply
```
