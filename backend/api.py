import boto3
from boto3.dynamodb.conditions import Attr, Key
import json
import os
from decimal import Decimal

# Extract method, path, and query parameters from the event
def _get_request_parts(event):
    method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod")
        or "GET"
    )
    path = event.get("rawPath") or event.get("path") or "/"
    params = event.get("queryStringParameters") or {}
    return method, path, params

# Pick the first allowed CORS origin or wildcard
def _get_cors_origin():
    origins = os.getenv("CORS_ORIGINS", "*")
    return origins.split(",")[0].strip() if origins else "*"

# Serialize Decimal values in JSON responses
def _json_default(value):
    if isinstance(value, Decimal):
        return float(value)
    raise TypeError(f"Type not serializable: {type(value)}")

# Build a JSON HTTP response with CORS headers
def _response(status_code, body, headers=None):
    base_headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": _get_cors_origin(),
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
    }
    if headers:
        base_headers.update(headers)

    return {
        "statusCode": status_code,
        "headers": base_headers,
        "body": json.dumps(body, default=_json_default),
    }

# Cast a query string parameter to int with a default
def _parse_int(params, name, default):
    value = params.get(name) if params else None
    if value is None or value == "":
        return default
    try:
        return int(value)
    except ValueError:
        return default


# Build health response payload
def _handle_health():
    return _response(200, {"status": "ok"})

# Build stats response payload
def _handle_stats(table_name):
    client = boto3.client("dynamodb")
    table_info = client.describe_table(TableName=table_name)["Table"]
    return _response(
        200,
        {
            "table": table_name,
            "item_count": table_info.get("ItemCount"),
            "last_updated": table_info.get("TableStatus"),
        },
    )


# Query the latest snapshot items for a resolution
def _query_snapshot(table, resolution, min_count):
    meta = table.get_item(Key={"resolution": resolution, "h3_index": "__meta__"})
    snapshot_id = meta.get("Item", {}).get("snapshot_id")
    if not snapshot_id:
        return snapshot_id, []

    response = table.query(
        KeyConditionExpression=Key("resolution").eq(resolution),
        FilterExpression=(
            Attr("snapshot_id").eq(snapshot_id)
            & Attr("count").gte(min_count)
        ),
    )

    items = [
        item for item in response.get("Items", []) if item.get("h3_index") != "__meta__"
    ]
    return snapshot_id, items

# Build GeoJSON features from DynamoDB items
def _build_geojson_features(items, resolution):
    features = []
    for item in items:
        boundary = item.get("boundary", [])
        coordinates = [[float(p["lon"]), float(p["lat"])] for p in boundary]
        if coordinates:
            coordinates.append(coordinates[0])

        features.append(
            {
                "type": "Feature",
                "geometry": {"type": "Polygon", "coordinates": [coordinates]},
                "properties": {
                    "h3_index": item.get("h3_index"),
                    "count": int(item.get("count", 0)),
                    "resolution": resolution,
                    "last_updated": item.get("last_updated"),
                },
            }
        )
    return features

# Build heatmap GeoJSON response
def _handle_geojson(table, resolution, min_count):
    snapshot_id, items = _query_snapshot(table, resolution, min_count)
    features = _build_geojson_features(items, resolution)
    return _response(
        200,
        {
            "type": "FeatureCollection",
            "features": features,
            "properties": {
                "snapshot_id": snapshot_id,
                "resolution": resolution,
                "hexagon_count": len(features),
            },
        },
    )


# Build hexagon response items from DynamoDB records
def _build_heatmap_hexagons(items):
    hexagons = []
    for item in items:
        boundary = item.get("boundary", [])
        hexagons.append(
            {
                "h3_index": item.get("h3_index"),
                "center": {
                    "lat": float(item.get("center_lat")),
                    "lon": float(item.get("center_lon")),
                },
                "boundary": [
                    {"lat": float(p["lat"]), "lon": float(p["lon"])} for p in boundary
                ],
                "count": int(item.get("count", 0)),
                "last_updated": item.get("last_updated"),
            }
        )
    return hexagons

# Build heatmap JSON response
def _handle_heatmap(table, resolution, min_count):
    snapshot_id, items = _query_snapshot(table, resolution, min_count)
    hexagons = _build_heatmap_hexagons(items)
    return _response(
        200,
        {
            "resolution": resolution,
            "snapshot_id": snapshot_id,
            "hexagons": hexagons,
            "hexagon_count": len(hexagons),
        },
    )


# Route API Gateway requests to heatmap, stats, and health endpoints
def api_handler(event, context):
    method, path, params = _get_request_parts(event)

    if method == "OPTIONS":
        return _response(204, {})

    table_name = os.getenv("DDB_TABLE")
    if not table_name:
        return _response(500, {"error": "DDB_TABLE is required"})

    default_resolution = int(os.getenv("H3_DEFAULT_RESOLUTION", "8"))
    min_count = _parse_int(params, "min_count", 1)
    resolution = _parse_int(params, "resolution", default_resolution)

    table = boto3.resource("dynamodb").Table(table_name)

    if path.endswith("/api/health") or path == "/api/health":
        return _handle_health()

    if path.endswith("/api/stats") or path == "/api/stats":
        return _handle_stats(table_name)

    if path.endswith("/api/heatmap/geojson") or path == "/api/heatmap/geojson":
        return _handle_geojson(table, resolution, min_count)

    if path.endswith("/api/heatmap") or path == "/api/heatmap":
        return _handle_heatmap(table, resolution, min_count)

    return _response(404, {"error": "Not found"})
