#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/downloads}"
BASE_URL="${BASE_URL:-http://127.0.0.1:18081}"

run_with_host_wget() {
  mkdir -p "$OUTPUT_DIR"
  wget -q -O "$OUTPUT_DIR/status.json" "$BASE_URL/api/status"
  wget -q -O "$OUTPUT_DIR/report.txt" "$BASE_URL/files/report.txt"
  wget -q -O "$OUTPUT_DIR/redirect-report.txt" "$BASE_URL/redirect/report"
  wget -q --user=wget --password=packetlab -O "$OUTPUT_DIR/auth.txt" "$BASE_URL/auth/basic"
  wget -q -O "$OUTPUT_DIR/big.bin" "$BASE_URL/files/big.bin"
  wget -q -N -P "$OUTPUT_DIR/timestamped" "$BASE_URL/files/report.txt"
  wget -q --recursive --level=1 --no-host-directories --directory-prefix="$OUTPUT_DIR/mirror" "$BASE_URL/mirror/"
}

run_with_toolbox_wget() {
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T toolbox sh <<'EOF'
set -eu
BASE_URL="http://target:8080"
OUTPUT_DIR="/work/downloads"
mkdir -p "$OUTPUT_DIR"
wget -q -O "$OUTPUT_DIR/status.json" "$BASE_URL/api/status"
wget -q -O "$OUTPUT_DIR/report.txt" "$BASE_URL/files/report.txt"
wget -q -O "$OUTPUT_DIR/redirect-report.txt" "$BASE_URL/redirect/report"
wget -q --user=wget --password=packetlab -O "$OUTPUT_DIR/auth.txt" "$BASE_URL/auth/basic"
wget -q -O "$OUTPUT_DIR/big.bin" "$BASE_URL/files/big.bin"
wget -q -N -P "$OUTPUT_DIR/timestamped" "$BASE_URL/files/report.txt"
wget -q --recursive --level=1 --no-host-directories --directory-prefix="$OUTPUT_DIR/mirror" "$BASE_URL/mirror/"
EOF
}

if command -v wget >/dev/null 2>&1; then
  run_with_host_wget
else
  echo "Host wget not found; using the toolbox container."
  run_with_toolbox_wget
fi

echo "Generated wget lab downloads."
