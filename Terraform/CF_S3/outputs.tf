output "site_bucket_name" {
  description = "Private S3 bucket that stores the static site files."
  value       = aws_s3_bucket.site.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.site.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name for the hosted site."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route 53 alias records."
  value       = aws_cloudfront_distribution.site.hosted_zone_id
}

output "upload_command" {
  description = "Example command to upload a local static site build."
  value       = "aws s3 sync ./dist s3://${aws_s3_bucket.site.id}/ --delete"
}

output "invalidate_command" {
  description = "Example command to invalidate CloudFront after uploading new files."
  value       = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.site.id} --paths '/*'"
}
