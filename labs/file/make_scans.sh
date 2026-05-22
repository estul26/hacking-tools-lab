#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
CUSTOM_MAGIC="$OUTPUT_DIR/packetlab.magic"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.magic "$OUTPUT_DIR"/*.mgc "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

file --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
file --version > "$OUTPUT_DIR/version.txt" 2>&1
sha256sum "$FIXTURE_DIR"/* > "$OUTPUT_DIR/fixture-sha256.txt"

file "$FIXTURE_DIR"/* > "$OUTPUT_DIR/default-types.txt"
file -b "$FIXTURE_DIR"/* > "$OUTPUT_DIR/brief-types.txt"
file --mime-type "$FIXTURE_DIR"/* > "$OUTPUT_DIR/mime-types.txt"
file --mime-encoding "$FIXTURE_DIR"/* > "$OUTPUT_DIR/mime-encodings.txt"
file -z "$FIXTURE_DIR"/note.txt.gz > "$OUTPUT_DIR/compressed-types.txt"

{
  printf '0\tstring\tPKTLABMAGIC\tPacketLab custom firmware blob\n'
} > "$CUSTOM_MAGIC"
file -m "$CUSTOM_MAGIC" "$FIXTURE_DIR"/packetlab.bin > "$OUTPUT_DIR/custom-magic.txt"

{
  printf 'file\texpected\n'
  jq -r '.fixtures[] | [.name, .expected] | @tsv' "$OUTPUT_DIR/fixture-manifest.json"
} > "$OUTPUT_DIR/expected-types.tsv"

{
  printf 'command\tpurpose\n'
  printf 'file fixtures/*\tIdentify file types from content.\n'
  printf 'file -b fixtures/*\tPrint brief descriptions without file names.\n'
  printf 'file --mime-type fixtures/*\tPrint MIME type output for scripting.\n'
  printf 'file --mime-encoding fixtures/*\tPrint text/binary encoding hints.\n'
  printf 'file -z fixtures/note.txt.gz\tInspect compressed content when supported.\n'
  printf 'file -m outputs/packetlab.magic fixtures/packetlab.bin\tUse a local custom magic rule.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

jq -n \
  --arg fixture_dir "$FIXTURE_DIR" \
  --arg fixture_count "$(jq '.fixtures | length' "$OUTPUT_DIR/fixture-manifest.json")" \
  --arg sha256_count "$(wc -l < "$OUTPUT_DIR/fixture-sha256.txt" | tr -d ' ')" \
  '{
    fixture_dir: $fixture_dir,
    fixture_count: ($fixture_count | tonumber),
    sha256_count: ($sha256_count | tonumber)
  }' > "$OUTPUT_DIR/file-summary.json"

if grep -qi 'Usage: file' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -qi 'file-' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ "$(jq '.fixtures | length' "$OUTPUT_DIR/fixture-manifest.json")" -ge 8 ]; then
  fixtures_generated="yes"
else
  fixtures_generated="no"
fi

if grep -q 'note.txt:.*ASCII text' "$OUTPUT_DIR/default-types.txt"; then
  text_detected="yes"
else
  text_detected="no"
fi

if grep -q 'script.sh:.*shell script' "$OUTPUT_DIR/default-types.txt"; then
  script_detected="yes"
else
  script_detected="no"
fi

if grep -q 'renamed-as-jpg.jpg:.*PNG image data' "$OUTPUT_DIR/default-types.txt"; then
  mismatched_extension_detected="yes"
else
  mismatched_extension_detected="no"
fi

if grep -Eq 'config[.]json:[[:space:]]+application/json' "$OUTPUT_DIR/mime-types.txt"; then
  mime_json_detected="yes"
else
  mime_json_detected="no"
fi

if grep -q 'note.txt.gz:.*gzip compressed data' "$OUTPUT_DIR/default-types.txt" \
  && grep -q 'ASCII text' "$OUTPUT_DIR/compressed-types.txt"; then
  compressed_content_detected="yes"
else
  compressed_content_detected="no"
fi

if grep -q 'PacketLab custom firmware blob' "$OUTPUT_DIR/custom-magic.txt"; then
  custom_magic_detected="yes"
else
  custom_magic_detected="no"
fi

if [ -s "$OUTPUT_DIR/fixture-sha256.txt" ] && [ -s "$OUTPUT_DIR/file-summary.json" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixtures_generated\t%s\n' "$fixtures_generated"
  printf 'text_detected\t%s\n' "$text_detected"
  printf 'script_detected\t%s\n' "$script_detected"
  printf 'mismatched_extension_detected\t%s\n' "$mismatched_extension_detected"
  printf 'mime_json_detected\t%s\n' "$mime_json_detected"
  printf 'compressed_content_detected\t%s\n' "$compressed_content_detected"
  printf 'custom_magic_detected\t%s\n' "$custom_magic_detected"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture_dir\t%s\n' "$FIXTURE_DIR"
  printf 'fixture_count\t%s\n' "$(jq '.fixtures | length' "$OUTPUT_DIR/fixture-manifest.json")"
  printf 'file_version\t%s\n' "$(head -n 1 "$OUTPUT_DIR/version.txt")"
  printf 'mime_lines\t%s\n' "$(wc -l < "$OUTPUT_DIR/mime-types.txt" | tr -d ' ')"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated file lab outputs."
