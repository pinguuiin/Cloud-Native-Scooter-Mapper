# Base name for provisioned resources
variable "project_name" {
  type    = string
  default = "scootermap"
}

# AWS region to deploy into
variable "region" {
  type    = string
  default = "eu-north-1"
}

# GBFS feed URL for ingestion
variable "gbfs_url" {
  type    = string
  default = "https://gbfs.api.ridedott.com/public/v2/aachen/free_bike_status.json"
}

# Timezone used by all pipeline Lambdas
variable "timezone" {
  type    = string
  default = "Europe/Berlin"
}

# City identifier used in S3 prefixes
variable "city" {
  type    = string
  default = "aachen"
}

# H3 resolutions to aggregate
variable "h3_resolutions" {
  type    = list(number)
  default = [9, 8, 7, 6]
}

# Default H3 resolution for API responses
variable "h3_default_resolution" {
  type    = number
  default = 8
}

# Latitudes/longitudes for bounds filtering
variable "min_latitude" {
  type    = number
  default = 50.72
}

variable "max_latitude" {
  type    = number
  default = 50.82
}

variable "min_longitude" {
  type    = number
  default = 6.03
}

variable "max_longitude" {
  type    = number
  default = 6.14
}

# EventBridge schedule for ingestion
variable "ingestion_schedule_expression" {
  type    = string
  default = "rate(1 minute)"
}

# EventBridge schedule for Parquet compaction
variable "compaction_schedule_expression" {
  type    = string
  default = "rate(1 hour)"
}

# Number of hours to look back from now when selecting target hour to compact
variable "compaction_lookback_hours" {
  type    = number
  default = 1
}

# Allowed CORS origins for API responses
# can be overridden with specific domains in production for better security
variable "cors_origins" {
  type    = list(string)
  default = ["*"]
}

# Lambda timeout in seconds
variable "lambda_timeout" {
  type    = number
  default = 60
}

# Image tag used for all Lambda ECR images.
variable "lambda_image_tag" {
  type    = string
  default = "latest"
}

# Lambda memory size in MB
variable "lambda_memory" {
  type    = number
  default = 512
}

# Auto-cleanup after 3 days for raw GBFS snapshots in S3.
variable "raw_retention_days" {
  type    = number
  default = 3
}

# Auto-cleanup after 7 days for aggregated Parquet snapshots in S3.
variable "aggregated_retention_days" {
  type    = number
  default = 7
}

# Auto-cleanup after 7 days for Athena query results in S3.
variable "athena_retention_days" {
  type    = number
  default = 7
}

# Optional email endpoint for CloudWatch alarm notifications.
variable "alarm_email_endpoint" {
  type    = string
  default = null
}

# Alarm threshold for Lambda error count within the alarm period.
variable "lambda_error_alarm_threshold" {
  type    = number
  default = 1
}

# Alarm threshold for Lambda p95 duration in milliseconds.
variable "lambda_duration_p95_alarm_ms" {
  type    = number
  default = 5000
}

# Alarm threshold for EventBridge failed invocations in period.
variable "eventbridge_failed_invocation_threshold" {
  type    = number
  default = 1
}
