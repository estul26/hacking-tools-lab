#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
SOURCE="$FIXTURE_DIR/packetlab-r2-sample.c"
BINARY="$FIXTURE_DIR/packetlab-r2-sample"
STRIPPED="$FIXTURE_DIR/packetlab-r2-sample-stripped"
RAW="$FIXTURE_DIR/packetlab-r2-raw.bin"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

gcc -g -O0 -Wall -Wextra -o "$BINARY" "$SOURCE"
cp "$BINARY" "$STRIPPED"
strip "$STRIPPED"

r2 -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
r2 -v > "$OUTPUT_DIR/version.txt" 2>&1
file "$FIXTURE_DIR"/* > "$OUTPUT_DIR/file-types.txt"
sha256sum "$FIXTURE_DIR"/* > "$OUTPUT_DIR/sample-sha256.txt"

rabin2 -I "$BINARY" > "$OUTPUT_DIR/binary-info.txt"
rabin2 -S "$BINARY" > "$OUTPUT_DIR/sections.txt"
rabin2 -z "$BINARY" > "$OUTPUT_DIR/strings.txt"
rabin2 -s "$BINARY" > "$OUTPUT_DIR/symbols.txt"
rabin2 -i "$BINARY" > "$OUTPUT_DIR/imports.txt"

r2 -q -e scr.color=false -e scr.utf8=false -A \
  -c 'iI' \
  -c 'afl' \
  -c 'izz' \
  -c 'pdf @ sym.packetlab_local_status' \
  -c 'px 64 @ entry0' \
  -c 'q' \
  "$BINARY" > "$OUTPUT_DIR/r2-analysis.txt" 2>&1

r2 -q -e scr.color=false -e scr.utf8=false -A \
  -c 'pdf @ sym.packetlab_check_mode' \
  -c 'agf @ sym.packetlab_check_mode' \
  -c 'q' \
  "$BINARY" > "$OUTPUT_DIR/function-analysis.txt" 2>&1

r2 -q -e scr.color=false -e scr.utf8=false -A \
  -c 'afl' \
  -c 'izz' \
  -c 'q' \
  "$STRIPPED" > "$OUTPUT_DIR/stripped-analysis.txt" 2>&1

r2 -q -e scr.color=false -e scr.utf8=false \
  -c 'px 96' \
  -c '/ PACKETLAB_RAW_R2_MARKER' \
  -c 'q' \
  "$RAW" > "$OUTPUT_DIR/raw-blob-analysis.txt" 2>&1

./fixtures/packetlab-r2-sample local > "$OUTPUT_DIR/sample-run-local.txt" 2>&1 || true
./fixtures/packetlab-r2-sample remote > "$OUTPUT_DIR/sample-run-remote.txt" 2>&1 || true

{
  printf 'command\tpurpose\n'
  printf 'rabin2 -I packetlab-r2-sample\tShow binary metadata without entering the r2 shell.\n'
  printf 'rabin2 -S packetlab-r2-sample\tList sections and sizes.\n'
  printf 'rabin2 -z packetlab-r2-sample\tExtract strings from the sample.\n'
  printf 'rabin2 -s packetlab-r2-sample\tList symbols for named function review.\n'
  printf 'r2 -A -c "afl" packetlab-r2-sample\tAnalyze and list discovered functions.\n'
  printf 'r2 -A -c "pdf @ sym.packetlab_check_mode" packetlab-r2-sample\tDisassemble one known local function.\n'
  printf 'r2 -c "px 96" packetlab-r2-raw.bin\tPractice hex viewing against a raw generated blob.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

jq -n \
  --arg binary "$BINARY" \
  --arg stripped "$STRIPPED" \
  --arg raw "$RAW" \
  --arg sha256 "$(awk -v target="$BINARY" '$2 == target {print $1}' "$OUTPUT_DIR/sample-sha256.txt")" \
  --arg strings "$(wc -l < "$OUTPUT_DIR/strings.txt" | tr -d ' ')" \
  --arg symbols "$(grep -c 'packetlab_' "$OUTPUT_DIR/symbols.txt" || true)" \
  '{
    binary: $binary,
    stripped_binary: $stripped,
    raw_blob: $raw,
    binary_sha256: $sha256,
    extracted_string_lines: ($strings | tonumber),
    packetlab_symbol_count: ($symbols | tonumber)
  }' > "$OUTPUT_DIR/radare2-summary.json"

if grep -qi 'Usage:' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -qi 'radare2' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$BINARY" ] && [ -s "$STRIPPED" ] && [ -s "$RAW" ]; then
  fixtures_built="yes"
else
  fixtures_built="no"
fi

if grep -q 'PACKETLAB_R2_FIXTURE' "$OUTPUT_DIR/strings.txt"; then
  strings_extracted="yes"
else
  strings_extracted="no"
fi

if grep -q 'packetlab_check_mode' "$OUTPUT_DIR/symbols.txt"; then
  symbols_listed="yes"
else
  symbols_listed="no"
fi

if grep -q '.text' "$OUTPUT_DIR/sections.txt"; then
  sections_listed="yes"
else
  sections_listed="no"
fi

if grep -q 'packetlab_local_status' "$OUTPUT_DIR/r2-analysis.txt"; then
  function_listed="yes"
else
  function_listed="no"
fi

if grep -q 'packetlab_check_mode' "$OUTPUT_DIR/function-analysis.txt"; then
  function_disassembled="yes"
else
  function_disassembled="no"
fi

if grep -q 'PACKETLAB_RAW_R2_MARKER' "$OUTPUT_DIR/raw-blob-analysis.txt"; then
  raw_blob_searched="yes"
else
  raw_blob_searched="no"
fi

if grep -q 'check=42' "$OUTPUT_DIR/sample-run-local.txt" && grep -q 'check=-1' "$OUTPUT_DIR/sample-run-remote.txt"; then
  sample_behavior_recorded="yes"
else
  sample_behavior_recorded="no"
fi

if [ -s "$OUTPUT_DIR/radare2-summary.json" ] && [ -s "$OUTPUT_DIR/safe-command-plan.tsv" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixtures_built\t%s\n' "$fixtures_built"
  printf 'strings_extracted\t%s\n' "$strings_extracted"
  printf 'symbols_listed\t%s\n' "$symbols_listed"
  printf 'sections_listed\t%s\n' "$sections_listed"
  printf 'function_listed\t%s\n' "$function_listed"
  printf 'function_disassembled\t%s\n' "$function_disassembled"
  printf 'raw_blob_searched\t%s\n' "$raw_blob_searched"
  printf 'sample_behavior_recorded\t%s\n' "$sample_behavior_recorded"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'binary\t%s\n' "$BINARY"
  printf 'binary_size_bytes\t%s\n' "$(wc -c < "$BINARY" | tr -d ' ')"
  printf 'stripped_size_bytes\t%s\n' "$(wc -c < "$STRIPPED" | tr -d ' ')"
  printf 'radare2_version\t%s\n' "$(head -n 1 "$OUTPUT_DIR/version.txt")"
  printf 'packetlab_symbols\t%s\n' "$(grep -c 'packetlab_' "$OUTPUT_DIR/symbols.txt" || true)"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated radare2 lab outputs."
