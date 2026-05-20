#!/usr/bin/env sh
set -eu

mkdir -p /run/sshd /run/samba

smbd --foreground --no-process-group &
SMBD_PID=$!

trap 'kill "$SMBD_PID" 2>/dev/null || true' INT TERM EXIT

exec /usr/sbin/sshd -D -e
