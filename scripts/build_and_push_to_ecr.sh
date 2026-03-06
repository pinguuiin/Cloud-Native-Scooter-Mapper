#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-latest}"

INGEST_REPO=$(terraform -chdir="$ROOT_DIR/terraform" output -raw ecr_ingest_repository_url)
TRANSFORM_REPO=$(terraform -chdir="$ROOT_DIR/terraform" output -raw ecr_transform_repository_url)
API_REPO=$(terraform -chdir="$ROOT_DIR/terraform" output -raw ecr_api_repository_url)
COMPACT_REPO=$(terraform -chdir="$ROOT_DIR/terraform" output -raw ecr_compact_repository_url)
AWS_REGION="eu-north-1"

REGISTRY="$(echo "$INGEST_REPO" | cut -d'/' -f1)"

# Login to ECR using a token retrieved from AWS CLI
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker build -f "$ROOT_DIR/backend/Dockerfile.ingest" -t "$INGEST_REPO:$TAG" "$ROOT_DIR/backend"
docker build -f "$ROOT_DIR/backend/Dockerfile.transform" -t "$TRANSFORM_REPO:$TAG" "$ROOT_DIR/backend"
docker build -f "$ROOT_DIR/backend/Dockerfile.api" -t "$API_REPO:$TAG" "$ROOT_DIR/backend"
docker build -f "$ROOT_DIR/backend/Dockerfile.compact" -t "$COMPACT_REPO:$TAG" "$ROOT_DIR/backend"

docker push "$INGEST_REPO:$TAG"
docker push "$TRANSFORM_REPO:$TAG"
docker push "$API_REPO:$TAG"
docker push "$COMPACT_REPO:$TAG"

echo "Pushed Lambda images with tag: $TAG"
