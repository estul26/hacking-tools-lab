#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
HASH_DIR="/work/hashes"
WORDLIST="/work/wordlists/passwords.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.potfile "$OUTPUT_DIR"/*.tsv

hashcat --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
hashcat --version > "$OUTPUT_DIR/version.txt" 2>&1 || true
hashcat -I > "$OUTPUT_DIR/devices.txt" 2>&1 || true
clinfo > "$OUTPUT_DIR/clinfo.txt" 2>&1 || true

cp "$HASH_DIR/md5.txt" "$OUTPUT_DIR/md5.txt"
cp "$HASH_DIR/sha256.txt" "$OUTPUT_DIR/sha256.txt"

hashcat \
  --potfile-path "$OUTPUT_DIR/md5.potfile" \
  --outfile "$OUTPUT_DIR/md5-cracked.txt" \
  --outfile-format 2 \
  --quiet \
  -m 0 \
  -a 0 \
  "$OUTPUT_DIR/md5.txt" \
  "$WORDLIST" \
  > "$OUTPUT_DIR/md5-crack.log" 2>&1 || true

hashcat \
  --potfile-path "$OUTPUT_DIR/md5.potfile" \
  --show \
  --outfile-format 2 \
  -m 0 \
  "$OUTPUT_DIR/md5.txt" \
  > "$OUTPUT_DIR/md5-show.txt" 2>&1 || true

hashcat \
  --potfile-path "$OUTPUT_DIR/sha256.potfile" \
  --outfile "$OUTPUT_DIR/sha256-cracked.txt" \
  --outfile-format 2 \
  --quiet \
  -m 1400 \
  -a 0 \
  "$OUTPUT_DIR/sha256.txt" \
  "$WORDLIST" \
  > "$OUTPUT_DIR/sha256-crack.log" 2>&1 || true

hashcat \
  --potfile-path "$OUTPUT_DIR/sha256.potfile" \
  --show \
  --outfile-format 2 \
  -m 1400 \
  "$OUTPUT_DIR/sha256.txt" \
  > "$OUTPUT_DIR/sha256-show.txt" 2>&1 || true

{
  printf 'hash_set\tcracked\ttotal\n'
  printf 'md5\t%s\t%s\n' "$(grep -cv '^$' "$OUTPUT_DIR/md5-show.txt" 2>/dev/null || true)" "$(wc -l < "$OUTPUT_DIR/md5.txt" | tr -d ' ')"
  printf 'sha256\t%s\t%s\n' "$(grep -cv '^$' "$OUTPUT_DIR/sha256-show.txt" 2>/dev/null || true)" "$(wc -l < "$OUTPUT_DIR/sha256.txt" | tr -d ' ')"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Hashcat lab outputs."
