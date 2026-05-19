#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.59.81.20:8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
RESOURCE_DIR="/work/resources"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
msfconsole --version > "$OUTPUT_DIR/version.txt" 2>&1
msfconsole -q -x 'search type:auxiliary scanner/http/http_version; search type:auxiliary scanner/http/robots_txt; exit -y' \
  > "$OUTPUT_DIR/module-search.txt" 2>&1

msfconsole -q -r "$RESOURCE_DIR/http_version.rc" > "$OUTPUT_DIR/http-version.txt" 2>&1
msfconsole -q -r "$RESOURCE_DIR/robots_txt.rc" > "$OUTPUT_DIR/robots.txt" 2>&1

{
  printf 'check\tstatus\n'
  if grep -Eq 'Apache|PacketLab|HTTP' "$OUTPUT_DIR/http-version.txt" "$OUTPUT_DIR/http-version-spool.txt" 2>/dev/null; then
    printf 'http_version\tyes\n'
  else
    printf 'http_version\tno\n'
  fi
  if grep -Fq 'Disallow: /admin/' "$OUTPUT_DIR/robots.txt" || grep -Fq 'Disallow: /admin/' "$OUTPUT_DIR/robots-spool.txt"; then
    printf 'robots_txt\tyes\n'
  else
    printf 'robots_txt\tno\n'
  fi
  if grep -Fq 'scanner/http/http_version' "$OUTPUT_DIR/module-search.txt"; then
    printf 'http_version_module_found\tyes\n'
  else
    printf 'http_version_module_found\tno\n'
  fi
  if grep -Fq 'scanner/http/robots_txt' "$OUTPUT_DIR/module-search.txt"; then
    printf 'robots_txt_module_found\tyes\n'
  else
    printf 'robots_txt_module_found\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
  printf 'resource_scripts\t%s\n' "$(find "$RESOURCE_DIR" -name '*.rc' | wc -l | tr -d ' ')"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated MSFConsole lab outputs."
