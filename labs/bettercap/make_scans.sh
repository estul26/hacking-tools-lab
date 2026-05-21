#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_WEB="${TARGET_WEB:-172.68.90.20}"
TARGET_SERVICES="${TARGET_SERVICES:-172.68.90.30}"
SUBNET="${SUBNET:-172.68.90.0/24}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_WEB" "$TARGET_SERVICES" "$SUBNET" <<'EOF'
set -eu

TARGET_WEB="$1"
TARGET_SERVICES="$2"
SUBNET="$3"
OUTPUT_DIR="/work/outputs"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if curl -fsS "http://$TARGET_WEB/" >/dev/null 2>&1 && nc -z "$TARGET_SERVICES" 2222 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

bettercap -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
bettercap -version > "$OUTPUT_DIR/version.txt" 2>&1 || true
ip -brief address > "$OUTPUT_DIR/interfaces.txt"
ip route > "$OUTPUT_DIR/routes.txt"
curl -fsS "http://$TARGET_WEB/" > "$OUTPUT_DIR/web-health.json"
nc -vz "$TARGET_WEB" 80 > "$OUTPUT_DIR/web-port.txt" 2>&1 || true
nc -vz "$TARGET_SERVICES" 2222 > "$OUTPUT_DIR/ssh-port.txt" 2>&1 || true
nc -vz "$TARGET_SERVICES" 2525 > "$OUTPUT_DIR/smtp-port.txt" 2>&1 || true

timeout 12s bettercap -no-colors -eval "help net.recon; help net.probe; help syn.scan; quit" \
  > "$OUTPUT_DIR/module-help.txt" 2>&1 || true

timeout 20s bettercap -no-colors -eval \
  "set net.probe.throttle 50; net.probe on; sleep 4; net.show; syn.scan $TARGET_WEB 70 90; sleep 1; syn.scan $TARGET_WEB 8070 8090; sleep 1; syn.scan $TARGET_SERVICES 2220 2230; sleep 1; syn.scan $TARGET_SERVICES 2520 2530; sleep 1; quit" \
  > "$OUTPUT_DIR/bettercap-discovery.txt" 2>&1 || true

awk '
  /net\.recon|net\.probe|syn\.scan/ { print }
' "$OUTPUT_DIR/module-help.txt" > "$OUTPUT_DIR/safe-modules.txt"

{
  printf 'target\tport\tstatus\n'
  for item in "$TARGET_WEB:80" "$TARGET_WEB:8080" "$TARGET_SERVICES:2222" "$TARGET_SERVICES:2525"; do
    host="${item%:*}"
    port="${item#*:}"
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      printf '%s\t%s\topen\n' "$host" "$port"
    else
      printf '%s\t%s\tclosed\n' "$host" "$port"
    fi
  done
} > "$OUTPUT_DIR/port-baseline.tsv"

jq -Rn '
  [inputs
  | split("\t")
  | select(length == 3 and .[0] != "target")
  | {target: .[0], port: (.[1] | tonumber), status: .[2]}]
' "$OUTPUT_DIR/port-baseline.tsv" > "$OUTPUT_DIR/port-baseline.json"

{
  printf 'check\tstatus\n'
  if grep -Eiq 'Usage of bettercap|bettercap' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if grep -Eiq 'bettercap v[0-9]' "$OUTPUT_DIR/version.txt"; then
    printf 'version_available\tyes\n'
  else
    printf 'version_available\tno\n'
  fi
  if grep -Fq "$TARGET_WEB" "$OUTPUT_DIR/bettercap-discovery.txt" && grep -Fq "$TARGET_SERVICES" "$OUTPUT_DIR/bettercap-discovery.txt"; then
    printf 'targets_seen_by_bettercap\tyes\n'
  else
    printf 'targets_seen_by_bettercap\tno\n'
  fi
  if grep -Eiq 'syn\.scan|open port|started syn scanner|progress' "$OUTPUT_DIR/bettercap-discovery.txt"; then
    printf 'syn_scan_ran\tyes\n'
  else
    printf 'syn_scan_ran\tno\n'
  fi
  if awk -F'\t' 'NR > 1 && $3 == "open" {count++} END {exit(count >= 4 ? 0 : 1)}' "$OUTPUT_DIR/port-baseline.tsv"; then
    printf 'baseline_ports_open\tyes\n'
  else
    printf 'baseline_ports_open\tno\n'
  fi
  if grep -Fq 'net.probe' "$OUTPUT_DIR/safe-modules.txt" && grep -Fq 'net.recon' "$OUTPUT_DIR/safe-modules.txt"; then
    printf 'safe_module_help_saved\tyes\n'
  else
    printf 'safe_module_help_saved\tno\n'
  fi
  if jq -e 'length == 4' "$OUTPUT_DIR/port-baseline.json" >/dev/null; then
    printf 'json_summary_written\tyes\n'
  else
    printf 'json_summary_written\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'subnet\t%s\n' "$SUBNET"
  printf 'target_web\t%s\n' "$TARGET_WEB"
  printf 'target_services\t%s\n' "$TARGET_SERVICES"
  printf 'baseline_open_ports\t%s\n' "$(awk -F'\t' 'NR > 1 && $3 == "open" {count++} END {print count + 0}' "$OUTPUT_DIR/port-baseline.tsv")"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Bettercap lab outputs."
