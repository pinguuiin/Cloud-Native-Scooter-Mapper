import json
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import boto3
import pyarrow as pa
import pyarrow.parquet as pq


# Parse a delimited environment variable into a list
def _env_list(name: str, cast_func=int, sep=","):
    value = os.getenv(name, "")
    if not value:
        return []
    return [cast_func(v.strip()) for v in value.split(sep) if v.strip()]

# Get local time based on timezone in environment
def _get_local_time() -> datetime:
    timezone = os.getenv("TIMEZONE")
    if not timezone:
        raise ValueError("TIMEZONE is required")
    try:
        ZoneInfo(timezone)
    except ValueError as e:
        raise ValueError(f"Invalid TIMEZONE '{timezone}'") from e

    return datetime.now(ZoneInfo(timezone))

# Read compaction targets and runtime options from environment
def _get_targets():
    agg_bucket = os.getenv("AGG_BUCKET")
    if not agg_bucket:
        raise ValueError("AGG_BUCKET is required")

    city = os.getenv("CITY", "default")
    resolutions = _env_list("H3_RESOLUTIONS", int) or [9, 8, 7, 6]
    now = _get_local_time()
    lookback_hours = int(os.getenv("COMPACTION_LOOKBACK_HOURS", "1"))
    delete_source = os.getenv("DELETE_SOURCE_AFTER_COMPACT", "true").lower() == "true"

    return agg_bucket, city, resolutions, now, lookback_hours, delete_source

# Compute the target time range (clock-hour) for compaction based on lookback
def _target_time(now: datetime, lookback_hours: int):
    hour_boundary = now.replace(minute=0, second=0, microsecond=0)
    target = hour_boundary - timedelta(hours=lookback_hours)
    return target.strftime("%Y-%m-%d"), target.hour

# List minute-level snapshot parquet keys under a partition prefix
def _list_snapshot_keys(s3_client, bucket: str, prefix: str):
    paginator = s3_client.get_paginator("list_objects_v2")
    keys = []

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for item in page.get("Contents", []):
            key = item["Key"]
            file_name = key.rsplit("/", 1)[-1]
            if not (file_name.startswith("snapshot_id=") and file_name.endswith(".parquet")):
                continue
            keys.append(key)

    return keys

# Read a set of parquet objects from S3 into PyArrow tables
def _read_tables(s3_client, bucket: str, keys: list[str]):
    tables = []
    for key in keys:
        obj = s3_client.get_object(Bucket=bucket, Key=key)
        data = obj["Body"].read()
        table = pq.read_table(pa.BufferReader(data))
        tables.append(table)
    return tables

# Write a compacted parquet table back to S3
def _write_compacted_table(s3_client, bucket: str, key: str, table: pa.Table):
    buffer = pa.BufferOutputStream()
    pq.write_table(table, buffer)
    data = buffer.getvalue().to_pybytes()

    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType="application/octet-stream",
    )

# Delete source parquet objects from S3 in batches
def _delete_keys(s3_client, bucket: str, keys: list[str]):
    if not keys:
        return

    for i in range(0, len(keys), 1000):
        batch = keys[i : i + 1000]
        s3_client.delete_objects(
            Bucket=bucket,
            Delete={"Objects": [{"Key": key} for key in batch], "Quiet": True},
        )

# Compact minute parquet files into one file per date/hour/resolution partition
def compact(event, context):
    agg_bucket, city, resolutions, now, lookback_hours, delete_source = _get_targets()
    date_str, hour = _target_time(now, lookback_hours)

    s3 = boto3.client("s3")

    scanned_files = 0
    compacted_files = 0
    compacted_rows = 0

    for resolution in resolutions:
        partition_prefix = (
            f"aggregated/city={city}/date={date_str}/hour={hour}/resolution={resolution}/"
        )
        # List all snapshot files for the current resolution
        snapshot_keys = _list_snapshot_keys(s3, agg_bucket, partition_prefix)
        scanned_files += len(snapshot_keys)

        if len(snapshot_keys) < 1:
            continue
        # Read snapshot files into PyArrow tables, concatenate, and write back as one file
        tables = _read_tables(s3, agg_bucket, snapshot_keys)
        compacted_table = pa.concat_tables(tables, promote_options="default")
        compacted_key = (
            f"compacted/city={city}/date={date_str}/hour={hour}/resolution={resolution}/"
            "compacted.parquet"
        )
        _write_compacted_table(s3, agg_bucket, compacted_key, compacted_table)

        compacted_files += 1
        compacted_rows += compacted_table.num_rows

        if delete_source:
            _delete_keys(s3, agg_bucket, snapshot_keys)

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "target_date": date_str,
                "target_hour": hour,
                "resolutions": resolutions,
                "files_scanned": scanned_files,
                "partitions_compacted": compacted_files,
                "rows_written": compacted_rows,
            }
        ),
    }
