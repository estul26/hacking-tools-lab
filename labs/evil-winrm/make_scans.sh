#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_HOST="${TARGET_HOST:-172.67.89.20}"
TARGET_PORT="${TARGET_PORT:-5985}"
LAB_USER="${LAB_USER:-labadmin}"
LAB_PASS="${LAB_PASS:-LabPass2026!}"
BASE_URL="http://$TARGET_HOST:$TARGET_PORT"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_HOST" "$TARGET_PORT" "$LAB_USER" "$LAB_PASS" "$BASE_URL" <<'EOF'
set -eu

TARGET_HOST="$1"
TARGET_PORT="$2"
LAB_USER="$3"
LAB_PASS="$4"
BASE_URL="$5"
OUTPUT_DIR="/work/outputs"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
nc -vz "$TARGET_HOST" "$TARGET_PORT" > "$OUTPUT_DIR/winrm-port.txt" 2>&1 || true
script -q -c "evil-winrm -h" /dev/null > "$OUTPUT_DIR/help.txt" 2>&1 || true
script -q -c "evil-winrm -V" /dev/null > "$OUTPUT_DIR/version.txt" 2>&1 || true

curl -sS -i "$BASE_URL/wsman" > "$OUTPUT_DIR/wsman-unauthenticated.txt"
curl -sS -i -u "$LAB_USER:$LAB_PASS" \
  -H "Content-Type: application/soap+xml;charset=UTF-8" \
  --data '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body/></s:Envelope>' \
  "$BASE_URL/wsman" > "$OUTPUT_DIR/wsman-basic-auth.txt" || true

timeout 12s script -q -c "evil-winrm -i $TARGET_HOST -P $TARGET_PORT -U /wsman -u $LAB_USER -p '$LAB_PASS' -n" \
  /dev/null > "$OUTPUT_DIR/evil-winrm-attempt.txt" 2>&1 || true

curl -fsS "$BASE_URL/events" > "$OUTPUT_DIR/target-events.json"

{
  printf 'check\tstatus\n'
  if grep -Eiq 'Evil-WinRM|Usage:' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if grep -Fq '"status": "ok"' "$OUTPUT_DIR/http-status.json"; then
    printf 'target_health_ok\tyes\n'
  else
    printf 'target_health_ok\tno\n'
  fi
  if grep -Eq 'HTTP/[0-9.]+ 401|WWW-Authenticate' "$OUTPUT_DIR/wsman-unauthenticated.txt"; then
    printf 'wsman_auth_required\tyes\n'
  else
    printf 'wsman_auth_required\tno\n'
  fi
  if grep -Fq 'Local lab endpoint reached' "$OUTPUT_DIR/wsman-basic-auth.txt"; then
    printf 'soap_fault_seen\tyes\n'
  else
    printf 'soap_fault_seen\tno\n'
  fi
  if grep -Eiq 'evil-winrm|winrm|authorization|connection|error|endpoint' "$OUTPUT_DIR/evil-winrm-attempt.txt"; then
    printf 'evil_winrm_attempt_recorded\tyes\n'
  else
    printf 'evil_winrm_attempt_recorded\tno\n'
  fi
  if jq -e '.events[] | select(.path == "/wsman")' "$OUTPUT_DIR/target-events.json" >/dev/null; then
    printf 'target_logged_wsman\tyes\n'
  else
    printf 'target_logged_wsman\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'target\t%s:%s\n' "$TARGET_HOST" "$TARGET_PORT"
  printf 'credential\t%s:%s\n' "$LAB_USER" "$LAB_PASS"
  printf 'wsman_events\t%s\n' "$(jq '[.events[] | select(.path == "/wsman")] | length' "$OUTPUT_DIR/target-events.json")"
  printf 'auth_types_seen\t%s\n' "$(jq -r '[.events[].auth_type] | unique | join(",")' "$OUTPUT_DIR/target-events.json")"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Evil-WinRM lab outputs."
