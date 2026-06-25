# Secure Static Site Hosting on S3 and CloudFront

This Terraform stack creates a production-grade static hosting setup:

- Private S3 bucket for website files
- CloudFront distribution with HTTPS redirect and compression
- CloudFront Origin Access Control (OAC), so S3 is not public
- S3 bucket policy restricted to the CloudFront distribution ARN
- S3 public access block, bucket-owner enforced ownership, versioning, and encryption
- CloudFront security response headers
- Optional CloudFront and S3 access logs with lifecycle retention
- Optional custom domains using ACM certificates in `us-east-1`

## Cost Note

This is designed to stay inside AWS Free Tier usage patterns for small static sites, but AWS pricing depends on traffic, requests, storage, logging, invalidations, and your account's Free Tier eligibility. Review the plan before applying.

## Usage

```bash
terraform init
cp terraform.tfvars.example terraform.tfvars
terraform plan
terraform apply
```

Upload your built site:

```bash
aws s3 sync ./dist s3://$(terraform output -raw site_bucket_name)/ --delete
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths '/*'
```

Open the site at:

```bash
terraform output -raw cloudfront_domain_name
```

## Custom Domain

To use `example.com` or `www.example.com`:

1. Create or import an ACM certificate in `us-east-1`.
2. Set `domain_aliases` and `acm_certificate_arn` in `terraform.tfvars`.
3. Create Route 53 alias records pointing to:
   - `cloudfront_domain_name`
   - `cloudfront_hosted_zone_id`

## Security Choices

The S3 website endpoint is intentionally not used because it requires public bucket access. CloudFront serves private S3 objects through OAC and signs origin requests with SigV4.

Security headers include:

- `Strict-Transport-Security`
- `X-Content-Type-Options`
- `X-Frame-Options`
- `Referrer-Policy`
- `X-XSS-Protection`
- `Permissions-Policy`

For apps that need iframes, camera, microphone, geolocation, or payment APIs, adjust the response headers policy in `main.tf`.

## SPA Routing

`enable_spa_routing = true` maps CloudFront 403 and 404 responses to `index.html` with HTTP 200. This is useful for React, Vue, Angular, and similar single-page apps. Set it to `false` for a traditional static site that should return real 404s.
