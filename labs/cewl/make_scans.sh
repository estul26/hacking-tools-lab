#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.58.80.20:8080}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
EXCLUDE_PATHS="/work/scope/exclude-paths.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
cewl --help > "$OUTPUT_DIR/help.txt" 2>&1 || true

cewl \
  --depth 2 \
  --min_word_length 5 \
  --with-numbers \
  --lowercase \
  --exclude "$EXCLUDE_PATHS" \
  --write "$OUTPUT_DIR/words.txt" \
  "$BASE_URL" \
  > "$OUTPUT_DIR/words.log" 2>&1

cewl \
  --depth 2 \
  --min_word_length 5 \
  --with-numbers \
  --lowercase \
  --count \
  --exclude "$EXCLUDE_PATHS" \
  --write "$OUTPUT_DIR/counts.txt" \
  "$BASE_URL" \
  > "$OUTPUT_DIR/counts.log" 2>&1

cewl \
  --depth 2 \
  --min_word_length 5 \
  --with-numbers \
  --lowercase \
  --email \
  --email_file "$OUTPUT_DIR/emails.txt" \
  --exclude "$EXCLUDE_PATHS" \
  --write "$OUTPUT_DIR/words-with-email-run.txt" \
  "$BASE_URL" \
  > "$OUTPUT_DIR/emails.log" 2>&1

cewl \
  --depth 1 \
  --min_word_length 5 \
  --with-numbers \
  --lowercase \
  --write "$OUTPUT_DIR/depth-one.txt" \
  "$BASE_URL" \
  > "$OUTPUT_DIR/depth-one.log" 2>&1

sort -u "$OUTPUT_DIR/words.txt" > "$OUTPUT_DIR/words.sorted.txt"
sort -u "$OUTPUT_DIR/emails.txt" > "$OUTPUT_DIR/emails.sorted.txt"

{
  printf 'word\tpresent\n'
  for word in packetbridge blueharbor sensorboard trailmap2026 beaconfield noiseword hiddenphrase; do
    if grep -Fxq "$word" "$OUTPUT_DIR/words.sorted.txt"; then
      printf '%s\tyes\n' "$word"
    else
      printf '%s\tno\n' "$word"
    fi
  done
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'words\t%s\n' "$(grep -cv '^$' "$OUTPUT_DIR/words.sorted.txt" 2>/dev/null || true)"
  printf 'counted_words\t%s\n' "$(grep -cv '^$' "$OUTPUT_DIR/counts.txt" 2>/dev/null || true)"
  printf 'emails\t%s\n' "$(grep -cv '^$' "$OUTPUT_DIR/emails.sorted.txt" 2>/dev/null || true)"
  printf 'depth_one_words\t%s\n' "$(grep -cv '^$' "$OUTPUT_DIR/depth-one.txt" 2>/dev/null || true)"
  printf 'expected_terms_found\t%s\n' "$(awk 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated CeWL lab outputs."
