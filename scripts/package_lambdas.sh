#!/usr/bin/env bash
# Strict mode. Exit on error, unset variables, or pipe failures
set -euo pipefail

# Root directory is the parent directory of this script
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

mkdir -p "$DIST_DIR"

package_lambda() {
  local name="$1"
  local handler_file="$2"
  local requirements_file="$3"
  local src_dir="$ROOT_DIR/backend"
  local build_dir="$DIST_DIR/$name" # Build per Lambda to avoid dependency bloat and packaging errors
  local zip_path="$DIST_DIR/lambda_${name}.zip"

  rm -rf "$build_dir" "$zip_path"
  mkdir -p "$build_dir"

  if [[ -n "$requirements_file" && -f "$requirements_file" ]]; then
    python3 -m pip install -r "$requirements_file" -t "$build_dir"
  fi

  cp "$src_dir/$handler_file" "$build_dir/handler.py"

  (cd "$build_dir" && zip -qr "$zip_path" .)
}

package_lambda "ingest" "ingest.py" ""
package_lambda "transform" "transform.py" "$ROOT_DIR/backend/requirements.txt"
package_lambda "api" "api.py" ""

echo "Lambda packages created in $DIST_DIR"
