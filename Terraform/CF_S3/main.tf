data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  bucket_name = coalesce(
    var.bucket_name,
    "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  )

  cloudfront_log_bucket_name = "${local.bucket_name}-cf-logs"
  s3_log_bucket_name         = "${local.bucket_name}-s3-logs"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket" "s3_logs" {
  count = var.enable_s3_server_access_logging ? 1 : 0

  bucket        = local.s3_log_bucket_name
  force_destroy = var.force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "s3_logs" {
  count = var.enable_s3_server_access_logging ? 1 : 0

  bucket = aws_s3_bucket.s3_logs[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_logs" {
  count = var.enable_s3_server_access_logging ? 1 : 0

  bucket = aws_s3_bucket.s3_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_logs" {
  count = var.enable_s3_server_access_logging ? 1 : 0

  bucket = aws_s3_bucket.s3_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_logs" {
  count = var.enable_s3_server_access_logging ? 1 : 0

  bucket = aws_s3_bucket.s3_logs[0].id

  rule {
    id     = "expire-s3-access-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.s3_log_retention_days
    }
  }
}

resource "aws_s3_bucket_logging" "site" {
  count = var.enable_s3_server_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.site.id
  target_bucket = aws_s3_bucket.s3_logs[0].id
  target_prefix = "s3-access/${aws_s3_bucket.site.id}/"

  depends_on = [aws_s3_bucket_ownership_controls.s3_logs]
}

resource "aws_s3_bucket" "cloudfront_logs" {
  count = var.enable_cloudfront_logging ? 1 : 0

  bucket        = local.cloudfront_log_bucket_name
  force_destroy = var.force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  count = var.enable_cloudfront_logging ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  count = var.enable_cloudfront_logging ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  count = var.enable_cloudfront_logging ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  count = var.enable_cloudfront_logging ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  count = var.enable_cloudfront_logging ? 1 : 0

  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    id     = "expire-cloudfront-access-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.cloudfront_log_retention_days
    }
  }
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-${var.environment}-s3-oac"
  description                       = "Restricts S3 origin access to CloudFront for ${local.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.project_name}-${var.environment}-security-headers"
  comment = "Security headers for ${var.project_name} ${var.environment}"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      override = true
      value    = "camera=(), microphone=(), geolocation=(), payment=()"
    }
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "${var.project_name} ${var.environment} static site"
  default_root_object = var.index_document
  aliases             = var.domain_aliases
  price_class         = var.price_class
  wait_for_deployment = false

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = var.allowed_methods
    cached_methods             = var.cached_methods
    compress                   = true
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3_origin.id
  }

  dynamic "custom_error_response" {
    for_each = var.enable_spa_routing ? [403, 404] : []

    content {
      error_code            = custom_error_response.value
      response_code         = 200
      response_page_path    = "/${var.error_document}"
      error_caching_min_ttl = 10
    }
  }

  dynamic "logging_config" {
    for_each = var.enable_cloudfront_logging ? [1] : []

    content {
      bucket          = aws_s3_bucket.cloudfront_logs[0].bucket_domain_name
      include_cookies = false
      prefix          = "cloudfront/"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.acm_certificate_arn
    cloudfront_default_certificate = var.acm_certificate_arn == null ? true : null
    minimum_protocol_version       = var.minimum_tls_version
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
  }

  tags = local.common_tags

  depends_on = [
    aws_s3_bucket_public_access_block.site
  ]
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "cors_s3_origin" {
  name = "Managed-CORS-S3Origin"
}

data "aws_iam_policy_document" "site_bucket" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      "${aws_s3_bucket.site.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket.json
}
