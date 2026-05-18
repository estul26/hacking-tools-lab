#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://target:8080}"
TUNING="${TUNING:-123b}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BASE_URL" "$TUNING" <<'EOF'
set -eu

BASE_URL="$1"
TUNING="$2"
OUTPUT_DIR="/work/outputs"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.csv "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv

nikto -Version > "$OUTPUT_DIR/version.txt"

nikto \
  -h "$BASE_URL" \
  -nointeractive \
  -nocheck \
  -Tuning "$TUNING" \
  -Format txt \
  -output "$OUTPUT_DIR/baseline"

nikto \
  -h "$BASE_URL" \
  -nointeractive \
  -nocheck \
  -Tuning "$TUNING" \
  -Format csv \
  -output "$OUTPUT_DIR/baseline"

{
  printf 'scan\tfinding\n'
  awk -v scan="baseline" '
    /^\+ / {
      finding = $0
      sub(/^\+ /, "", finding)
      if (finding ~ /^(Target IP|Target Host|Target Hostname|Target Port|Start Time|End Time|Server:|No CGI Directories|[0-9]+ host)/) next
      gsub(/\t/, " ", finding)
      print scan "\t" finding
    }
  ' "$OUTPUT_DIR/baseline.txt"
} > "$OUTPUT_DIR/summary.tsv"

curl -sS "$BASE_URL/api/status" > "$OUTPUT_DIR/http-status.json"
EOF

echo "Generated Nikto lab outputs."
