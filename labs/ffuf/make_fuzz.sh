#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://target:8080}"
THREADS="${THREADS:-5}"
RATE="${RATE:-20}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BASE_URL" "$THREADS" "$RATE" <<'EOF'
set -eu

BASE_URL="$1"
THREADS="$2"
RATE="$3"
OUTPUT_DIR="/work/outputs"
WORDLIST_DIR="/work/wordlists"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/http-status.json

run_ffuf() {
  name="$1"
  shift
  ffuf -s -t "$THREADS" -rate "$RATE" "$@" -of json -o "$OUTPUT_DIR/$name.json"
}

summarize() {
  name="$1"
  jq -r '
    ["word", "status", "length", "url"],
    (.results[] | [
      (.input.FUZZ // (.input | to_entries[0].value)),
      (.status | tostring),
      (.length | tostring),
      .url
    ])
    | @tsv
  ' "$OUTPUT_DIR/$name.json" > "$OUTPUT_DIR/$name.tsv"
}

run_ffuf paths \
  -w "$WORDLIST_DIR/paths.txt" \
  -u "$BASE_URL/FUZZ" \
  -mc 200,401,403
summarize paths

run_ffuf extensions \
  -w "$WORDLIST_DIR/extensions.txt" \
  -u "$BASE_URL/files/config.FUZZ" \
  -mc 200
summarize extensions

run_ffuf vhosts \
  -w "$WORDLIST_DIR/vhosts.txt" \
  -u "$BASE_URL/" \
  -H "Host: FUZZ.ffuf.lab" \
  -mc 200
summarize vhosts

run_ffuf params \
  -w "$WORDLIST_DIR/params.txt" \
  -u "$BASE_URL/search?FUZZ=packetlab" \
  -mc 200
summarize params

run_ffuf login \
  -w "$WORDLIST_DIR/passwords.txt" \
  -u "$BASE_URL/login" \
  -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=FUZZ" \
  -mc 200
summarize login

curl -sS "$BASE_URL/api/status" > "$OUTPUT_DIR/http-status.json"
EOF

echo "Generated ffuf lab outputs."
