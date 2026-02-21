#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-latest}"

INGEST_REPO=$(terraform -chdir="$ROOT_DIR/terraform" output -raw ecr_ingest_repository_url)
TRANSFORM_REPO=$(terraform -chdir="$ROOT_DIR/terraform" output -raw ecr_transform_repository_url)
API_REPO=$(terraform -chdir="$ROOT_DIR/terraform" output -raw ecr_api_repository_url)
AWS_REGION=$(terraform -chdir="$ROOT_DIR/terraform" output -raw aws_region)

REGISTRY="$(echo "$INGEST_REPO" | cut -d'/' -f1)"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

docker build -f "$ROOT_DIR/backend/Dockerfile.ingest" -t "$INGEST_REPO:$TAG" "$ROOT_DIR/backend"
docker build -f "$ROOT_DIR/backend/Dockerfile.transform" -t "$TRANSFORM_REPO:$TAG" "$ROOT_DIR/backend"
docker build -f "$ROOT_DIR/backend/Dockerfile.api" -t "$API_REPO:$TAG" "$ROOT_DIR/backend"

docker push "$INGEST_REPO:$TAG"
docker push "$TRANSFORM_REPO:$TAG"
docker push "$API_REPO:$TAG"

echo "Pushed Lambda images with tag: $TAG"
