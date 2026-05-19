#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

crunch > "$OUTPUT_DIR/help.txt" 2>&1 || true
dpkg-query -W -f='${Package}\t${Version}\n' crunch > "$OUTPUT_DIR/version.txt" 2>&1 || true

crunch 2 2 ab \
  -o "$OUTPUT_DIR/basic-ab.txt" \
  > "$OUTPUT_DIR/basic-ab.log" 2>&1

crunch 4 4 \
  -t lab% \
  -o "$OUTPUT_DIR/pattern-lab-digit.txt" \
  > "$OUTPUT_DIR/pattern-lab-digit.log" 2>&1

crunch 3 3 xyz \
  -o "$OUTPUT_DIR/custom-charset.txt" \
  > "$OUTPUT_DIR/custom-charset.log" 2>&1

crunch 3 3 abc \
  -s aba \
  -e abb \
  -o "$OUTPUT_DIR/start-end-range.txt" \
  > "$OUTPUT_DIR/start-end-range.log" 2>&1

crunch 1 1 \
  -p red blue green \
  > "$OUTPUT_DIR/permutations.txt" 2>"$OUTPUT_DIR/permutations.log"

{
  printf 'word\tpresent\n'
  for word in aa ab ba bb lab0 lab9 xxx zzz aba abb redbluegreen; do
    if grep -Fxq "$word" "$OUTPUT_DIR/basic-ab.txt" \
      || grep -Fxq "$word" "$OUTPUT_DIR/pattern-lab-digit.txt" \
      || grep -Fxq "$word" "$OUTPUT_DIR/custom-charset.txt" \
      || grep -Fxq "$word" "$OUTPUT_DIR/start-end-range.txt" \
      || grep -Fxq "$word" "$OUTPUT_DIR/permutations.txt"; then
      printf '%s\tyes\n' "$word"
    else
      printf '%s\tno\n' "$word"
    fi
  done
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'wordlist\tlines\n'
  printf 'basic-ab\t%s\n' "$(wc -l < "$OUTPUT_DIR/basic-ab.txt" | tr -d ' ')"
  printf 'pattern-lab-digit\t%s\n' "$(wc -l < "$OUTPUT_DIR/pattern-lab-digit.txt" | tr -d ' ')"
  printf 'custom-charset\t%s\n' "$(wc -l < "$OUTPUT_DIR/custom-charset.txt" | tr -d ' ')"
  printf 'start-end-range\t%s\n' "$(wc -l < "$OUTPUT_DIR/start-end-range.txt" | tr -d ' ')"
  printf 'permutations\t%s\n' "$(wc -l < "$OUTPUT_DIR/permutations.txt" | tr -d ' ')"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Crunch lab outputs."
