## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.95 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.16 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.19.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.35 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 1.19.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_rule.karpenter_interruption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.karpenter_interruption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_ec2_tag.cluster_primary_security_group_discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_ec2_tag.cluster_primary_security_group_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_tag) | resource |
| [aws_eks_access_entry.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_iam_policy.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.karpenter_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_sqs_queue.karpenter_interruption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.karpenter_interruption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter_crd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.ec2_node_class_default](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.node_pool_default](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_config_map_v1_data.aws_auth_karpenter_node](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1_data) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.karpenter_interruption_queue](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [kubernetes_config_map_v1.aws_auth](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/data-sources/config_map_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ami_alias"></a> [ami\_alias](#input\_ami\_alias) | AMI alias for EC2NodeClass. Use al2023@latest for quick starts, or pin an alias such as al2023@v20260203 for production. | `string` | `"al2023@latest"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where the existing EKS cluster is running. | `string` | n/a | yes |
| <a name="input_capacity_types"></a> [capacity\_types](#input\_capacity\_types) | Allowed Karpenter capacity types. | `list(string)` | <pre>[<br/>  "spot",<br/>  "on-demand"<br/>]</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the existing EKS cluster. | `string` | n/a | yes |
| <a name="input_cluster_primary_security_group_tags"></a> [cluster\_primary\_security\_group\_tags](#input\_cluster\_primary\_security\_group\_tags) | Tags to add to the EKS cluster primary security group so EC2NodeClass can discover it. | `map(string)` | `{}` | no |
| <a name="input_consolidate_after"></a> [consolidate\_after](#input\_consolidate\_after) | How long Karpenter waits before consolidating empty or underutilized nodes. | `string` | `"1m"` | no |
| <a name="input_controller_cpu_limit"></a> [controller\_cpu\_limit](#input\_controller\_cpu\_limit) | CPU limit for the Karpenter controller. | `string` | `"1"` | no |
| <a name="input_controller_cpu_request"></a> [controller\_cpu\_request](#input\_controller\_cpu\_request) | CPU request for the Karpenter controller. | `string` | `"1"` | no |
| <a name="input_controller_memory_limit"></a> [controller\_memory\_limit](#input\_controller\_memory\_limit) | Memory limit for the Karpenter controller. | `string` | `"1Gi"` | no |
| <a name="input_controller_memory_request"></a> [controller\_memory\_request](#input\_controller\_memory\_request) | Memory request for the Karpenter controller. | `string` | `"1Gi"` | no |
| <a name="input_enable_irsa"></a> [enable\_irsa](#input\_enable\_irsa) | Create an IAM role for the Karpenter service account using the cluster OIDC provider. | `bool` | `true` | no |
| <a name="input_enable_zonal_shift"></a> [enable\_zonal\_shift](#input\_enable\_zonal\_shift) | Pass settings.enableZonalShift to Karpenter. | `bool` | `false` | no |
| <a name="input_existing_karpenter_controller_role_arn"></a> [existing\_karpenter\_controller\_role\_arn](#input\_existing\_karpenter\_controller\_role\_arn) | Existing IAM role ARN for the Karpenter service account. Used when enable\_irsa is false. | `string` | `null` | no |
| <a name="input_instance_categories"></a> [instance\_categories](#input\_instance\_categories) | Allowed EC2 instance categories for the default NodePool. | `list(string)` | <pre>[<br/>  "c",<br/>  "m",<br/>  "r"<br/>]</pre> | no |
| <a name="input_instance_generation_gt"></a> [instance\_generation\_gt](#input\_instance\_generation\_gt) | Minimum EC2 instance generation, exclusive. | `string` | `"2"` | no |
| <a name="input_karpenter_chart_version"></a> [karpenter\_chart\_version](#input\_karpenter\_chart\_version) | Karpenter Helm chart version. Check https://karpenter.sh/docs/ before upgrading. | `string` | `"1.13.0"` | no |
| <a name="input_karpenter_namespace"></a> [karpenter\_namespace](#input\_karpenter\_namespace) | Kubernetes namespace for Karpenter. | `string` | `"kube-system"` | no |
| <a name="input_node_expire_after"></a> [node\_expire\_after](#input\_node\_expire\_after) | Maximum lifetime for Karpenter nodes. | `string` | `"720h"` | no |
| <a name="input_node_role_auth_mode"></a> [node\_role\_auth\_mode](#input\_node\_role\_auth\_mode) | How Karpenter node IAM role is authorized to join EKS. Valid values: access\_entry, aws\_auth\_configmap, none. | `string` | `"access_entry"` | no |
| <a name="input_nodepool_cpu_limit"></a> [nodepool\_cpu\_limit](#input\_nodepool\_cpu\_limit) | Total CPU limit for the default Karpenter NodePool. | `string` | `"1000"` | no |
| <a name="input_security_group_selector_tags"></a> [security\_group\_selector\_tags](#input\_security\_group\_selector\_tags) | Tags used by EC2NodeClass to discover node security groups. Defaults to karpenter.sh/discovery=<cluster\_name>. | `map(string)` | `null` | no |
| <a name="input_subnet_selector_tags"></a> [subnet\_selector\_tags](#input\_subnet\_selector\_tags) | Tags used by EC2NodeClass to discover private subnets for Karpenter nodes. Defaults to karpenter.sh/discovery=<cluster\_name>. | `map(string)` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_karpenter_controller_role_arn"></a> [karpenter\_controller\_role\_arn](#output\_karpenter\_controller\_role\_arn) | IAM role ARN used by the Karpenter controller service account. |
| <a name="output_karpenter_interruption_queue_name"></a> [karpenter\_interruption\_queue\_name](#output\_karpenter\_interruption\_queue\_name) | SQS queue name configured for Karpenter interruption handling. |
| <a name="output_karpenter_node_role_arn"></a> [karpenter\_node\_role\_arn](#output\_karpenter\_node\_role\_arn) | IAM role ARN used by EC2 instances launched by Karpenter. |
| <a name="output_karpenter_nodepool_name"></a> [karpenter\_nodepool\_name](#output\_karpenter\_nodepool\_name) | Default Karpenter NodePool name. |
