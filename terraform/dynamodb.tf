# DynamoDB table for current H3 snapshot
resource "aws_dynamodb_table" "current_snapshot" {
  name         = "${local.project}-current-${local.name_suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "resolution"
  range_key    = "h3_index"

  attribute {
    name = "resolution"
    type = "N"
  }

  attribute {
    name = "h3_index"
    type = "S"
  }

  tags = local.common_tags
}
