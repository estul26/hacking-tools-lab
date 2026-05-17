#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CAPTURE_DIR="${CAPTURE_DIR:-$SCRIPT_DIR/captures}"
TARGET_IP="${TARGET_IP:-172.39.90.20}"

mkdir -p "$CAPTURE_DIR"
rm -f \
  "$CAPTURE_DIR/lab.pcap" \
  "$CAPTURE_DIR/summary.txt" \
  "$CAPTURE_DIR/http-ascii.txt" \
  "$CAPTURE_DIR/dns-hex.txt" \
  "$CAPTURE_DIR/tcp-syns.txt" \
  "$CAPTURE_DIR/capture.log"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T analyzer \
  tcpdump -i eth0 -nn -s 0 -U -w captures/lab.pcap "host $TARGET_IP" \
  > "$CAPTURE_DIR/capture.log" 2>&1 &
TCPDUMP_PID=$!

sleep 2
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T client \
  env ONCE=1 python /opt/lab/traffic_client.py
sleep 2

kill -INT "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID" || true

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T analyzer \
  tcpdump -nn -r captures/lab.pcap > "$CAPTURE_DIR/summary.txt"
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T analyzer \
  tcpdump -A -nn -r captures/lab.pcap 'tcp port 8080' > "$CAPTURE_DIR/http-ascii.txt"
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T analyzer \
  tcpdump -XX -nn -r captures/lab.pcap 'udp port 5300' > "$CAPTURE_DIR/dns-hex.txt"
docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T analyzer \
  tcpdump -nn -r captures/lab.pcap 'tcp[tcpflags] & tcp-syn != 0' > "$CAPTURE_DIR/tcp-syns.txt"

echo "Generated tcpdump lab captures."
