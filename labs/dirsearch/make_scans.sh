#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://target:8080}"
THREADS="${THREADS:-5}"
MAX_RATE="${MAX_RATE:-20}"
EXTENSIONS="${EXTENSIONS:-txt,json,html,js,css}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BASE_URL" "$THREADS" "$MAX_RATE" "$EXTENSIONS" <<'EOF'
set -eu

BASE_URL="$1"
THREADS="$2"
MAX_RATE="$3"
EXTENSIONS="$4"
OUTPUT_DIR="/work/outputs"
WORDLIST_DIR="/work/wordlists"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/http-status.json

run_dirsearch() {
  name="$1"
  shift
  dirsearch "$@" \
    --threads "$THREADS" \
    --max-rate "$MAX_RATE" \
    --timeout 5 \
    --no-color \
    --quiet-mode \
    --format plain \
    -o "$OUTPUT_DIR/$name.txt"
}

summarize() {
  name="$1"
  awk -v scan="$name" '
    BEGIN { print "scan\tresult" }
    NF && $1 != "#" {
      gsub(/\t/, " ")
      print scan "\t" $0
    }
  ' "$OUTPUT_DIR/$name.txt" > "$OUTPUT_DIR/$name.tsv"
}

run_dirsearch paths \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/paths.txt" \
  -e "$EXTENSIONS" \
  -i 200,301,401,403
summarize paths

run_dirsearch files \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/files.txt" \
  -e "$EXTENSIONS" \
  -i 200
summarize files

run_dirsearch recursive \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/recursive.txt" \
  -e "$EXTENSIONS" \
  -i 200,301,403 \
  -r \
  -R 2 \
  --recursion-status 200,301
summarize recursive

run_dirsearch auth \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/admin.txt" \
  -e "$EXTENSIONS" \
  --auth dirsearch:packetlab \
  --auth-type basic \
  -i 200,403
summarize auth

dirsearch \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/files.txt" \
  -e "$EXTENSIONS" \
  -i 200 \
  --threads "$THREADS" \
  --max-rate "$MAX_RATE" \
  --timeout 5 \
  --no-color \
  --quiet-mode \
  --format json \
  -o "$OUTPUT_DIR/files.json"

curl -sS "$BASE_URL/api/status" > "$OUTPUT_DIR/http-status.json"
EOF

echo "Generated dirsearch lab outputs."
