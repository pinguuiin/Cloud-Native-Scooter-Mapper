import json
import os
from datetime import datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

import boto3
import h3
import pyarrow as pa
import pyarrow.parquet as pq

# ========= Compatible functions for different H3 versions ========= #

# Convert lat/lon to an H3 index at a resolution
def _latlng_to_cell(lat: float, lon: float, resolution: int) -> str:
    if hasattr(h3, "latlng_to_cell"):
        return h3.latlng_to_cell(lat, lon, resolution)
    return h3.geo_to_h3(lat, lon, resolution)

# Get the center coordinate for an H3 cell
def _cell_to_latlng(h3_index: str):
    if hasattr(h3, "cell_to_latlng"):
        return h3.cell_to_latlng(h3_index)
    return h3.h3_to_geo(h3_index)

# Get H3 cell boundary coordinates
def _cell_to_boundary(h3_index: str):
    if hasattr(h3, "cell_to_boundary"):
        return h3.cell_to_boundary(h3_index)
    return h3.h3_to_geo_boundary(h3_index)

# ========================= Transformation ========================= #

# Extract required bucket/key from event or environment
def _get_raw_location(event):
    raw_bucket = event.get("bucket") or os.getenv("RAW_BUCKET")
    raw_key = event.get("key")
    if not raw_bucket or not raw_key:
        raise ValueError("bucket and key are required")
    return raw_bucket, raw_key

# Extract required processing targets from environment
def _get_processing_targets():
    agg_bucket = os.getenv("AGG_BUCKET")
    if not agg_bucket:
        raise ValueError("AGG_BUCKET is required")

    ddb_table_name = os.getenv("DDB_TABLE")
    if not ddb_table_name:
        raise ValueError("DDB_TABLE is required")

    return agg_bucket, ddb_table_name

# Parse a delimited environment variable into a list
def _env_list(name: str, cast_func=int, sep=","):
    value = os.getenv(name, "")
    if not value:
        return []
    return [cast_func(v.strip()) for v in value.split(sep) if v.strip()]

# Cast the environment variable to float, if not exist return global map
def _env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    return float(value) if value is not None else default

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

# Build snapshot metadata and time window values
def _build_snapshot_window(window_minutes: int):
    now = _get_local_time()
    snapshot_id = now.strftime("%Y%m%dT%H%M%S%z")
    window_start = (now - timedelta(minutes=window_minutes)).isoformat()
    window_end = now.isoformat()
    return now, snapshot_id, window_start, window_end

# Load a raw GBFS snapshot JSON from S3 and return the bike records
def _load_bikes_from_snapshot(s3_client, bucket: str, key: str) -> list:
    obj = s3_client.get_object(Bucket=bucket, Key=key)
    body = obj["Body"].read().decode("utf-8")
    records = json.loads(body)
    return records.get("bikes", [])

# Filter and deduplicate bike records within bounds
def _filter_unique_bikes(bikes, bounds):
    min_lat, max_lat, min_lon, max_lon = bounds
    filtered = []
    seen_ids = set()
    for bike in bikes:
        bike_id = bike.get("bike_id")
        lat = bike.get("lat")
        lon = bike.get("lon")
        if not bike_id or lat is None or lon is None:
            continue
        if bike_id in seen_ids:
            continue
        if (min_lat <= lat <= max_lat and min_lon <= lon <= max_lon):
            seen_ids.add(bike_id)
            filtered.append(bike)
    return filtered

# Aggregate bike counts by H3 resolution
def _aggregate_counts(bikes, resolutions):
    counts_by_res = {res: {} for res in resolutions}
    for bike in bikes:
        lat = bike.get("lat")
        lon = bike.get("lon")
        if lat is None or lon is None:
            continue
        for res in resolutions:
            h3_index = _latlng_to_cell(lat, lon, res)
            counts_by_res[res][h3_index] = counts_by_res[res].get(h3_index, 0) + 1
    return counts_by_res

# Write snapshot items into DynamoDB and return Parquet-ready records
def _write_ddb_snapshot(ddb_table, resolutions, counts_by_res, snapshot_id,
                        window_start, window_end):
    parquet_records = []

    for res in resolutions:
        counts = counts_by_res.get(res, {})

        # The metadata row that holds the most recent snapshot for this resolution
        ddb_table.put_item(
            Item={
                "resolution": res,
                "h3_index": "__meta__",
                "snapshot_id": snapshot_id,
                "last_updated": window_end,
            }
        )

        with ddb_table.batch_writer(overwrite_by_pkeys=["resolution", "h3_index"]) as batch:
            for h3_index, count in counts.items():
                center_lat, center_lon = _cell_to_latlng(h3_index)
                boundary = _cell_to_boundary(h3_index)

                batch.put_item(
                    Item={
                        "resolution": res,
                        "h3_index": h3_index,
                        "count": int(count),
                        "snapshot_id": snapshot_id,
                        "last_updated": window_end,
                        "window_start": window_start,
                        "window_end": window_end,
                        "center_lat": Decimal(str(center_lat)),
                        "center_lon": Decimal(str(center_lon)),
                        "boundary": [
                            {"lat": Decimal(str(lat)), "lon": Decimal(str(lon))}
                            for lat, lon in boundary
                        ],
                    }
                )

                parquet_records.append(
                    {
                        "resolution": res,
                        "h3_index": h3_index,
                        "count": int(count),
                        "snapshot_id": snapshot_id,
                        "last_updated": window_end,
                        "window_start": window_start,
                        "window_end": window_end,
                    }
                )

    return parquet_records

def _group_records_by_res(parquet_records):
    records_by_resolution = {}
    for record in parquet_records:
        res = int(record["resolution"])
        records_by_resolution.setdefault(res, []).append(record)
    return records_by_resolution

# Build the S3 key for a Parquet snapshot
def _build_parquet_key(city, now, resolution, snapshot_id):
    date_str = now.strftime("%Y-%m-%d")
    hour = now.hour
    return (
        f"aggregated/city={city}/date={date_str}/hour={hour}/resolution={resolution}/"
        f"snapshot_id={snapshot_id}.parquet"
    )

# Write aggregated records to S3 as Parquet
def _write_parquet_snapshot(s3_client, agg_bucket, key, parquet_records):
    if not parquet_records:
        return
    # Convert list of dicts to a PyArrow Table, vectorizing the Parquet writing
    table = pa.Table.from_pylist(parquet_records)
    buffer = pa.BufferOutputStream()
    pq.write_table(table, buffer)
    data = buffer.getvalue().to_pybytes()

    s3_client.put_object(
        Bucket=agg_bucket,
        Key=key,
        Body=data,
        ContentType="application/octet-stream",
    )

# Transform a raw snapshot into DynamoDB and Parquet outputs
def transform(event, context):
    raw_bucket, raw_key = _get_raw_location(event)
    agg_bucket, ddb_table_name = _get_processing_targets()

    city = os.getenv("CITY", "default")
    resolutions = _env_list("H3_RESOLUTIONS", int) or [9, 8, 7, 6]

    min_lat = _env_float("MIN_LATITUDE", -90.0)
    max_lat = _env_float("MAX_LATITUDE", 90.0)
    min_lon = _env_float("MIN_LONGITUDE", -180.0)
    max_lon = _env_float("MAX_LONGITUDE", 180.0)

    # get snapshot ID and time window
    window_minutes = int(os.getenv("WINDOW_SIZE_MINUTES", "5"))
    now, snapshot_id, window_start, window_end = _build_snapshot_window(window_minutes)

    # load bikes from S3 snapshot, filter and aggregate
    s3 = boto3.client("s3")
    bikes = _load_bikes_from_snapshot(s3, raw_bucket, raw_key)
    filtered = _filter_unique_bikes(bikes, (min_lat, max_lat, min_lon, max_lon))
    counts_by_res = _aggregate_counts(filtered, resolutions)

    # write to DynamoDB and Parquet
    ddb = boto3.resource("dynamodb").Table(ddb_table_name)
    parquet_records = _write_ddb_snapshot(
        ddb, resolutions, counts_by_res, snapshot_id, window_start, window_end
    )

    # Group records by resolution and write to separate Parquet files, for more efficient querying later
    records_by_resolution = _group_records_by_res(parquet_records)

    for res, records in records_by_resolution.items():
        parquet_key = _build_parquet_key(city, now, res, snapshot_id)
        _write_parquet_snapshot(s3, agg_bucket, parquet_key, records)

    return {
        "statusCode": 200,
        "body": json.dumps({"snapshot_id": snapshot_id, "count": len(parquet_records)}),
    }
