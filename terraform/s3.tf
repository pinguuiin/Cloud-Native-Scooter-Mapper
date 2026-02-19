# Raw GBFS snapshots bucket
resource "aws_s3_bucket" "raw" {
  bucket = "${local.project}-raw-${local.name_suffix}"
  tags   = local.common_tags
}

# Aggregated Parquet output bucket
resource "aws_s3_bucket" "aggregated" {
  bucket = "${local.project}-aggregated-${local.name_suffix}"
  tags   = local.common_tags
}

# Athena query results bucket
resource "aws_s3_bucket" "athena" {
  bucket = "${local.project}-athena-${local.name_suffix}"
  tags   = local.common_tags
}

# Static frontend assets bucket
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.project}-frontend-${local.name_suffix}"
  tags   = local.common_tags
}

# Block public access on raw bucket
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Block public access on aggregated bucket
resource "aws_s3_bucket_public_access_block" "aggregated" {
  bucket                  = aws_s3_bucket.aggregated.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Block public access on Athena results bucket
resource "aws_s3_bucket_public_access_block" "athena" {
  bucket                  = aws_s3_bucket.athena.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Block public access on frontend bucket (CloudFront only)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
