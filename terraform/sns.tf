resource "aws_sns_topic" "alarm_notifications" {
  name = "${local.project}-alarms-${local.name_suffix}"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  for_each = var.alarm_email_endpoint == null ? {} : { primary = var.alarm_email_endpoint }

  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = each.value
}
