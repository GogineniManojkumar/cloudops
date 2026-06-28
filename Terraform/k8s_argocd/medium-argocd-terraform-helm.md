# Setting Up Argo CD on Kubernetes with Terraform and Helm

Argo CD is one of the most common tools used to bring GitOps into Kubernetes. Instead of applying manifests manually from a laptop or a CI job, Argo CD watches a Git repository and keeps the cluster in sync with the desired state defined there.

In this guide, we will install Argo CD on a Kubernetes cluster using Terraform and the official Argo CD Helm chart.

The setup uses:

- Terraform to manage the installation
- Helm provider to install the Argo CD chart
- Kubernetes provider to connect to the cluster
- A Kubernetes API token instead of a kubeconfig file

This approach works well for automation environments such as CI/CD pipelines, Terraform runners, and platform repositories where using a local kubeconfig is not ideal.

For a production setup, create a dedicated service account for Terraform and give it only the permissions it needs to install and manage Argo CD. Avoid using a personal admin token.

## What We Are Building

The Terraform module will:

- Connect to an existing Kubernetes cluster
- Create the `argocd` namespace if it does not exist
- Install Argo CD using the official Helm chart
- Optionally expose Argo CD through ingress
- Allow custom Helm values when needed

The main Terraform resource is a `helm_release`, which points to the official Argo Helm repository:

```hcl
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
}
```

Using Helm through Terraform gives us a repeatable installation while still keeping access to the full flexibility of the Helm chart.

## Provider Configuration

Instead of using a kubeconfig file, this setup connects to Kubernetes with three values:

- Kubernetes API server URL
- Bearer token
- Cluster CA certificate

The providers look like this:

```hcl
provider "kubernetes" {
  host                   = var.cluster_host
  token                  = var.cluster_token
  cluster_ca_certificate = var.cluster_ca_certificate == null ? null : base64decode(var.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_host
    token                  = var.cluster_token
    cluster_ca_certificate = var.cluster_ca_certificate == null ? null : base64decode(var.cluster_ca_certificate)
  }
}
```

This is useful because Terraform can run from anywhere as long as it has the cluster endpoint, a valid token, and the CA certificate. There is no dependency on a kubeconfig file being present on the machine.

## Input Variables

The cluster connection variables are:

```hcl
variable "cluster_host" {
  description = "Kubernetes API server endpoint."
  type        = string
}

variable "cluster_token" {
  description = "Bearer token used to authenticate with the Kubernetes API server."
  type        = string
  sensitive   = true
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded Kubernetes cluster CA certificate."
  type        = string
  default     = null
  sensitive   = true
}
```

The Argo CD installation itself is controlled with variables such as:

```hcl
variable "namespace" {
  type    = string
  default = "argocd"
}

variable "release_name" {
  type    = string
  default = "argocd"
}

variable "service_type" {
  type    = string
  default = "ClusterIP"
}

variable "enable_ingress" {
  type    = bool
  default = false
}
```

This keeps the default installation simple, while still making it easy to enable ingress or change the service type later.

## Creating the Terraform Values File

Create a file called `terraform.tfvars`.

Do not commit this file to Git, because it contains a cluster token. In this repository, `*.tfvars` files are ignored for that reason.

```hcl
cluster_host           = "https://your-kubernetes-api-server"
cluster_token          = "your-service-account-token"
cluster_ca_certificate = "base64-encoded-cluster-ca-certificate"

namespace    = "argocd"
release_name = "argocd"
```

For the CA certificate, most managed Kubernetes platforms expose it as a base64-encoded value. Terraform decodes it before passing it to the Kubernetes and Helm providers.

## Installing Argo CD

Initialize Terraform:

```bash
terraform init
```

Check the plan:

```bash
terraform plan
```

Apply the changes:

```bash
terraform apply
```

Terraform will create the namespace and install Argo CD into the cluster using Helm.

## Accessing the Argo CD UI

If you keep the default service type as `ClusterIP`, you can access Argo CD through port forwarding:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then open:

```text
https://localhost:8080
```

The default username is:

```text
admin
```

To fetch the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

After logging in, change the admin password or configure SSO depending on your environment.

## Enabling Ingress

For a more permanent setup, enable ingress by adding these values to `terraform.tfvars`:

```hcl
enable_ingress     = true
ingress_class_name = "nginx"
server_host        = "argocd.example.com"
tls_secret_name    = "argocd-tls"
```

The module passes these values into the Helm chart:

```hcl
server = {
  ingress = {
    enabled          = var.enable_ingress
    ingressClassName = var.ingress_class_name
    hosts            = var.server_host == null ? [] : [var.server_host]
  }
}
```

When ingress is enabled, the module also sets the Argo CD server URL:

```hcl
configs = {
  cm = {
    url = "https://${var.server_host}"
  }
}
```

This helps Argo CD generate correct callback URLs and links.

## Passing Custom Helm Values

The official Argo CD Helm chart has many configuration options. Instead of hardcoding all of them into Terraform variables, the module accepts a generic `values` map.

For example:

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

These values are merged into the Helm release:

```hcl
values = [
  yamlencode(local.base_values),
  yamlencode(var.values)
]
```

This gives us a good balance: common settings are exposed as simple variables, while advanced settings can still be passed directly to the Helm chart.

## Setting the Admin Password

By default, Argo CD creates an initial admin password and stores it in a Kubernetes secret.

If you want to set the admin password during installation, generate a bcrypt hash:

```bash
argocd account bcrypt --password 'your-password'
```

Then pass it to Terraform:

```hcl
admin_password_bcrypt = "$2a$10$examplebcryptvalue"
admin_password_mtime  = "2026-01-01T00:00:00Z"
```

The password variable is marked as sensitive, but it is still better to provide it through a secure Terraform variable store or CI secret instead of committing it into a file.

## Why Use Terraform for This?

You can install Argo CD with a single Helm command, and for local testing that is perfectly fine.

For shared environments, Terraform gives a few advantages:

- The installation is version-controlled
- Changes are visible in `terraform plan`
- The same configuration can be reused across clusters
- CI/CD systems can apply it without relying on a local kubeconfig
- Helm values can be managed alongside other infrastructure

In short, Helm does the installation, and Terraform makes that installation predictable.

## Final Thoughts

This setup gives you a clean starting point for running Argo CD on Kubernetes.

Start simple with a private `ClusterIP` service and port forwarding. Once the installation is stable, add ingress, TLS, SSO, RBAC, and repository configuration based on your organization’s needs.

The important part is that Argo CD itself is now managed declaratively. That is a good first step toward managing the rest of your Kubernetes workloads the same way.
