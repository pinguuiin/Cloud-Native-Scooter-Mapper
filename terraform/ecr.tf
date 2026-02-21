# ECR repository for ingest Lambda image.
resource "aws_ecr_repository" "ingest" {
  name                 = "${local.project}-ingest"
  image_tag_mutability = "MUTABLE"
  tags                 = local.common_tags
}

# ECR repository for transform Lambda image.
resource "aws_ecr_repository" "transform" {
  name                 = "${local.project}-transform"
  image_tag_mutability = "MUTABLE"
  tags                 = local.common_tags
}

# ECR repository for API Lambda image.
resource "aws_ecr_repository" "api" {
  name                 = "${local.project}-api"
  image_tag_mutability = "MUTABLE"
  tags                 = local.common_tags
}

# Allow Lambda service to pull ingest image.
resource "aws_ecr_repository_policy" "ingest" {
  repository = aws_ecr_repository.ingest.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaPull"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# Allow Lambda service to pull transform image.
resource "aws_ecr_repository_policy" "transform" {
  repository = aws_ecr_repository.transform.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaPull"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# Allow Lambda service to pull api image.
resource "aws_ecr_repository_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaPull"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
