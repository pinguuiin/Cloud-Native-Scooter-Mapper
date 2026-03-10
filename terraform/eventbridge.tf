# Schedule rule to trigger ingestion
resource "aws_cloudwatch_event_rule" "ingest_schedule" {
  name                = "${local.project}-ingest-${local.name_suffix}"
  schedule_expression = var.ingestion_schedule_expression
}

# Event target that invokes the ingest Lambda
resource "aws_cloudwatch_event_target" "ingest" {
  rule      = aws_cloudwatch_event_rule.ingest_schedule.name
  target_id = "ingest-lambda"
  arn       = aws_lambda_function.ingest.arn
}

# Allow EventBridge to invoke ingest Lambda
resource "aws_lambda_permission" "eventbridge_ingest" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ingest_schedule.arn
}

# Schedule rule to trigger compaction
resource "aws_cloudwatch_event_rule" "compact_schedule" {
  name                = "${local.project}-compact-${local.name_suffix}"
  schedule_expression = var.compaction_schedule_expression
}

# Event target that invokes the compact Lambda
resource "aws_cloudwatch_event_target" "compact" {
  rule      = aws_cloudwatch_event_rule.compact_schedule.name
  target_id = "compact-lambda"
  arn       = aws_lambda_function.compact.arn
}

# Allow EventBridge to invoke compact Lambda
resource "aws_lambda_permission" "eventbridge_compact" {
  statement_id  = "AllowEventBridgeInvokeCompact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compact.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compact_schedule.arn
}
