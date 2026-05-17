#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_IP="${TARGET_IP:-172.38.30.20}"
TCP_PORT="${TCP_PORT:-8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T toolbox sh -s -- "$TARGET_IP" "$TCP_PORT" <<'EOF'
set -eu

TARGET_IP="$1"
TCP_PORT="$2"
OUTPUT_DIR="/work/outputs"

mkdir -p "$OUTPUT_DIR"

ip route > "$OUTPUT_DIR/routes.txt"
ping -c 3 -W 2 "$TARGET_IP" > "$OUTPUT_DIR/ping.txt"
traceroute -n -q 1 -w 2 "$TARGET_IP" > "$OUTPUT_DIR/traceroute-udp.txt"
traceroute -n -I -q 1 -w 2 "$TARGET_IP" > "$OUTPUT_DIR/traceroute-icmp.txt"
traceroute -n -T -p "$TCP_PORT" -q 1 -w 2 "$TARGET_IP" > "$OUTPUT_DIR/traceroute-tcp.txt"
curl -sS "http://$TARGET_IP:$TCP_PORT/api/status" > "$OUTPUT_DIR/http-status.json"
EOF

echo "Generated traceroute lab outputs."
