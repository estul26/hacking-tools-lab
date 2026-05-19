#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
HASH_DIR="/work/hashes"
SAMPLES="$HASH_DIR/samples.txt"
EXPECTED="$HASH_DIR/expected.tsv"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

hashid --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
hashid --version > "$OUTPUT_DIR/version.txt" 2>&1 || true
cp "$SAMPLES" "$OUTPUT_DIR/samples.txt"
cp "$EXPECTED" "$OUTPUT_DIR/expected.tsv"

hashid -m -j "$SAMPLES" > "$OUTPUT_DIR/identified.txt" 2>"$OUTPUT_DIR/identified.log"
hashid --extended -m -j "$SAMPLES" > "$OUTPUT_DIR/identified-extended.txt" 2>"$OUTPUT_DIR/identified-extended.log"

while IFS="$(printf '\t')" read -r label hash expected hashcat_mode john_format; do
  [ "$label" = "label" ] && continue
  hashid -m -j "$hash" > "$OUTPUT_DIR/$label.txt" 2>"$OUTPUT_DIR/$label.log"
done < "$EXPECTED"

{
  printf 'label\texpected_candidate\tfound\thashcat_mode_found\tjohn_format_found\n'
  while IFS="$(printf '\t')" read -r label hash expected hashcat_mode john_format; do
    [ "$label" = "label" ] && continue
    result_file="$OUTPUT_DIR/$label.txt"
    if grep -Fq "[+] $expected" "$result_file"; then
      found="yes"
    else
      found="no"
    fi
    if grep -Fq "Hashcat Mode: $hashcat_mode" "$result_file"; then
      hashcat_found="yes"
    else
      hashcat_found="no"
    fi
    if grep -Fq "JtR Format: $john_format" "$result_file"; then
      john_found="yes"
    else
      john_found="no"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$label" "$expected" "$found" "$hashcat_found" "$john_found"
  done < "$EXPECTED"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'sample_hashes\t%s\n' "$(grep -cv '^$' "$SAMPLES")"
  printf 'expected_candidates_found\t%s\n' "$(awk -F'\t' 'NR > 1 && $3 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
  printf 'hashcat_modes_found\t%s\n' "$(awk -F'\t' 'NR > 1 && $4 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
  printf 'john_formats_found\t%s\n' "$(awk -F'\t' 'NR > 1 && $5 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated HashID lab outputs."
