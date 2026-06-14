resource "aws_security_group" "cluster" {
  name        = "${local.name}-cluster-sg"
  description = "Custom security group for the ${local.name} EKS control plane."
  vpc_id      = var.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name}-cluster-sg"
  })
}

resource "aws_security_group" "nodes" {
  name        = "${local.name}-nodes-sg"
  description = "Custom security group for ${local.name} EKS worker nodes."
  vpc_id      = var.vpc_id

  tags = merge(local.tags, {
    Name                                      = "${local.name}-nodes-sg"
    "kubernetes.io/cluster/${local.name}"     = "owned"
    "karpenter.sh/discovery/${local.name}"    = local.name
    "karpenter.k8s.aws/cluster/${local.name}" = "owned"
  })
}

resource "aws_security_group_rule" "cluster_egress" {
  type              = "egress"
  security_group_id = aws_security_group.cluster.id
  description       = "Allow EKS control plane egress."
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = var.cluster_egress_cidr_blocks
}

resource "aws_security_group_rule" "cluster_ingress_from_nodes" {
  type                     = "ingress"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow nodes to communicate with the EKS control plane."
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "cluster_private_access" {
  for_each = toset(var.cluster_endpoint_private_access_cidrs)

  type              = "ingress"
  security_group_id = aws_security_group.cluster.id
  description       = "Allow private API endpoint access from trusted networks."
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
}

resource "aws_security_group_rule" "node_egress" {
  type              = "egress"
  security_group_id = aws_security_group.nodes.id
  description       = "Allow worker node egress."
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = var.node_egress_cidr_blocks
}

resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  self              = true
  description       = "Allow node-to-node traffic."
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

resource "aws_security_group_rule" "node_ingress_from_cluster" {
  type                     = "ingress"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow control plane to reach kubelets and webhooks."
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "node_webhook_ingress_from_cluster" {
  type                     = "ingress"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow control plane to reach admission webhooks."
  from_port                = 443
  to_port                  = 9443
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "additional_cluster_ingress" {
  for_each = var.additional_cluster_security_group_rules

  type              = "ingress"
  security_group_id = aws_security_group.cluster.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

resource "aws_security_group_rule" "additional_node_ingress" {
  for_each = var.additional_node_security_group_rules

  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}
