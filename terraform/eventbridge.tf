# Schedule rule to trigger ingestion
resource "aws_cloudwatch_event_rule" "ingest_schedule" {
  name                = "${local.project}-ingest-${local.name_suffix}"
  schedule_expression = var.schedule_expression
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
