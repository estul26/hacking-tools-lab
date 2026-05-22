#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
SAMPLE="$FIXTURE_DIR/packetlab-sample.bin"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

strings --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
strings --version > "$OUTPUT_DIR/version.txt" 2>&1
file "$SAMPLE" > "$OUTPUT_DIR/file-type.txt"
sha256sum "$SAMPLE" > "$OUTPUT_DIR/sample-sha256.txt"

strings -a "$SAMPLE" > "$OUTPUT_DIR/all-strings.txt"
strings -a -n 8 "$SAMPLE" > "$OUTPUT_DIR/min-length-8.txt"
strings -a -t x "$SAMPLE" > "$OUTPUT_DIR/offsets-hex.txt"
strings -a -t d "$SAMPLE" > "$OUTPUT_DIR/offsets-decimal.txt"
strings -a -e l "$SAMPLE" > "$OUTPUT_DIR/utf16le-strings.txt"

grep -E 'https?://|127[.]0[.]0[.]1|localhost' "$OUTPUT_DIR/all-strings.txt" \
  > "$OUTPUT_DIR/url-hits.txt"
grep -Ei 'token|secret|password|credential|auth' "$OUTPUT_DIR/all-strings.txt" \
  > "$OUTPUT_DIR/sensitive-keyword-hits.txt"
grep -E 'PACKETLAB|packetlab|LOCAL-TRAINING|demo-user' "$OUTPUT_DIR/all-strings.txt" \
  > "$OUTPUT_DIR/lab-marker-hits.txt"

jq -n \
  --arg fixture "$SAMPLE" \
  --arg sha256 "$(awk '{print $1}' "$OUTPUT_DIR/sample-sha256.txt")" \
  --arg ascii_count "$(wc -l < "$OUTPUT_DIR/all-strings.txt" | tr -d ' ')" \
  --arg min8_count "$(wc -l < "$OUTPUT_DIR/min-length-8.txt" | tr -d ' ')" \
  --arg url_hits "$(wc -l < "$OUTPUT_DIR/url-hits.txt" | tr -d ' ')" \
  --arg sensitive_hits "$(wc -l < "$OUTPUT_DIR/sensitive-keyword-hits.txt" | tr -d ' ')" \
  '{
    fixture: $fixture,
    sha256: $sha256,
    ascii_string_count: ($ascii_count | tonumber),
    min_length_8_count: ($min8_count | tonumber),
    url_hits: ($url_hits | tonumber),
    sensitive_keyword_hits: ($sensitive_hits | tonumber)
  }' > "$OUTPUT_DIR/strings-summary.json"

{
  printf 'command\tpurpose\n'
  printf 'strings -a packetlab-sample.bin\tExtract printable ASCII strings from the whole fixture.\n'
  printf 'strings -a -n 8 packetlab-sample.bin\tRaise minimum string length to reduce noise.\n'
  printf 'strings -a -t x packetlab-sample.bin\tShow hexadecimal offsets for triage notes.\n'
  printf 'strings -a -e l packetlab-sample.bin\tSearch UTF-16LE strings often seen in Windows artifacts.\n'
  printf 'grep -Ei "token|secret|auth" all-strings.txt\tReview keyword hits without treating them as proof.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

if grep -qi 'Usage: strings' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -q 'GNU strings' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$SAMPLE" ] && grep -q '"sha256"' "$OUTPUT_DIR/fixture-manifest.json"; then
  fixture_generated="yes"
else
  fixture_generated="no"
fi

if grep -q 'PACKETLAB_STRINGS_FIXTURE' "$OUTPUT_DIR/all-strings.txt"; then
  ascii_marker_found="yes"
else
  ascii_marker_found="no"
fi

if grep -q 'URL=http://127.0.0.1:8080/status' "$OUTPUT_DIR/url-hits.txt"; then
  url_found="yes"
else
  url_found="no"
fi

if grep -q 'API_TOKEN=LOCAL-TRAINING-ONLY-NOT-A-REAL-SECRET' "$OUTPUT_DIR/sensitive-keyword-hits.txt"; then
  sensitive_keyword_found="yes"
else
  sensitive_keyword_found="no"
fi

if grep -q 'UNICODE_PACKETLAB_MARKER' "$OUTPUT_DIR/utf16le-strings.txt"; then
  utf16le_marker_found="yes"
else
  utf16le_marker_found="no"
fi

if grep -Eq '^[[:space:]]*80[[:space:]]+PACKETLAB_STRINGS_FIXTURE' "$OUTPUT_DIR/offsets-hex.txt"; then
  offset_recorded="yes"
else
  offset_recorded="no"
fi

if grep -q '^tiny$' "$OUTPUT_DIR/all-strings.txt" && ! grep -q '^tiny$' "$OUTPUT_DIR/min-length-8.txt"; then
  min_length_filter_worked="yes"
else
  min_length_filter_worked="no"
fi

if [ -s "$OUTPUT_DIR/sample-sha256.txt" ] && [ -s "$OUTPUT_DIR/strings-summary.json" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixture_generated\t%s\n' "$fixture_generated"
  printf 'ascii_marker_found\t%s\n' "$ascii_marker_found"
  printf 'url_found\t%s\n' "$url_found"
  printf 'sensitive_keyword_found\t%s\n' "$sensitive_keyword_found"
  printf 'utf16le_marker_found\t%s\n' "$utf16le_marker_found"
  printf 'offset_recorded\t%s\n' "$offset_recorded"
  printf 'min_length_filter_worked\t%s\n' "$min_length_filter_worked"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$SAMPLE"
  printf 'fixture_size_bytes\t%s\n' "$(wc -c < "$SAMPLE" | tr -d ' ')"
  printf 'strings_version\t%s\n' "$(head -n 1 "$OUTPUT_DIR/version.txt")"
  printf 'ascii_strings\t%s\n' "$(wc -l < "$OUTPUT_DIR/all-strings.txt" | tr -d ' ')"
  printf 'utf16le_strings\t%s\n' "$(wc -l < "$OUTPUT_DIR/utf16le-strings.txt" | tr -d ' ')"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated strings lab outputs."
