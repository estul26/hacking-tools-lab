#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.50.200.20:8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
TARGET_LIST="/work/targets/urls.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.jsonl "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
httpx -version -duc > "$OUTPUT_DIR/version.txt" 2>&1

httpx \
  -list "$TARGET_LIST" \
  -duc \
  -status-code \
  -title \
  -web-server \
  -tech-detect \
  -location \
  -content-length \
  -response-time \
  -favicon \
  -json \
  -silent \
  -o "$OUTPUT_DIR/probes.jsonl" >/dev/null

httpx \
  -u "$BASE_URL/redirect" \
  -duc \
  -status-code \
  -location \
  -follow-redirects \
  -title \
  -json \
  -silent \
  -o "$OUTPUT_DIR/redirect-follow.jsonl" >/dev/null

httpx \
  -u "$BASE_URL/admin/" \
  -duc \
  -status-code \
  -web-server \
  -include-response-header \
  -json \
  -silent \
  -o "$OUTPUT_DIR/admin-headers.jsonl" >/dev/null

{
  printf 'url\tstatus\ttitle\tserver\tlocation\tcontent_length\tresponse_time\ttech\n'
  jq -r '[
    (.url // .input // ""),
    ((."status-code" // .status_code // "") | tostring),
    (.title // ""),
    (.webserver // ."web-server" // ""),
    (.location // ""),
    ((."content-length" // .content_length // "") | tostring),
    ((."response-time" // .response_time // .time // "") | tostring),
    ((.tech // []) | join(","))
  ] | @tsv' "$OUTPUT_DIR/probes.jsonl"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated HTTPX lab outputs."
