#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
HASH_DIR="/work/hashes"
WORDLIST="/work/wordlists/passwords.txt"
JOHN_HOME="$OUTPUT_DIR/john-home"

mkdir -p "$OUTPUT_DIR" "$JOHN_HOME"
rm -rf "$JOHN_HOME"
mkdir -p "$JOHN_HOME/.john"
export HOME="$JOHN_HOME"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv
rm -f /root/.john/john.pot

john > "$OUTPUT_DIR/help.txt" 2>&1 || true
grep -A1 -- "--format=NAME" "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/formats.txt" || true
sed -n '1,4p' "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/version.txt"

cp "$HASH_DIR/md5crypt.txt" "$OUTPUT_DIR/md5crypt.txt"

john \
  --wordlist="$WORDLIST" \
  --format=md5crypt \
  "$OUTPUT_DIR/md5crypt.txt" \
  > "$OUTPUT_DIR/md5crypt-crack.txt" 2>&1 || true

john \
  --show \
  --format=md5crypt \
  "$OUTPUT_DIR/md5crypt.txt" \
  > "$OUTPUT_DIR/md5crypt-show.txt" 2>&1 || true

cp /root/.john/john.pot "$OUTPUT_DIR/john.pot" 2>/dev/null || true

{
  printf 'hash_set\tcracked\ttotal\n'
  awk -F: '/^[^:]+:[^:]+/ {cracked++} /password hashes cracked/ {split($1, a, " "); total=a[1]} END {printf "md5crypt\t%d\t%d\n", cracked + 0, total + 0}' "$OUTPUT_DIR/md5crypt-show.txt"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated John lab outputs."
