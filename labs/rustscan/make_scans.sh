#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_IP="${TARGET_IP:-172.41.110.20}"
PORTS="${PORTS:-80,2222,2525,6379,8000}"
BATCH_SIZE="${BATCH_SIZE:-64}"
TIMEOUT_MS="${TIMEOUT_MS:-1000}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_IP" "$PORTS" "$BATCH_SIZE" "$TIMEOUT_MS" <<'EOF'
set -eu

TARGET_IP="$1"
PORTS="$2"
BATCH_SIZE="$3"
TIMEOUT_MS="$4"
SCAN_DIR="/work/scans"

mkdir -p "$SCAN_DIR"
rm -f \
  "$SCAN_DIR/rustscan-basic.txt" \
  "$SCAN_DIR/rustscan-greppable.txt" \
  "$SCAN_DIR/rustscan-with-nmap.txt" \
  "$SCAN_DIR/follow-up-nmap.txt" \
  "$SCAN_DIR/open-ports.txt" \
  "$SCAN_DIR/open-ports.json" \
  "$SCAN_DIR/http-status.json"

rustscan -a "$TARGET_IP" -p "$PORTS" \
  --batch-size "$BATCH_SIZE" --timeout "$TIMEOUT_MS" --tries 1 \
  --accessible --scripts none > "$SCAN_DIR/rustscan-basic.txt"

rustscan -a "$TARGET_IP" -p "$PORTS" \
  --batch-size "$BATCH_SIZE" --timeout "$TIMEOUT_MS" --tries 1 \
  --accessible --greppable > "$SCAN_DIR/rustscan-greppable.txt"

grep -Eo '[0-9]+ -> \[[0-9, ]+\]' "$SCAN_DIR/rustscan-greppable.txt" \
  | sed -E 's/.*\[//; s/\]//' \
  | tr ',' '\n' \
  | sed 's/^ *//; s/ *$//' \
  | sed '/^$/d' \
  | sort -n > "$SCAN_DIR/open-ports.txt"

jq -Rn --arg ip "$TARGET_IP" '
  [inputs | select(length > 0) | tonumber] as $ports
  | {ip: $ip, open_ports: $ports}
' < "$SCAN_DIR/open-ports.txt" > "$SCAN_DIR/open-ports.json"

rustscan -a "$TARGET_IP" -p "$PORTS" \
  --batch-size "$BATCH_SIZE" --timeout "$TIMEOUT_MS" --tries 1 \
  --accessible -- -sV -Pn > "$SCAN_DIR/rustscan-with-nmap.txt"

nmap -sV -Pn -p "$PORTS" "$TARGET_IP" > "$SCAN_DIR/follow-up-nmap.txt"
curl -sS "http://$TARGET_IP/api/status" > "$SCAN_DIR/http-status.json"
EOF

echo "Generated rustscan lab scan outputs."
