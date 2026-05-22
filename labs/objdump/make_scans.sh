#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
SOURCE="$FIXTURE_DIR/packetlab-objdump-sample.c"
OBJECT="$FIXTURE_DIR/packetlab-objdump-sample.o"
BINARY="$FIXTURE_DIR/packetlab-objdump-sample"
STRIPPED="$FIXTURE_DIR/packetlab-objdump-sample-stripped"
RAW="$FIXTURE_DIR/packetlab-objdump-data.bin"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

gcc -g -O0 -Wall -Wextra -c -o "$OBJECT" "$SOURCE"
gcc -g -O0 -Wall -Wextra -o "$BINARY" "$OBJECT"
cp "$BINARY" "$STRIPPED"
strip "$STRIPPED"

objdump --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
objdump --version > "$OUTPUT_DIR/version.txt" 2>&1
file "$FIXTURE_DIR"/* > "$OUTPUT_DIR/file-types.txt"
sha256sum "$FIXTURE_DIR"/* > "$OUTPUT_DIR/sample-sha256.txt"

objdump -f "$BINARY" > "$OUTPUT_DIR/file-header.txt"
objdump -p "$BINARY" > "$OUTPUT_DIR/private-headers.txt"
objdump -h "$BINARY" > "$OUTPUT_DIR/section-headers.txt"
objdump -t "$BINARY" > "$OUTPUT_DIR/symbol-table.txt"
objdump -T "$BINARY" > "$OUTPUT_DIR/dynamic-symbols.txt"
objdump -r "$OBJECT" > "$OUTPUT_DIR/relocations-object.txt"
objdump -d "$BINARY" > "$OUTPUT_DIR/disassembly.txt"
objdump -S "$BINARY" > "$OUTPUT_DIR/source-disassembly.txt"
objdump -s -j .rodata "$BINARY" > "$OUTPUT_DIR/rodata-dump.txt"
objdump -h "$STRIPPED" > "$OUTPUT_DIR/stripped-section-headers.txt"
objdump -t "$STRIPPED" > "$OUTPUT_DIR/stripped-symbol-table.txt"
objdump -s -b binary -m aarch64 "$RAW" > "$OUTPUT_DIR/raw-data-dump.txt"

./fixtures/packetlab-objdump-sample local > "$OUTPUT_DIR/sample-run-local.txt" 2>&1 || true
./fixtures/packetlab-objdump-sample remote > "$OUTPUT_DIR/sample-run-remote.txt" 2>&1 || true

{
  printf 'command\tpurpose\n'
  printf 'objdump -f packetlab-objdump-sample\tShow the file format and architecture flags.\n'
  printf 'objdump -h packetlab-objdump-sample\tList section headers and sizes.\n'
  printf 'objdump -t packetlab-objdump-sample\tList symbols from the unstripped sample.\n'
  printf 'objdump -T packetlab-objdump-sample\tList dynamic symbols and imports.\n'
  printf 'objdump -r packetlab-objdump-sample.o\tShow relocations in the object file.\n'
  printf 'objdump -d packetlab-objdump-sample\tDisassemble executable sections.\n'
  printf 'objdump -S packetlab-objdump-sample\tMix source and disassembly when debug info exists.\n'
  printf 'objdump -s -j .rodata packetlab-objdump-sample\tDump read-only data for string context.\n'
  printf 'objdump -s -b binary -m aarch64 packetlab-objdump-data.bin\tDump a raw local blob by declaring its format.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

jq -n \
  --arg binary "$BINARY" \
  --arg object "$OBJECT" \
  --arg stripped "$STRIPPED" \
  --arg raw "$RAW" \
  --arg sha256 "$(awk -v target="$BINARY" '$2 == target {print $1}' "$OUTPUT_DIR/sample-sha256.txt")" \
  --arg sections "$(awk 'NR > 5 && $1 ~ /^[0-9]+$/ {count++} END {print count + 0}' "$OUTPUT_DIR/section-headers.txt")" \
  --arg packetlab_symbols "$(grep -c 'packetlab_' "$OUTPUT_DIR/symbol-table.txt" || true)" \
  '{
    binary: $binary,
    object_file: $object,
    stripped_binary: $stripped,
    raw_blob: $raw,
    binary_sha256: $sha256,
    section_count: ($sections | tonumber),
    packetlab_symbol_count: ($packetlab_symbols | tonumber)
  }' > "$OUTPUT_DIR/objdump-summary.json"

if grep -qi 'Usage:' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -qi 'GNU objdump' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$OBJECT" ] && [ -s "$BINARY" ] && [ -s "$STRIPPED" ] && [ -s "$RAW" ]; then
  fixtures_built="yes"
else
  fixtures_built="no"
fi

if grep -qi 'file format' "$OUTPUT_DIR/file-header.txt"; then
  file_header_written="yes"
else
  file_header_written="no"
fi

if grep -q '.text' "$OUTPUT_DIR/section-headers.txt" && grep -q '.rodata' "$OUTPUT_DIR/section-headers.txt"; then
  sections_listed="yes"
else
  sections_listed="no"
fi

if grep -q 'packetlab_check_mode' "$OUTPUT_DIR/symbol-table.txt"; then
  symbols_listed="yes"
else
  symbols_listed="no"
fi

if grep -Eq 'printf|puts|strcmp' "$OUTPUT_DIR/dynamic-symbols.txt"; then
  dynamic_symbols_listed="yes"
else
  dynamic_symbols_listed="no"
fi

if grep -q 'RELOCATION RECORDS' "$OUTPUT_DIR/relocations-object.txt"; then
  relocations_listed="yes"
else
  relocations_listed="no"
fi

if grep -q '<packetlab_check_mode>' "$OUTPUT_DIR/disassembly.txt"; then
  disassembly_written="yes"
else
  disassembly_written="no"
fi

if grep -q 'packetlab_print_status' "$OUTPUT_DIR/source-disassembly.txt"; then
  source_disassembly_written="yes"
else
  source_disassembly_written="no"
fi

if grep -q 'PACKETLA' "$OUTPUT_DIR/rodata-dump.txt" && grep -q 'B_OBJDUMP' "$OUTPUT_DIR/rodata-dump.txt"; then
  rodata_dumped="yes"
else
  rodata_dumped="no"
fi

if ! grep -q 'packetlab_check_mode' "$OUTPUT_DIR/stripped-symbol-table.txt"; then
  stripped_comparison_worked="yes"
else
  stripped_comparison_worked="no"
fi

if grep -q 'PACKETLAB_OBJDUM' "$OUTPUT_DIR/raw-data-dump.txt" && grep -q 'P_RAW_MARKER' "$OUTPUT_DIR/raw-data-dump.txt"; then
  raw_blob_dumped="yes"
else
  raw_blob_dumped="no"
fi

if grep -q 'check=7' "$OUTPUT_DIR/sample-run-local.txt" && grep -q 'check=-3' "$OUTPUT_DIR/sample-run-remote.txt"; then
  sample_behavior_recorded="yes"
else
  sample_behavior_recorded="no"
fi

if [ -s "$OUTPUT_DIR/objdump-summary.json" ] && [ -s "$OUTPUT_DIR/safe-command-plan.tsv" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixtures_built\t%s\n' "$fixtures_built"
  printf 'file_header_written\t%s\n' "$file_header_written"
  printf 'sections_listed\t%s\n' "$sections_listed"
  printf 'symbols_listed\t%s\n' "$symbols_listed"
  printf 'dynamic_symbols_listed\t%s\n' "$dynamic_symbols_listed"
  printf 'relocations_listed\t%s\n' "$relocations_listed"
  printf 'disassembly_written\t%s\n' "$disassembly_written"
  printf 'source_disassembly_written\t%s\n' "$source_disassembly_written"
  printf 'rodata_dumped\t%s\n' "$rodata_dumped"
  printf 'stripped_comparison_worked\t%s\n' "$stripped_comparison_worked"
  printf 'raw_blob_dumped\t%s\n' "$raw_blob_dumped"
  printf 'sample_behavior_recorded\t%s\n' "$sample_behavior_recorded"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'binary\t%s\n' "$BINARY"
  printf 'binary_size_bytes\t%s\n' "$(wc -c < "$BINARY" | tr -d ' ')"
  printf 'object_size_bytes\t%s\n' "$(wc -c < "$OBJECT" | tr -d ' ')"
  printf 'stripped_size_bytes\t%s\n' "$(wc -c < "$STRIPPED" | tr -d ' ')"
  printf 'objdump_version\t%s\n' "$(head -n 1 "$OUTPUT_DIR/version.txt")"
  printf 'packetlab_symbols\t%s\n' "$(grep -c 'packetlab_' "$OUTPUT_DIR/symbol-table.txt" || true)"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated objdump lab outputs."
