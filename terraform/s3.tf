# Raw GBFS snapshots bucket
resource "aws_s3_bucket" "raw" {
  bucket        = "${local.project}-raw-${local.name_suffix}"
  force_destroy = true
  tags          = local.common_tags
}

# Expire raw snapshots after retention period
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "expire-raw"
    status = "Enabled"

    filter {}

    expiration {
      days = var.raw_retention_days
    }
  }
}

# Aggregated Parquet output bucket
resource "aws_s3_bucket" "aggregated" {
  bucket        = "${local.project}-aggregated-${local.name_suffix}"
  force_destroy = true
  tags          = local.common_tags
}

# Expire aggregated snapshots after retention period
resource "aws_s3_bucket_lifecycle_configuration" "aggregated" {
  bucket = aws_s3_bucket.aggregated.id

  rule {
    id     = "expire-aggregated"
    status = "Enabled"

    filter {}

    expiration {
      days = var.aggregated_retention_days
    }
  }
}

# Athena query results bucket
resource "aws_s3_bucket" "athena" {
  bucket        = "${local.project}-athena-${local.name_suffix}"
  force_destroy = true
  tags          = local.common_tags
}

# Expire Athena query results after retention period
resource "aws_s3_bucket_lifecycle_configuration" "athena" {
  bucket = aws_s3_bucket.athena.id

  rule {
    id     = "expire-athena-results"
    status = "Enabled"

    filter {}

    expiration {
      days = var.athena_retention_days
    }
  }
}

# Static frontend assets bucket
resource "aws_s3_bucket" "frontend" {
  bucket        = "${local.project}-frontend-${local.name_suffix}"
  force_destroy = true
  tags          = local.common_tags
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
