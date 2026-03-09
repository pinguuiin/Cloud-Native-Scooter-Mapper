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

# Athena database pointing at aggregated bucket. It's a metadata entry inside Glue Catalog
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

# SQL query template for hourly averaged number of scooters at a selected hexagon
resource "aws_athena_named_query" "hourly_hexagon_avg" {
  name      = "hourly_hexagon_avg"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = <<-SQL
  
    -- Create minutely time series for the range of aggregated data
    WITH bounds AS (
      SELECT
        MIN(date_parse(concat("date", ' ', lpad(CAST(hour AS varchar), 2, '0')), '%Y-%m-%d %H')) AS min_ts,
        MAX(date_parse(concat("date", ' ', lpad(CAST(hour AS varchar), 2, '0')), '%Y-%m-%d %H')) AS max_ts
      FROM historical_aggregations
    ),
    time_series AS (
      SELECT ts
      FROM bounds
      CROSS JOIN UNNEST(sequence(min_ts, max_ts + INTERVAL '59' MINUTE, INTERVAL '1' MINUTE)) AS t(ts)
    ),

    -- Left join the time series with historical data to get a complete table with zero values
    full_table AS (
      SELECT
        CAST(t.ts AS DATE) AS "date",
        HOUR(t.ts) AS hour,
        MINUTE(t.ts) AS minute,
        COALESCE(a.h3_index, '881fa0a00dfffff') AS h3_index,
        COALESCE(a.resolution, 8) AS resolution,
        COALESCE(a.count, 0) AS scooter_count
      FROM time_series t
      LEFT JOIN historical_aggregations a
        ON CAST(t.ts AS DATE) = CAST(a."date" AS DATE)
        AND HOUR(t.ts) = a.hour
        AND MINUTE(t.ts) = MINUTE(try_cast(a.last_updated AS timestamp))
        AND a.h3_index = '881fa0a00dfffff'
        AND a.resolution = 8
    )

    -- Aggregate the minutely data into hourly averages
    SELECT
      "date",
      hour,
      h3_index,
      resolution,
      avg(scooter_count) AS avg_count,
      min(scooter_count) AS min_count,
      max(scooter_count) AS max_count,
      count(*) AS snapshots
    FROM full_table
    GROUP BY "date", hour, h3_index, resolution
    ORDER BY "date" ASC, hour ASC;
  SQL
}
