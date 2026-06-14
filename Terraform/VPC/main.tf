data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  subnet_count         = var.public_subnet_count + var.private_subnet_count
  nat_gateway_count    = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 3) : 0
  public_subnet_bits   = [for index in range(var.public_subnet_count) : cidrsubnet(var.vpc_cidr, var.subnet_newbits, index)]
  private_subnet_bits  = [for index in range(var.private_subnet_count) : cidrsubnet(var.vpc_cidr, var.subnet_newbits, index + var.public_subnet_count)]
  common_name          = "${var.name}-${var.environment}"
  public_route_tables  = var.public_subnet_count > 0 ? ["public"] : []
  private_route_tables = var.private_subnet_count > 0 ? (var.enable_nat_gateway && !var.single_nat_gateway ? ["az-0", "az-1", "az-2"] : ["private"]) : []

  common_tags = merge(
    {
      Project     = var.name
      Environment = var.environment
      ManagedBy   = "terraform"
      Terraform   = "true"
    },
    var.additional_tags
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = {
    Name = local.common_name
  }
}

resource "aws_internet_gateway" "this" {
  count = var.public_subnet_count > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.common_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count = var.public_subnet_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_bits[count.index]
  availability_zone       = local.azs[count.index % 3]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.common_name}-public-${local.azs[count.index % 3]}-${count.index + 1}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.private_subnet_bits[count.index]
  availability_zone       = local.azs[count.index % 3]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.common_name}-private-${local.azs[count.index % 3]}-${count.index + 1}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  for_each = toset(local.public_route_tables)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = {
    Name = "${local.common_name}-public-rt"
    Tier = "public"
  }
}

resource "aws_route_table_association" "public" {
  count = var.public_subnet_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public["public"].id
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = {
    Name = "${local.common_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = {
    Name = "${local.common_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  for_each = toset(local.private_route_tables)

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : tonumber(trimprefix(each.key, "az-"))].id
    }
  }

  tags = {
    Name = "${local.common_name}-private-rt"
    Tier = "private"
  }
}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.enable_nat_gateway && !var.single_nat_gateway ? "az-${count.index % 3}" : "private"].id
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = var.enable_vpc_endpoints ? var.gateway_vpc_endpoints : []

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = compact(concat([for rt in aws_route_table.private : rt.id], [for rt in aws_route_table.public : rt.id]))

  tags = {
    Name = "${local.common_name}-${replace(each.value, ".", "-")}-gateway-vpce"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints && length(var.interface_vpc_endpoints) > 0 ? 1 : 0

  name        = "${local.common_name}-interface-vpce-sg"
  description = "Allow HTTPS access to interface VPC endpoints from inside the VPC"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS responses"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.common_name}-interface-vpce-sg"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_vpc_endpoints ? var.interface_vpc_endpoints : []

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = var.vpc_endpoint_private_dns_enabled

  tags = {
    Name = "${local.common_name}-${replace(each.value, ".", "-")}-interface-vpce"
  }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${local.common_name}/flow-logs"
  retention_in_days = var.flow_log_retention_days

  tags = {
    Name = "${local.common_name}-flow-logs"
  }
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${local.common_name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role[0].json

  tags = {
    Name = "${local.common_name}-vpc-flow-logs"
  }
}

data "aws_iam_policy_document" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = ["${aws_cloudwatch_log_group.flow_logs[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "${local.common_name}-vpc-flow-logs"
  role   = aws_iam_role.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = var.flow_log_traffic_type
  vpc_id          = aws_vpc.this.id

  tags = {
    Name = "${local.common_name}-flow-log"
  }
}

resource "terraform_data" "subnet_capacity_guard" {
  input = local.subnet_count

  lifecycle {
    precondition {
      condition     = local.subnet_count <= pow(2, var.subnet_newbits)
      error_message = "public_subnet_count + private_subnet_count must fit within the selected subnet_newbits."
    }
  }
}

resource "terraform_data" "nat_gateway_guard" {
  input = var.enable_nat_gateway

  lifecycle {
    precondition {
      condition     = !var.enable_nat_gateway || var.public_subnet_count >= 1
      error_message = "enable_nat_gateway requires at least one public subnet."
    }

    precondition {
      condition     = !var.enable_nat_gateway || var.single_nat_gateway || var.public_subnet_count >= 3
      error_message = "single_nat_gateway=false requires at least three public subnets, one per selected availability zone."
    }
  }
}

resource "terraform_data" "interface_endpoint_guard" {
  input = length(var.interface_vpc_endpoints)

  lifecycle {
    precondition {
      condition     = !var.enable_vpc_endpoints || length(var.interface_vpc_endpoints) == 0 || var.private_subnet_count > 0
      error_message = "Interface VPC endpoints require at least one private subnet."
    }
  }
}
