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
