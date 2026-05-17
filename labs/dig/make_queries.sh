#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/outputs}"
SERVER="${SERVER:-127.0.0.1}"
PORT="${PORT:-1053}"

run_with_host_dig() {
  mkdir -p "$OUTPUT_DIR"
  dig @"$SERVER" -p "$PORT" www.dig.lab.test A > "$OUTPUT_DIR/a.txt"
  dig @"$SERVER" -p "$PORT" api.dig.lab.test A +short > "$OUTPUT_DIR/cname-short.txt"
  dig @"$SERVER" -p "$PORT" dig.lab.test MX +short > "$OUTPUT_DIR/mx-short.txt"
  dig @"$SERVER" -p "$PORT" text.dig.lab.test TXT +short > "$OUTPUT_DIR/txt-short.txt"
  dig @"$SERVER" -p "$PORT" ipv6.dig.lab.test AAAA +short > "$OUTPUT_DIR/aaaa-short.txt"
  dig @"$SERVER" -p "$PORT" -x 172.36.70.20 +short > "$OUTPUT_DIR/ptr-short.txt"
  dig @"$SERVER" -p "$PORT" +tcp www.dig.lab.test A +short > "$OUTPUT_DIR/tcp-short.txt"
  dig @"$SERVER" -p "$PORT" missing.dig.lab.test A > "$OUTPUT_DIR/nxdomain.txt"
}

run_with_toolbox_dig() {
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T toolbox sh <<'EOF'
set -eu
OUTPUT_DIR="/work/outputs"
mkdir -p "$OUTPUT_DIR"
dig @target -p 5353 www.dig.lab.test A > "$OUTPUT_DIR/a.txt"
dig @target -p 5353 api.dig.lab.test A +short > "$OUTPUT_DIR/cname-short.txt"
dig @target -p 5353 dig.lab.test MX +short > "$OUTPUT_DIR/mx-short.txt"
dig @target -p 5353 text.dig.lab.test TXT +short > "$OUTPUT_DIR/txt-short.txt"
dig @target -p 5353 ipv6.dig.lab.test AAAA +short > "$OUTPUT_DIR/aaaa-short.txt"
dig @target -p 5353 -x 172.36.70.20 +short > "$OUTPUT_DIR/ptr-short.txt"
dig @target -p 5353 +tcp www.dig.lab.test A +short > "$OUTPUT_DIR/tcp-short.txt"
dig @target -p 5353 missing.dig.lab.test A > "$OUTPUT_DIR/nxdomain.txt"
EOF
}

if command -v dig >/dev/null 2>&1; then
  run_with_host_dig
else
  echo "Host dig not found; using the toolbox container."
  run_with_toolbox_dig
fi

echo "Generated dig lab query outputs."
