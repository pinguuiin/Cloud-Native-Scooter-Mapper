import boto3
import json
import os
import urllib.request
from datetime import datetime
from zoneinfo import ZoneInfo

# Fetch and validate required environment variables
def _get_required_env():
    gbfs_url = os.getenv("GBFS_URL")
    if not gbfs_url:
        raise ValueError("GBFS_URL is required")

    raw_bucket = os.getenv("RAW_BUCKET")
    if not raw_bucket:
        raise ValueError("RAW_BUCKET is required")

    return gbfs_url, raw_bucket

# Cast the environment variable to float, if not exist return global map
def _env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    return float(value) if value is not None else default

# Fetch JSON payload from a URL
def _fetch_json(url: str) -> dict:
    try:
        with urllib.request.urlopen(url, timeout=15) as response:
            payload = response.read().decode("utf-8")
        return json.loads(payload)
    except (OSError, ValueError) as e:
        raise ValueError(f"Failed to fetch or parse JSON from {url}") from e

# Filter bikes within the bounding box
def _filter_bikes(bikes, bounds):
    min_lat, max_lat, min_lon, max_lon = bounds
    filtered = []
    for bike in bikes:
        lat = bike.get("lat")
        lon = bike.get("lon")
        if lat is None or lon is None:
            continue
        if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
            filtered.append(bike)
    return filtered

# Build a raw snapshot record from filtered bikes
def _build_record(now, city, gbfs_url, bikes):
    return {
        "fetched_at": now.isoformat(),
        "city": city,
        "source_url": gbfs_url,
        "bike_count": len(bikes),
        "bikes": bikes,
    }

# Store a raw snapshot in S3 and return the object key
def _store_snapshot(raw_bucket, raw_prefix, city, now, record):
    date_str = now.strftime("%Y-%m-%d")
    ts_str = now.strftime("%Y%m%dT%H%M%S%z")
    key = f"{raw_prefix.rstrip('/')}/city={city}/date={date_str}/gbfs_{ts_str}.json"

    # boto3 creates a new client object to interact with S3
    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=raw_bucket,
        Key=key,
        Body=json.dumps(record).encode("utf-8"),
        ContentType="application/json",
    )
    return key

# Invoke the transforming Lambda asynchronously
def _invoke_transform(transform_lambda_name, raw_bucket, key):
    if not transform_lambda_name:
        return
    lambda_client = boto3.client("lambda")
    lambda_client.invoke(
        FunctionName=transform_lambda_name,
        InvocationType="Event", # asynchronous invocation
        Payload=json.dumps({"bucket": raw_bucket, "key": key}).encode("utf-8"),
    )

# Fetch GBFS data, store snapshot in S3, and invoke transforming
def ingest(event, context):
    gbfs_url, raw_bucket = _get_required_env()
    raw_prefix = os.getenv("RAW_PREFIX", "raw")
    city = os.getenv("CITY", "default")

    min_lat = _env_float("MIN_LATITUDE", -90.0)
    max_lat = _env_float("MAX_LATITUDE", 90.0)
    min_lon = _env_float("MIN_LONGITUDE", -180.0)
    max_lon = _env_float("MAX_LONGITUDE", 180.0)

    now = datetime.now(ZoneInfo("Europe/Berlin"))

    # Fetch GBFS data and filter bikes within the bounding box
    payload = _fetch_json(gbfs_url)
    bikes = payload.get("data", {}).get("bikes", [])
    filtered = _filter_bikes(bikes, (min_lat, max_lat, min_lon, max_lon))

    # Build a snapshot record and store it in S3
    record = _build_record(now, city, gbfs_url, filtered)
    key = _store_snapshot(raw_bucket, raw_prefix, city, now, record)

    # Invoke the transforming Lambda asynchronously
    transform_lambda_name = os.getenv("TRANSFORM_LAMBDA_NAME")
    _invoke_transform(transform_lambda_name, raw_bucket, key)

    return {
        "statusCode": 200,
        "body": json.dumps({"bucket": raw_bucket, "key": key, "count": len(filtered)}),
    }
