#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://target:8080}"
THREADS="${THREADS:-5}"
RATE_LIMIT="${RATE_LIMIT:-20}"
AUTH_HEADER="${AUTH_HEADER:-Authorization: Basic ZmVyb3g6cGFja2V0bGFi}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BASE_URL" "$THREADS" "$RATE_LIMIT" "$AUTH_HEADER" <<'EOF'
set -eu

BASE_URL="$1"
THREADS="$2"
RATE_LIMIT="$3"
AUTH_HEADER="$4"
OUTPUT_DIR="/work/outputs"
WORDLIST_DIR="/work/wordlists"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/http-status.json

run_ferox() {
  name="$1"
  shift
  feroxbuster "$@" \
    --threads "$THREADS" \
    --rate-limit "$RATE_LIMIT" \
    --timeout 5 \
    --no-state \
    --dont-filter \
    --quiet \
    -o "$OUTPUT_DIR/$name.txt"
}

summarize() {
  name="$1"
  awk -v scan="$name" '
    BEGIN { print "scan\tstatus\twords\tchars\turl" }
    /https?:\/\// {
      status = words = chars = url = "-"
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[0-9][0-9][0-9]$/) status = $i
        if ($i ~ /^[0-9]+w$/) words = substr($i, 1, length($i) - 1)
        if ($i ~ /^[0-9]+c$/) chars = substr($i, 1, length($i) - 1)
        if ($i ~ /^https?:\/\//) url = $i
      }
      if (url != "-") print scan "\t" status "\t" words "\t" chars "\t" url
    }
  ' "$OUTPUT_DIR/$name.txt" > "$OUTPUT_DIR/$name.tsv"
}

run_ferox paths \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/paths.txt" \
  --status-codes 200 301 401 403 \
  --no-recursion \
  --dont-extract-links
summarize paths

run_ferox extensions \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/files.txt" \
  -x txt json html js css \
  --status-codes 200 \
  --no-recursion \
  --dont-extract-links
summarize extensions

run_ferox recursive \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/recursive.txt" \
  --status-codes 200 301 403 \
  --depth 2
summarize recursive

run_ferox auth \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/admin.txt" \
  --headers "$AUTH_HEADER" \
  --status-codes 200 403 \
  --no-recursion \
  --dont-extract-links
summarize auth

feroxbuster \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/files.txt" \
  -x txt json html js css \
  --status-codes 200 \
  --threads "$THREADS" \
  --rate-limit "$RATE_LIMIT" \
  --timeout 5 \
  --no-state \
  --dont-filter \
  --quiet \
  --json \
  --no-recursion \
  --dont-extract-links \
  -o "$OUTPUT_DIR/extensions.json"

curl -sS "$BASE_URL/api/status" > "$OUTPUT_DIR/http-status.json"
EOF

echo "Generated feroxbuster lab outputs."
