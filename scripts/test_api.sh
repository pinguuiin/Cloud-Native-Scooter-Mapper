#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required"
  exit 1
fi

# Resolve API base URL from env var first, then Terraform output.
API_BASE_URL="${API_BASE_URL:-}"
if [[ -z "$API_BASE_URL" ]]; then
  if [[ -d "$TERRAFORM_DIR" ]]; then
    API_BASE_URL="$(terraform -chdir="$TERRAFORM_DIR" output -raw api_base_url 2>/dev/null || true)"
  fi
fi

if [[ -z "$API_BASE_URL" ]]; then
  echo "ERROR: API base URL not found."
  echo "Set API_BASE_URL or run after terraform apply."
  exit 1
fi

API_BASE_URL="${API_BASE_URL%/}"
RESOLUTIONS=(6 7 8 9)
MIN_COUNT="${MIN_COUNT:-1}"

# Track test result counters for final summary.
pass_count=0
fail_count=0

title() {
  echo
  echo "=== $1 ==="
}

pass() {
  echo "✅️ $1"
  pass_count=$((pass_count + 1))
}

fail() {
  echo "❌ $1"
  fail_count=$((fail_count + 1))
}

# Request one endpoint and return its HTTP status code.
get_status() {
  local url="$1"
  curl -sS -o /tmp/api_test_body.json -w "%{http_code}" "$url"
}

# Run basic endpoint health checks.
title "Scooter API Consistency Test"
echo "API_BASE_URL: $API_BASE_URL"

title "Basic endpoint checks"

health_status="$(get_status "$API_BASE_URL/api/health")"
if [[ "$health_status" == "200" ]]; then
  pass "GET /api/health returns 200"
else
  fail "GET /api/health returned $health_status"
fi

stats_status="$(get_status "$API_BASE_URL/api/stats")"
if [[ "$stats_status" == "200" ]]; then
  pass "GET /api/stats returns 200"
else
  fail "GET /api/stats returned $stats_status"
fi

# Compare total bike counts across resolutions for consistency.
title "Resolution consistency checks"

declare -A total_by_res
all_totals_equal=true
reference_total=""

for res in "${RESOLUTIONS[@]}"; do
  url="$API_BASE_URL/api/heatmap?resolution=$res&min_count=$MIN_COUNT"
  status="$(get_status "$url")"

  if [[ "$status" != "200" ]]; then
    fail "GET /api/heatmap for resolution $res returned $status"
    continue
  fi

  total="$(jq -r '[.hexagons[].count] | add // 0' /tmp/api_test_body.json)"
  total_by_res[$res]="$total"

  if [[ -z "$reference_total" ]]; then
    reference_total="$total"
    pass "Resolution $res baseline total count = $total"
  else
    if [[ "$total" == "$reference_total" ]]; then
      pass "Resolution $res total count matches baseline ($total)"
    else
      fail "Resolution $res total count mismatch (expected $reference_total, got $total)"
      all_totals_equal=false
    fi
  fi

done

if [[ "$all_totals_equal" == true ]]; then
  pass "All tested resolutions have equal total bike count"
fi

# Print final test summary and exit with non-zero on failures.
title "Summary"
echo "✅️ Passed: $pass_count"
echo "❌ Failed: $fail_count"

rm -f /tmp/api_test_body.json

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi

exit 0
