#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/outputs}"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T responder \
  responder -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T responder \
  responder --version > "$OUTPUT_DIR/version.txt" 2>&1 || true
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T responder \
  sh -lc 'ip -brief address show eth0 || ifconfig eth0' > "$OUTPUT_DIR/interface.txt" 2>&1 || true
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T responder \
  sh -lc 'rm -f /usr/share/responder/logs/*.log' > "$OUTPUT_DIR/log-reset.txt" 2>&1 || true

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T responder \
  timeout 12 responder -I eth0 -A -v \
  > "$OUTPUT_DIR/console.log" 2>&1 &
RESPONDER_PID=$!

sleep 3
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T client \
  python /opt/lab/query_client.py > "$OUTPUT_DIR/client.txt" 2>&1
wait "$RESPONDER_PID" || true
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T responder \
  sh -lc 'for file in /usr/share/responder/logs/Analyzer-Session.log /usr/share/responder/logs/Responder-Session.log /usr/share/responder/logs/Poisoners-Session.log; do [ -f "$file" ] && { printf "== %s ==\n" "$file"; cat "$file"; }; done' \
  > "$OUTPUT_DIR/analyze.log" 2>&1 || true

{
  printf 'check\tstatus\n'
  if grep -Eiq 'Analyze mode|Analyze|passive' "$OUTPUT_DIR/analyze.log"; then
    printf 'analyze_mode\tyes\n'
  else
    printf 'analyze_mode\tno\n'
  fi
  if grep -Eiq 'LLMNR|NBT-NS|NBNS|mDNS' "$OUTPUT_DIR/analyze.log"; then
    printf 'name_resolution_seen\tyes\n'
  else
    printf 'name_resolution_seen\tno\n'
  fi
  if grep -Eiq 'WPAD-LAB|FILES-LAB|PRINTER-LAB|wpad-lab|files-lab|printer-lab' "$OUTPUT_DIR/analyze.log"; then
    printf 'synthetic_names_seen\tyes\n'
  else
    printf 'synthetic_names_seen\tno\n'
  fi
  if grep -Fq 'sent synthetic' "$OUTPUT_DIR/client.txt"; then
    printf 'client_queries_sent\tyes\n'
  else
    printf 'client_queries_sent\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
  printf 'analyze_log_lines\t%s\n' "$(wc -l < "$OUTPUT_DIR/analyze.log" | tr -d ' ')"
} > "$OUTPUT_DIR/summary.tsv"

echo "Generated Responder lab outputs."
