# Assume role policy for Lambda execution
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM role for ingest Lambda
resource "aws_iam_role" "ingest" {
  name               = "${local.project}-ingest-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

# IAM role for transform Lambda
resource "aws_iam_role" "transform" {
  name               = "${local.project}-transform-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

# IAM role for API Lambda
resource "aws_iam_role" "api" {
  name               = "${local.project}-api-${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

# IAM policy for ingest Lambda access
resource "aws_iam_role_policy" "ingest" {
  name = "${local.project}-ingest-policy-${local.name_suffix}"
  role = aws_iam_role.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.raw.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [aws_lambda_function.transform.arn]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for transform Lambda access
resource "aws_iam_role_policy" "transform" {
  name = "${local.project}-transform-policy-${local.name_suffix}"
  role = aws_iam_role.transform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.raw.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.aggregated.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:BatchWriteItem"]
        Resource = [aws_dynamodb_table.current_snapshot.arn]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for API Lambda access
resource "aws_iam_role_policy" "api" {
  name = "${local.project}-api-policy-${local.name_suffix}"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DescribeTable"]
        Resource = [aws_dynamodb_table.current_snapshot.arn]
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}
