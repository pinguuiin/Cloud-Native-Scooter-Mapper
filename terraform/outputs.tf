# Base URL for the API Gateway stage
output "api_base_url" {
  value = aws_apigatewayv2_stage.api.invoke_url
}

# S3 bucket name for frontend assets
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

# CloudFront domain serving the frontend
output "cloudfront_domain" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

# CloudFront distribution ID for cache invalidation commands
output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

# S3 bucket name for raw snapshots
output "raw_bucket_name" {
  value = aws_s3_bucket.raw.bucket
}

# S3 bucket name for aggregated parquet output
output "aggregated_bucket_name" {
  value = aws_s3_bucket.aggregated.bucket
}

# DynamoDB table name for current snapshot
output "dynamodb_table_name" {
  value = aws_dynamodb_table.current_snapshot.name
}

# ECR repository URL for ingest image.
output "ecr_ingest_repository_url" {
  value = aws_ecr_repository.ingest.repository_url
}

# ECR repository URL for transform image.
output "ecr_transform_repository_url" {
  value = aws_ecr_repository.transform.repository_url
}

# ECR repository URL for api image.
output "ecr_api_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

# ECR repository URL for compact image.
output "ecr_compact_repository_url" {
  value = aws_ecr_repository.compact.repository_url
}

# AWS region currently targeted by Terraform.
output "aws_region" {
  value = var.region
}

# EventBridge rule name for pause/resume commands.
output "ingest_schedule_rule_name" {
  value = aws_cloudwatch_event_rule.ingest_schedule.name
}

# EventBridge rule name for compaction schedule.
output "compact_schedule_rule_name" {
  value = aws_cloudwatch_event_rule.compact_schedule.name
}
