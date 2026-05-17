#!/usr/bin/env sh
set -eu

printf 'hello from host\nquit\n' | nc -w 2 127.0.0.1 19001 >/dev/null || true
printf '' | nc -w 2 127.0.0.1 19002 >/dev/null || true
printf 'netcat lab note from host\n' | nc -w 2 127.0.0.1 19003 >/dev/null || true
printf 'GET /api/status HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n' \
  | nc -w 2 127.0.0.1 19080 >/dev/null || true
printf 'hello udp\n' | nc -u -w 2 127.0.0.1 19004 >/dev/null || true

echo "Generated netcat lab traffic."
