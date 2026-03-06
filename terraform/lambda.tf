# Ingest Lambda fetches GBFS and writes raw snapshots
resource "aws_lambda_function" "ingest" {
  function_name = "${local.project}-ingest-${local.name_suffix}"
  role          = aws_iam_role.ingest.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.ingest.repository_url}:${var.lambda_image_tag}"

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory

  environment {
    variables = {
      GBFS_URL              = var.gbfs_url
      RAW_BUCKET            = aws_s3_bucket.raw.bucket
      CITY                  = var.city
      TIMEZONE              = var.timezone
      MIN_LATITUDE          = var.min_latitude
      MAX_LATITUDE          = var.max_latitude
      MIN_LONGITUDE         = var.min_longitude
      MAX_LONGITUDE         = var.max_longitude
      TRANSFORM_LAMBDA_NAME = aws_lambda_function.transform.function_name
    }
  }

  tags = local.common_tags
}

# Transform Lambda aggregates H3 and writes DynamoDB/Parquet
resource "aws_lambda_function" "transform" {
  function_name = "${local.project}-transform-${local.name_suffix}"
  role          = aws_iam_role.transform.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.transform.repository_url}:${var.lambda_image_tag}"

  timeout     = var.lambda_timeout
  memory_size = 1024

  environment {
    variables = {
      RAW_BUCKET          = aws_s3_bucket.raw.bucket
      AGG_BUCKET          = aws_s3_bucket.aggregated.bucket
      DDB_TABLE           = aws_dynamodb_table.current_snapshot.name
      H3_RESOLUTIONS      = join(",", [for r in var.h3_resolutions : tostring(r)])
      MIN_LATITUDE        = var.min_latitude
      MAX_LATITUDE        = var.max_latitude
      MIN_LONGITUDE       = var.min_longitude
      MAX_LONGITUDE       = var.max_longitude
      WINDOW_SIZE_MINUTES = 5
      CITY                = var.city
      TIMEZONE            = var.timezone
    }
  }

  tags = local.common_tags
}

# API Lambda serves heatmap and stats endpoints
resource "aws_lambda_function" "api" {
  function_name = "${local.project}-api-${local.name_suffix}"
  role          = aws_iam_role.api.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.api.repository_url}:${var.lambda_image_tag}"

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory

  environment {
    variables = {
      DDB_TABLE             = aws_dynamodb_table.current_snapshot.name
      H3_DEFAULT_RESOLUTION = tostring(var.h3_default_resolution)
      CORS_ORIGINS          = join(",", var.cors_origins)
    }
  }

  tags = local.common_tags
}

# Compact Lambda merges small Parquet files by date/hour/resolution
resource "aws_lambda_function" "compact" {
  function_name = "${local.project}-compact-${local.name_suffix}"
  role          = aws_iam_role.compact.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.compact.repository_url}:${var.lambda_image_tag}"

  timeout     = var.lambda_timeout
  memory_size = 1024

  environment {
    variables = {
      AGG_BUCKET                  = aws_s3_bucket.aggregated.bucket
      CITY                        = var.city
      TIMEZONE                    = var.timezone
      H3_RESOLUTIONS              = join(",", [for r in var.h3_resolutions : tostring(r)])
      COMPACTION_LOOKBACK_HOURS   = tostring(var.compaction_lookback_hours)
      DELETE_SOURCE_AFTER_COMPACT = "true"
    }
  }

  tags = local.common_tags
}
