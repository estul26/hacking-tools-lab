#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.56.60.20:8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
ALLOW_PATHS="/work/scope/allow-paths.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.jsonl "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
katana -version > "$OUTPUT_DIR/version.txt" 2>&1 || true
katana -h > "$OUTPUT_DIR/help.txt" 2>&1 || true

katana \
  -u "$BASE_URL" \
  -silent \
  -no-color \
  -depth 3 \
  -js-crawl \
  -known-files all \
  -form-extraction \
  -jsonl \
  -o "$OUTPUT_DIR/crawl.jsonl" > "$OUTPUT_DIR/crawl.txt" 2>"$OUTPUT_DIR/crawl.log" || true

jq -r '.request.endpoint? // .url? // empty' "$OUTPUT_DIR/crawl.jsonl" \
  2>/dev/null | sort -u > "$OUTPUT_DIR/endpoints.raw.txt" || true

if [ ! -s "$OUTPUT_DIR/endpoints.raw.txt" ]; then
  jq -r '.url? // .endpoint? // empty' "$OUTPUT_DIR/crawl.jsonl" 2>/dev/null | sort -u > "$OUTPUT_DIR/endpoints.raw.txt" || true
fi

python3 - "$OUTPUT_DIR/endpoints.raw.txt" "$OUTPUT_DIR/paths.txt" "$OUTPUT_DIR/parameterized-urls.txt" <<'PY'
import sys
from urllib.parse import urlparse

paths = set()
parameterized = set()
with open(sys.argv[1], encoding="utf-8") as source:
    for line in source:
        url = line.strip()
        if not url:
            continue
        parsed = urlparse(url)
        paths.add(parsed.path or "/")
        if parsed.query:
            parameterized.add(url)

with open(sys.argv[2], "w", encoding="utf-8") as out:
    for path in sorted(paths):
        out.write(path + "\n")
with open(sys.argv[3], "w", encoding="utf-8") as out:
    for url in sorted(parameterized):
        out.write(url + "\n")
PY

sort -u "$ALLOW_PATHS" > "$OUTPUT_DIR/allow-paths.sorted.txt"
comm -12 "$OUTPUT_DIR/allow-paths.sorted.txt" "$OUTPUT_DIR/paths.txt" > "$OUTPUT_DIR/in-scope-paths.txt"

{
  printf 'path\tstatus\n'
  while IFS= read -r path; do
    status="$(curl -sS -o /tmp/katana-lab-body -w "%{http_code}" "$BASE_URL$path")"
    printf '%s\t%s\n' "$path" "$status"
  done < "$OUTPUT_DIR/in-scope-paths.txt"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'crawled_endpoints\t%s\n' "$(wc -l < "$OUTPUT_DIR/endpoints.raw.txt" | tr -d ' ')"
  printf 'unique_paths\t%s\n' "$(wc -l < "$OUTPUT_DIR/paths.txt" | tr -d ' ')"
  printf 'in_scope_paths\t%s\n' "$(wc -l < "$OUTPUT_DIR/in-scope-paths.txt" | tr -d ' ')"
  printf 'parameterized_urls\t%s\n' "$(wc -l < "$OUTPUT_DIR/parameterized-urls.txt" | tr -d ' ')"
  printf 'locally_validated\t%s\n' "$(awk 'NR > 1 && $2 ~ /^(200|401|403)$/ {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Katana lab outputs."
