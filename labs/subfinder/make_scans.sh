#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.51.210.20:8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
FIXTURE="/work/fixtures/passive-results.jsonl"
DOMAINS="/work/scope/domains.txt"
ALLOW="/work/scope/allow-subdomains.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.jsonl "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
subfinder -version -duc > "$OUTPUT_DIR/version.txt" 2>&1
subfinder -ls -duc -nc > "$OUTPUT_DIR/sources.txt" 2>&1

# This intentionally produces no local discoveries: passive internet sources do
# not know Docker-only training domains.
timeout 10s subfinder -dL "$DOMAINS" -duc -silent -max-time 1 > "$OUTPUT_DIR/passive-local-empty.txt" 2>/dev/null || true

cp "$FIXTURE" "$OUTPUT_DIR/passive-fixture.jsonl"

jq -r '.host' "$OUTPUT_DIR/passive-fixture.jsonl" | sort -u > "$OUTPUT_DIR/subdomains.txt"
sort -u "$ALLOW" > "$OUTPUT_DIR/allow-subdomains.sorted.txt"
comm -12 "$OUTPUT_DIR/allow-subdomains.sorted.txt" "$OUTPUT_DIR/subdomains.txt" > "$OUTPUT_DIR/in-scope.txt"

{
  printf 'host\tstatus\ttitle\n'
  while IFS= read -r host; do
    response="$(curl -sS -H "Host: $host" -o /tmp/subfinder-lab-body -w "%{http_code}" "$BASE_URL/")"
    title="$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' /tmp/subfinder-lab-body | head -1)"
    printf '%s\t%s\t%s\n' "$host" "$response" "$title"
  done < "$OUTPUT_DIR/in-scope.txt"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'domain_count\t%s\n' "$(wc -l < "$DOMAINS" | tr -d ' ')"
  printf 'fixture_subdomains\t%s\n' "$(wc -l < "$OUTPUT_DIR/subdomains.txt" | tr -d ' ')"
  printf 'in_scope_subdomains\t%s\n' "$(wc -l < "$OUTPUT_DIR/in-scope.txt" | tr -d ' ')"
  printf 'locally_validated\t%s\n' "$(awk 'NR > 1 && $2 ~ /^(200|401)$/ {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Subfinder lab outputs."
