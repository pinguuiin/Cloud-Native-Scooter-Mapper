# Athena workgroup with S3 output location
resource "aws_athena_workgroup" "main" {
  name = "${local.project}-wg-${local.name_suffix}"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena.bucket}/results/"
    }
  }

  tags = local.common_tags
}

# Athena database pointing at aggregated bucket
resource "aws_athena_database" "main" {
  name   = "${local.project}_analytics"
  bucket = aws_s3_bucket.aggregated.bucket
}
