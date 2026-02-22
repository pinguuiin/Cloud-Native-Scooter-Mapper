#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"
FRONTEND_DIR="$ROOT_DIR/frontend"

API_BASE_URL="$(terraform -chdir="$TERRAFORM_DIR" output -raw api_base_url)"
FRONTEND_BUCKET="$(terraform -chdir="$TERRAFORM_DIR" output -raw frontend_bucket_name)"
CLOUDFRONT_DIST_ID="$(terraform -chdir="$TERRAFORM_DIR" output -raw cloudfront_distribution_id)"

if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
  npm --prefix "$FRONTEND_DIR" install
fi

VITE_API_BASE_URL="$API_BASE_URL" npm --prefix "$FRONTEND_DIR" run build
aws s3 sync "$FRONTEND_DIR/dist/" "s3://$FRONTEND_BUCKET" --delete
aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DIST_ID" --paths "/*"

echo "Frontend deployed."
echo "CloudFront: https://$(terraform -chdir="$TERRAFORM_DIR" output -raw cloudfront_domain)"