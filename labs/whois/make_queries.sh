#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/outputs}"
SERVER="${SERVER:-127.0.0.1}"
PORT="${PORT:-1043}"

run_with_host_whois() {
  mkdir -p "$OUTPUT_DIR"
  whois -h "$SERVER" -p "$PORT" example.test > "$OUTPUT_DIR/domain.txt"
  whois -h "$SERVER" -p "$PORT" packetlab.test > "$OUTPUT_DIR/packetlab.txt"
  whois -h "$SERVER" -p "$PORT" 172.37.80.20 > "$OUTPUT_DIR/ip.txt"
  whois -h "$SERVER" -p "$PORT" AS64512 > "$OUTPUT_DIR/asn.txt"
  whois -h "$SERVER" -p "$PORT" ABUSE-WHOIS-LAB > "$OUTPUT_DIR/contact.txt"
  whois -h "$SERVER" -p "$PORT" missing.test > "$OUTPUT_DIR/no-match.txt"
}

run_with_toolbox_whois() {
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T toolbox sh <<'EOF'
set -eu
OUTPUT_DIR="/work/outputs"
mkdir -p "$OUTPUT_DIR"
whois -h target -p 43 example.test > "$OUTPUT_DIR/domain.txt"
whois -h target -p 43 packetlab.test > "$OUTPUT_DIR/packetlab.txt"
whois -h target -p 43 172.37.80.20 > "$OUTPUT_DIR/ip.txt"
whois -h target -p 43 AS64512 > "$OUTPUT_DIR/asn.txt"
whois -h target -p 43 ABUSE-WHOIS-LAB > "$OUTPUT_DIR/contact.txt"
whois -h target -p 43 missing.test > "$OUTPUT_DIR/no-match.txt"
EOF
}

if [ "${USE_HOST_WHOIS:-}" = "1" ] && command -v whois >/dev/null 2>&1; then
  run_with_host_whois
else
  echo "Using the toolbox WHOIS client. Set USE_HOST_WHOIS=1 to try host whois."
  run_with_toolbox_whois
fi

printf 'example.test\r\n' | nc -w 2 "$SERVER" "$PORT" > "$OUTPUT_DIR/raw-netcat.txt" || true

echo "Generated whois lab query outputs."
