#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://target:8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
TEMPLATE_DIR="/work/templates"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.jsonl "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
nuclei -version > "$OUTPUT_DIR/version.txt" 2>&1

nuclei \
  -u "$BASE_URL" \
  -t "$TEMPLATE_DIR" \
  -duc \
  -jsonl \
  -or \
  -ot \
  -o "$OUTPUT_DIR/findings.jsonl" \
  -silent >/dev/null

nuclei \
  -u "$BASE_URL" \
  -t "$TEMPLATE_DIR/local-backup-config.yaml" \
  -duc \
  -jsonl \
  -or \
  -ot \
  -o "$OUTPUT_DIR/backup-finding.jsonl" \
  -silent >/dev/null

{
  printf 'template_id\tseverity\tmatched_at\tname\n'
  jq -r '[."template-id", (.info.severity // ""), (."matched-at" // ""), (.info.name // "")] | @tsv' \
    "$OUTPUT_DIR/findings.jsonl"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Nuclei lab outputs."
