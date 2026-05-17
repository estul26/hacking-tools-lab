#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8090}"

curl -fsS "$BASE_URL/packet-demo?source=host-loopback" >/dev/null

if command -v nc >/dev/null 2>&1; then
  printf "EHLO host.wireshark-lab.local\r\nQUIT\r\n" | nc -w 2 127.0.0.1 12526 >/dev/null || true
  printf '*1\r\n$4\r\nPING\r\n' | nc -w 2 127.0.0.1 16381 >/dev/null || true
fi

if command -v dig >/dev/null 2>&1; then
  dig @127.0.0.1 -p 15300 target.wireshark-lab.local A +short >/dev/null || true
fi

echo "Generated Wireshark lab loopback traffic."
