# Production EKS Terraform Stack

This stack creates a private-by-default Amazon EKS cluster using native AWS Terraform resources, without public/community EKS modules.

- IRSA enabled through the cluster OIDC provider.
- Optional IRSA IAM roles for Kubernetes service accounts.
- Multiple EKS managed node groups through `eks_managed_node_groups`.
- Custom EKS control plane IAM role.
- Custom IAM roles per node group.
- Custom cluster and node security groups.
- Private Kubernetes API endpoint by default.
- Control plane logging, KMS envelope encryption, managed add-ons, and access entries.
- Native `aws_eks_cluster`, `aws_eks_node_group`, `aws_eks_addon`, `aws_iam_openid_connect_provider`, and IAM/KMS resources.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Update `terraform.tfvars` with real VPC, private subnet, IAM principal, and optional IRSA policy ARNs before planning.

## Private Cluster Default

The API endpoint defaults to private-only:

```hcl
cluster_endpoint_private_access = true
cluster_endpoint_public_access  = false
```

Add trusted private networks to `cluster_endpoint_private_access_cidrs` so bastion hosts, VPN ranges, or runner subnets can reach TCP/443 on the custom cluster security group.

## Multiple Node Groups

Add or edit node groups in `eks_managed_node_groups`:

```hcl
eks_managed_node_groups = {
  system = {
    min_size       = 2
    max_size       = 4
    desired_size   = 2
    instance_types = ["m6i.large"]
    capacity_type  = "ON_DEMAND"
  }

  workloads = {
    min_size       = 3
    max_size       = 20
    desired_size   = 6
    instance_types = ["m6i.large", "m6a.large"]
    capacity_type  = "SPOT"
  }
}
```

Each node group gets its own custom IAM role. The shared custom node security group is attached automatically.

## IRSA Roles

Define service-account-bound IAM roles with `irsa_roles`:

```hcl
irsa_roles = {
  external_dns = {
    namespace            = "kube-system"
    service_account_name = "external-dns"
    policy_arns          = ["arn:aws:iam::123456789012:policy/external-dns"]
  }
}
```

Use the matching annotation in Kubernetes:

```yaml
eks.amazonaws.com/role-arn: <value from irsa_role_arns.external_dns>
```

## Access

Modern EKS access entries are enabled by default with:

```hcl
authentication_mode = "API"
```

The Terraform caller gets admin permissions by default through `enable_cluster_creator_admin_permissions = true`. Add durable platform/admin roles through `access_entries`.
