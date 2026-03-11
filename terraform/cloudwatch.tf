locals {
  lambda_function_names = {
    ingest    = aws_lambda_function.ingest.function_name
    transform = aws_lambda_function.transform.function_name
    api       = aws_lambda_function.api.function_name
    compact   = aws_lambda_function.compact.function_name
  }

  eventbridge_rule_names = {
    ingest  = aws_cloudwatch_event_rule.ingest_schedule.name
    compact = aws_cloudwatch_event_rule.compact_schedule.name
  }

  alarm_actions = var.alarm_email_endpoint == null ? [] : [aws_sns_topic.alarm_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.lambda_function_names

  alarm_name          = "${each.value}-errors"
  alarm_description   = "Lambda ${each.value} reports errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.lambda_error_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration_p95" {
  for_each = local.lambda_function_names

  alarm_name          = "${each.value}-duration-p95"
  alarm_description   = "Lambda ${each.value} p95 duration is too high"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.lambda_duration_p95_alarm_ms
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "eventbridge_failed_invocations" {
  for_each = local.eventbridge_rule_names

  alarm_name          = "${each.value}-failed-invocations"
  alarm_description   = "EventBridge rule ${each.value} has failed invocations"
  namespace           = "AWS/Events"
  metric_name         = "FailedInvocations"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.eventbridge_failed_invocation_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  dimensions = {
    RuleName = each.value
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "apigw_access" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.api.name}-access"
  retention_in_days = 7
  tags              = local.common_tags
}

resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${local.project}-pipeline-${local.name_suffix}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Invocations"
          view    = "timeSeries"
          stacked = false
          stat    = "Sum"
          period  = 300
          region  = var.region
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", local.lambda_function_names.ingest, { "label" : "ingest" }],
            ["AWS/Lambda", "Invocations", "FunctionName", local.lambda_function_names.transform, { "label" : "transform" }],
            ["AWS/Lambda", "Invocations", "FunctionName", local.lambda_function_names.api, { "label" : "api" }],
            ["AWS/Lambda", "Invocations", "FunctionName", local.lambda_function_names.compact, { "label" : "compact" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Errors"
          view    = "timeSeries"
          stacked = false
          stat    = "Sum"
          period  = 300
          region  = var.region
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", local.lambda_function_names.ingest, { "label" : "ingest" }],
            ["AWS/Lambda", "Errors", "FunctionName", local.lambda_function_names.transform, { "label" : "transform" }],
            ["AWS/Lambda", "Errors", "FunctionName", local.lambda_function_names.api, { "label" : "api" }],
            ["AWS/Lambda", "Errors", "FunctionName", local.lambda_function_names.compact, { "label" : "compact" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Duration p95 (ms)"
          view    = "timeSeries"
          stacked = false
          stat    = "p95"
          period  = 300
          region  = var.region
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", local.lambda_function_names.ingest, { "label" : "ingest" }],
            ["AWS/Lambda", "Duration", "FunctionName", local.lambda_function_names.transform, { "label" : "transform" }],
            ["AWS/Lambda", "Duration", "FunctionName", local.lambda_function_names.api, { "label" : "api" }],
            ["AWS/Lambda", "Duration", "FunctionName", local.lambda_function_names.compact, { "label" : "compact" }]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Recent API Lambda Error Logs"
          region = var.region
          view   = "table"
          query  = <<-QUERY
            SOURCE '/aws/lambda/${local.lambda_function_names.api}'
            | fields @timestamp, @log, @message
            | filter @message like /ERROR|Error|Exception/
            | sort @timestamp desc
            | limit 100
          QUERY
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Recent API Gateway Access Logs"
          region = var.region
          view   = "table"
          query  = <<-QUERY
            SOURCE '${aws_cloudwatch_log_group.apigw_access.name}'
            | fields @timestamp, @message
            | sort @timestamp desc
            | limit 100
          QUERY
        }
      }
    ]
  })
}