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
variable "schedule_expression" {
  type    = string
  default = "rate(1 minute)"
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

# Lambda memory size in MB
variable "lambda_memory" {
  type    = number
  default = 512
}

# Relative path to Lambda zip artifacts
variable "lambda_artifacts_dir" {
  type    = string
  default = "../../dist"
}
