resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = local.interruption_queue_name
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = local.discovery_tags
}

data "aws_iam_policy_document" "karpenter_interruption_queue" {
  statement {
    sid    = "AllowEventBridgeSendMessage"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.${data.aws_partition.current.dns_suffix}", "sqs.${data.aws_partition.current.dns_suffix}"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.karpenter_interruption.arn]
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id
  policy    = data.aws_iam_policy_document.karpenter_interruption_queue.json
}

locals {
  interruption_events = {
    health_event = {
      name        = "KarpenterHealthEvent-${var.cluster_name}"
      description = "AWS Health events for Karpenter."
      pattern = {
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      }
    }
    spot_interruption = {
      name        = "KarpenterSpotInterruption-${var.cluster_name}"
      description = "EC2 Spot interruption warnings for Karpenter."
      pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      }
    }
    rebalance = {
      name        = "KarpenterRebalance-${var.cluster_name}"
      description = "EC2 instance rebalance recommendations for Karpenter."
      pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      }
    }
    state_change = {
      name        = "KarpenterInstanceStateChange-${var.cluster_name}"
      description = "EC2 instance state-change notifications for Karpenter."
      pattern = {
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      }
    }
  }
}

resource "aws_cloudwatch_event_rule" "karpenter_interruption" {
  for_each      = local.interruption_events
  name          = each.value.name
  description   = each.value.description
  event_pattern = jsonencode(each.value.pattern)

  tags = local.discovery_tags
}

resource "aws_cloudwatch_event_target" "karpenter_interruption" {
  for_each = aws_cloudwatch_event_rule.karpenter_interruption
  rule     = each.value.name
  arn      = aws_sqs_queue.karpenter_interruption.arn
}
