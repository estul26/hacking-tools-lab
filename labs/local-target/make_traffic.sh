#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://127.0.0.1:8088}"

curl -fsS "$BASE_URL/" >/dev/null
curl -fsS "$BASE_URL/api/status" >/dev/null
curl -fsS "$BASE_URL/api/users" >/dev/null
curl -fsS "$BASE_URL/api/orders?owner=analyst" >/dev/null
curl -fsS "$BASE_URL/search?q=host-loopback" >/dev/null
curl -fsS -L "$BASE_URL/redirect" >/dev/null
curl -fsS -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "username=analyst&password=packetlab" \
  "$BASE_URL/login" >/dev/null

if command -v nc >/dev/null 2>&1; then
  printf "EHLO host.local-target.lab\r\nQUIT\r\n" | nc -w 2 127.0.0.1 2525 >/dev/null || true
  printf '*1\r\n$4\r\nPING\r\n' | nc -w 2 127.0.0.1 16379 >/dev/null || true
fi

if command -v dig >/dev/null 2>&1; then
  dig @127.0.0.1 -p 5300 target.local-target.lab A +short >/dev/null || true
fi

echo "Generated local target traffic."
