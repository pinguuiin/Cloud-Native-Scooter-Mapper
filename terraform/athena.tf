# Athena workgroup with S3 output location
resource "aws_athena_workgroup" "main" {
  name = "${local.project}-wg-${local.name_suffix}"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena.bucket}/results/"
    }
  }

  tags = local.common_tags
}

# Athena database pointing at aggregated bucket
resource "aws_athena_database" "main" {
  name   = "${local.project}_analytics"
  bucket = aws_s3_bucket.aggregated.bucket
}

# Glue catalog table for historical Parquet data with partition projection
resource "aws_glue_catalog_table" "historical_aggregations" {
  name          = "historical_aggregations"
  database_name = aws_athena_database.main.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                     = "TRUE"
    "classification"               = "parquet"
    "projection.enabled"           = "true"
    "projection.city.type"         = "enum"
    "projection.city.values"       = var.city
    "projection.date.type"         = "date"
    "projection.date.format"       = "yyyy-MM-dd"
    "projection.date.range"        = "2024-01-01,NOW"
    "projection.hour.type"         = "integer"
    "projection.hour.range"        = "0,23"
    "projection.resolution.type"   = "enum"
    "projection.resolution.values" = join(",", [for r in var.h3_resolutions : tostring(r)])
    "storage.location.template"    = "s3://${aws_s3_bucket.aggregated.bucket}/compacted/city=$${city}/date=$${date}/hour=$${hour}/resolution=$${resolution}/"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.aggregated.bucket}/compacted/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "h3_index"
      type = "string"
    }
    columns {
      name = "count"
      type = "int"
    }
    columns {
      name = "snapshot_id"
      type = "string"
    }
    columns {
      name = "last_updated"
      type = "string"
    }
    columns {
      name = "window_start"
      type = "string"
    }
    columns {
      name = "window_end"
      type = "string"
    }
  }

  partition_keys {
    name = "city"
    type = "string"
  }

  partition_keys {
    name = "date"
    type = "string"
  }

  partition_keys {
    name = "hour"
    type = "int"
  }

  partition_keys {
    name = "resolution"
    type = "int"
  }
}

# SQL query for hourly hexagon averages over a day
resource "aws_athena_named_query" "hourly_hexagon_avg" {
  name      = "hourly_hexagon_avg"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = <<-SQL
    SELECT
      city,
      date,
      hour,
      resolution,
      h3_index,
      avg(count) AS avg_count,
      min(count) AS min_count,
      max(count) AS max_count,
      count(*) AS snapshots
    FROM historical_aggregations
    WHERE date = '2026-03-06'
      AND city = 'aachen'
      AND resolution = 8
      AND h3_index = '8928308280fffff'
    GROUP BY city, date, hour, resolution, h3_index
    ORDER BY hour;
  SQL
}
