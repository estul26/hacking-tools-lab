#!/usr/bin/env sh
set -eu

if [ -n "${ROUTES:-}" ]; then
  printf '%s\n' "$ROUTES" | while IFS= read -r route; do
    if [ -z "$route" ]; then
      continue
    fi

    attempt=0
    until ip route replace $route; do
      attempt=$((attempt + 1))
      if [ "$attempt" -ge 30 ]; then
        echo "Could not apply route: $route" >&2
        exit 1
      fi
      sleep 1
    done
  done
fi

exec "$@"
