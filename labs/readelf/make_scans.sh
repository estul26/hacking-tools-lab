#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
SOURCE="$FIXTURE_DIR/packetlab-readelf-sample.c"
OBJECT="$FIXTURE_DIR/packetlab-readelf-sample.o"
BINARY="$FIXTURE_DIR/packetlab-readelf-sample"
STRIPPED="$FIXTURE_DIR/packetlab-readelf-sample-stripped"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

gcc -g -O0 -Wall -Wextra -c -o "$OBJECT" "$SOURCE"
gcc -g -O0 -Wall -Wextra -o "$BINARY" "$OBJECT"
cp "$BINARY" "$STRIPPED"
strip "$STRIPPED"

readelf --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
readelf --version > "$OUTPUT_DIR/version.txt" 2>&1
file "$FIXTURE_DIR"/* > "$OUTPUT_DIR/file-types.txt"
sha256sum "$FIXTURE_DIR"/* > "$OUTPUT_DIR/sample-sha256.txt"

readelf -h "$BINARY" > "$OUTPUT_DIR/elf-header.txt"
readelf -l "$BINARY" > "$OUTPUT_DIR/program-headers.txt"
readelf -S "$BINARY" > "$OUTPUT_DIR/section-headers.txt"
readelf -s "$BINARY" > "$OUTPUT_DIR/symbols.txt"
readelf --dyn-syms "$BINARY" > "$OUTPUT_DIR/dynamic-symbols.txt"
readelf -r "$OBJECT" > "$OUTPUT_DIR/relocations-object.txt"
readelf -d "$BINARY" > "$OUTPUT_DIR/dynamic-section.txt"
readelf -n "$BINARY" > "$OUTPUT_DIR/notes.txt"
readelf -V "$BINARY" > "$OUTPUT_DIR/version-info.txt"
readelf -p .rodata "$BINARY" > "$OUTPUT_DIR/rodata-strings.txt"
readelf -x .rodata "$BINARY" > "$OUTPUT_DIR/rodata-hex.txt"
readelf --debug-dump=decodedline "$BINARY" > "$OUTPUT_DIR/debug-lines.txt"
readelf -S "$STRIPPED" > "$OUTPUT_DIR/stripped-section-headers.txt"
readelf -s "$STRIPPED" > "$OUTPUT_DIR/stripped-symbols.txt"

./fixtures/packetlab-readelf-sample local > "$OUTPUT_DIR/sample-run-local.txt" 2>&1 || true
./fixtures/packetlab-readelf-sample remote > "$OUTPUT_DIR/sample-run-remote.txt" 2>&1 || true

{
  printf 'command\tpurpose\n'
  printf 'readelf -h packetlab-readelf-sample\tShow the ELF header, class, machine, type, and entry point.\n'
  printf 'readelf -l packetlab-readelf-sample\tList program headers and segment-to-section mapping.\n'
  printf 'readelf -S packetlab-readelf-sample\tList section headers.\n'
  printf 'readelf -s packetlab-readelf-sample\tList symbols from the unstripped sample.\n'
  printf 'readelf --dyn-syms packetlab-readelf-sample\tList dynamic symbols.\n'
  printf 'readelf -r packetlab-readelf-sample.o\tShow relocations in the object file.\n'
  printf 'readelf -d packetlab-readelf-sample\tShow the dynamic section.\n'
  printf 'readelf -n packetlab-readelf-sample\tShow ELF notes such as build ID and ABI tag.\n'
  printf 'readelf -p .rodata packetlab-readelf-sample\tPrint strings from the read-only data section.\n'
  printf 'readelf -x .rodata packetlab-readelf-sample\tHex dump the read-only data section.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

jq -n \
  --arg binary "$BINARY" \
  --arg object "$OBJECT" \
  --arg stripped "$STRIPPED" \
  --arg sha256 "$(awk -v target="$BINARY" '$2 == target {print $1}' "$OUTPUT_DIR/sample-sha256.txt")" \
  --arg sections "$(awk '/^[[:space:]]*\\[[ 0-9]+\\]/ {count++} END {print count + 0}' "$OUTPUT_DIR/section-headers.txt")" \
  --arg packetlab_symbols "$(grep -c 'packetlab_' "$OUTPUT_DIR/symbols.txt" || true)" \
  '{
    binary: $binary,
    object_file: $object,
    stripped_binary: $stripped,
    binary_sha256: $sha256,
    section_count: ($sections | tonumber),
    packetlab_symbol_count: ($packetlab_symbols | tonumber)
  }' > "$OUTPUT_DIR/readelf-summary.json"

if grep -qi 'Usage:' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -qi 'GNU readelf' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$OBJECT" ] && [ -s "$BINARY" ] && [ -s "$STRIPPED" ]; then
  fixtures_built="yes"
else
  fixtures_built="no"
fi

if grep -q 'ELF Header:' "$OUTPUT_DIR/elf-header.txt" && grep -q 'Machine:' "$OUTPUT_DIR/elf-header.txt"; then
  elf_header_written="yes"
else
  elf_header_written="no"
fi

if grep -q 'Program Headers:' "$OUTPUT_DIR/program-headers.txt" && grep -q 'LOAD' "$OUTPUT_DIR/program-headers.txt"; then
  program_headers_listed="yes"
else
  program_headers_listed="no"
fi

if grep -q '.text' "$OUTPUT_DIR/section-headers.txt" && grep -q '.rodata' "$OUTPUT_DIR/section-headers.txt"; then
  sections_listed="yes"
else
  sections_listed="no"
fi

if grep -q 'packetlab_check_mode' "$OUTPUT_DIR/symbols.txt"; then
  symbols_listed="yes"
else
  symbols_listed="no"
fi

if grep -Eq 'printf|strcmp' "$OUTPUT_DIR/dynamic-symbols.txt"; then
  dynamic_symbols_listed="yes"
else
  dynamic_symbols_listed="no"
fi

if grep -q 'Relocation section' "$OUTPUT_DIR/relocations-object.txt"; then
  relocations_listed="yes"
else
  relocations_listed="no"
fi

if grep -q '(NEEDED)' "$OUTPUT_DIR/dynamic-section.txt"; then
  dynamic_section_listed="yes"
else
  dynamic_section_listed="no"
fi

if grep -Eq 'Build ID|ABI' "$OUTPUT_DIR/notes.txt"; then
  notes_listed="yes"
else
  notes_listed="no"
fi

if grep -Eq 'Version symbols|Version needs' "$OUTPUT_DIR/version-info.txt"; then
  version_info_listed="yes"
else
  version_info_listed="no"
fi

if grep -q 'PACKETLAB_READELF_FIXTURE' "$OUTPUT_DIR/rodata-strings.txt"; then
  rodata_strings_printed="yes"
else
  rodata_strings_printed="no"
fi

if grep -q 'PACKETLA' "$OUTPUT_DIR/rodata-hex.txt" && grep -q 'B_READELF' "$OUTPUT_DIR/rodata-hex.txt"; then
  rodata_hex_dumped="yes"
else
  rodata_hex_dumped="no"
fi

if grep -q 'packetlab-readelf-sample.c' "$OUTPUT_DIR/debug-lines.txt"; then
  debug_lines_listed="yes"
else
  debug_lines_listed="no"
fi

if ! grep -q 'packetlab_check_mode' "$OUTPUT_DIR/stripped-symbols.txt"; then
  stripped_comparison_worked="yes"
else
  stripped_comparison_worked="no"
fi

if grep -q 'check=11' "$OUTPUT_DIR/sample-run-local.txt" && grep -q 'check=-5' "$OUTPUT_DIR/sample-run-remote.txt"; then
  sample_behavior_recorded="yes"
else
  sample_behavior_recorded="no"
fi

if [ -s "$OUTPUT_DIR/readelf-summary.json" ] && [ -s "$OUTPUT_DIR/safe-command-plan.tsv" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixtures_built\t%s\n' "$fixtures_built"
  printf 'elf_header_written\t%s\n' "$elf_header_written"
  printf 'program_headers_listed\t%s\n' "$program_headers_listed"
  printf 'sections_listed\t%s\n' "$sections_listed"
  printf 'symbols_listed\t%s\n' "$symbols_listed"
  printf 'dynamic_symbols_listed\t%s\n' "$dynamic_symbols_listed"
  printf 'relocations_listed\t%s\n' "$relocations_listed"
  printf 'dynamic_section_listed\t%s\n' "$dynamic_section_listed"
  printf 'notes_listed\t%s\n' "$notes_listed"
  printf 'version_info_listed\t%s\n' "$version_info_listed"
  printf 'rodata_strings_printed\t%s\n' "$rodata_strings_printed"
  printf 'rodata_hex_dumped\t%s\n' "$rodata_hex_dumped"
  printf 'debug_lines_listed\t%s\n' "$debug_lines_listed"
  printf 'stripped_comparison_worked\t%s\n' "$stripped_comparison_worked"
  printf 'sample_behavior_recorded\t%s\n' "$sample_behavior_recorded"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'binary\t%s\n' "$BINARY"
  printf 'binary_size_bytes\t%s\n' "$(wc -c < "$BINARY" | tr -d ' ')"
  printf 'object_size_bytes\t%s\n' "$(wc -c < "$OBJECT" | tr -d ' ')"
  printf 'stripped_size_bytes\t%s\n' "$(wc -c < "$STRIPPED" | tr -d ' ')"
  printf 'readelf_version\t%s\n' "$(head -n 1 "$OUTPUT_DIR/version.txt")"
  printf 'packetlab_symbols\t%s\n' "$(grep -c 'packetlab_' "$OUTPUT_DIR/symbols.txt" || true)"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated readelf lab outputs."
