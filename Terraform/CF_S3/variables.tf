variable "aws_region" {
  description = "AWS region for S3 and regional resources. CloudFront remains global."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project name used for resource names."
  type        = string
  default     = "static-site"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,40}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-42 characters using lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name. Leave null to derive one from project_name, environment, account, and region."
  type        = string
  default     = null
}

variable "index_document" {
  description = "Default object served for the static site."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Object served for CloudFront 403 and 404 responses. For SPAs, set this to index.html."
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 is lowest cost and covers North America and Europe edge locations."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "domain_aliases" {
  description = "Optional custom hostnames, such as www.example.com. Requires acm_certificate_arn."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "Optional ACM certificate ARN in us-east-1 for CloudFront custom domains."
  type        = string
  default     = null
}

variable "minimum_tls_version" {
  description = "Minimum TLS protocol version for the CloudFront viewer certificate."
  type        = string
  default     = "TLSv1.2_2021"
}

variable "enable_ipv6" {
  description = "Whether CloudFront should serve IPv6 traffic."
  type        = bool
  default     = true
}

variable "enable_cloudfront_logging" {
  description = "Whether to enable CloudFront standard access logs in a private S3 bucket."
  type        = bool
  default     = false
}

variable "cloudfront_log_retention_days" {
  description = "Number of days to retain CloudFront logs when logging is enabled."
  type        = number
  default     = 90
}

variable "enable_s3_server_access_logging" {
  description = "Whether to enable S3 server access logs for the website bucket."
  type        = bool
  default     = false
}

variable "s3_log_retention_days" {
  description = "Number of days to retain S3 access logs when logging is enabled."
  type        = number
  default     = 90
}

variable "allowed_methods" {
  description = "HTTP methods allowed by CloudFront."
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "cached_methods" {
  description = "HTTP methods cached by CloudFront."
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "default_ttl" {
  description = "Default CloudFront cache TTL in seconds."
  type        = number
  default     = 3600
}

variable "max_ttl" {
  description = "Maximum CloudFront cache TTL in seconds."
  type        = number
  default     = 86400
}

variable "enable_spa_routing" {
  description = "Return error_document with HTTP 200 for 403/404 responses. Useful for React/Vue/Angular single-page apps."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Whether Terraform can delete non-empty buckets. Keep false in production unless you intentionally want teardown to remove objects."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}
