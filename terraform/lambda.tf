# Ingest Lambda fetches GBFS and writes raw snapshots
resource "aws_lambda_function" "ingest" {
  function_name = "${local.project}-ingest-${local.name_suffix}"
  role          = aws_iam_role.ingest.arn
  handler       = "handler.ingest"
  runtime       = "python3.11"

  filename         = "${local.lambda_artifacts_dir}/lambda_ingest.zip"
  # Hash is used to detect changes and trigger updates
  source_code_hash = filebase64sha256("${local.lambda_artifacts_dir}/lambda_ingest.zip")

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory

  environment {
    variables = {
      GBFS_URL           = var.gbfs_url
      RAW_BUCKET         = aws_s3_bucket.raw.bucket
      RAW_PREFIX         = "raw"
      CITY               = var.city
      MIN_LATITUDE       = var.min_latitude
      MAX_LATITUDE       = var.max_latitude
      MIN_LONGITUDE      = var.min_longitude
      MAX_LONGITUDE      = var.max_longitude
      TRANSFORM_LAMBDA_NAME = aws_lambda_function.transform.function_name
    }
  }

  tags = local.common_tags
}

# Transform Lambda aggregates H3 and writes DynamoDB/Parquet
resource "aws_lambda_function" "transform" {
  function_name = "${local.project}-transform-${local.name_suffix}"
  role          = aws_iam_role.transform.arn
  handler       = "handler.transform"
  runtime       = "python3.11"

  filename         = "${local.lambda_artifacts_dir}/lambda_transform.zip"
  source_code_hash = filebase64sha256("${local.lambda_artifacts_dir}/lambda_transform.zip")

  timeout     = var.lambda_timeout
  memory_size = 1024

  environment {
    variables = {
      RAW_BUCKET          = aws_s3_bucket.raw.bucket
      AGG_BUCKET          = aws_s3_bucket.aggregated.bucket
      AGG_PREFIX          = "aggregated"
      DDB_TABLE           = aws_dynamodb_table.current_snapshot.name
      CITY                = var.city
      H3_RESOLUTIONS       = join(",", [for r in var.h3_resolutions : tostring(r)])
      MIN_LATITUDE        = var.min_latitude
      MAX_LATITUDE        = var.max_latitude
      MIN_LONGITUDE       = var.min_longitude
      MAX_LONGITUDE       = var.max_longitude
      WINDOW_SIZE_MINUTES = 5
    }
  }

  tags = local.common_tags
}

# API Lambda serves heatmap and stats endpoints
resource "aws_lambda_function" "api" {
  function_name = "${local.project}-api-${local.name_suffix}"
  role          = aws_iam_role.api.arn
  handler       = "handler.api_handler"
  runtime       = "python3.11"

  filename         = "${local.lambda_artifacts_dir}/lambda_api.zip"
  source_code_hash = filebase64sha256("${local.lambda_artifacts_dir}/lambda_api.zip")

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
