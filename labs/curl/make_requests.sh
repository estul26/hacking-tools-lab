#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:18080}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/outputs}"

mkdir -p "$OUTPUT_DIR"

curl -fsS "$BASE_URL/health" >/dev/null
curl -fsS "$BASE_URL/api/status" >/dev/null
curl -fsS -H "X-Lab-Trace: make-requests" "$BASE_URL/api/headers" >/dev/null
curl -fsS "$BASE_URL/api/query?tool=curl&mode=lab" >/dev/null
curl -fsS -L "$BASE_URL/redirect-chain/1" >/dev/null
curl -fsS -c "$OUTPUT_DIR/cookies.txt" -b "$OUTPUT_DIR/cookies.txt" "$BASE_URL/cookies/set" >/dev/null
curl -fsS -b "$OUTPUT_DIR/cookies.txt" "$BASE_URL/cookies/check" >/dev/null
curl -fsS -u curl:packetlab "$BASE_URL/auth/basic" >/dev/null
curl -fsS -H "Content-Type: application/json" \
  -d '{"tool":"curl","mode":"json"}' "$BASE_URL/api/echo" >/dev/null
curl -fsS -d "name=curl&feature=forms" "$BASE_URL/forms" >/dev/null
curl -fsS -X PUT --data-binary "uploaded from make_requests.sh" "$BASE_URL/upload" >/dev/null
curl -fsS -r 0-24 "$BASE_URL/range/data.txt" >/dev/null
curl -fsS "$BASE_URL/download/report.txt" -o "$OUTPUT_DIR/report.txt"

echo "Generated curl lab requests."
