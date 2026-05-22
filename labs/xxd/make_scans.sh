#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
SAMPLE="$FIXTURE_DIR/packetlab-sample.bin"
ROUNDTRIP="$OUTPUT_DIR/roundtrip.bin"
PATCHED="$OUTPUT_DIR/packetlab-sample-patched.bin"
PATCH_HEX="$OUTPUT_DIR/patch.hex"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.bin "$OUTPUT_DIR"/*.hex "$OUTPUT_DIR"/*.h "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

xxd -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
xxd -v > "$OUTPUT_DIR/version.txt" 2>&1
file "$SAMPLE" > "$OUTPUT_DIR/file-type.txt"
sha256sum "$SAMPLE" > "$OUTPUT_DIR/sample-sha256.txt"

xxd "$SAMPLE" > "$OUTPUT_DIR/hexdump-default.txt"
xxd -g 1 "$SAMPLE" > "$OUTPUT_DIR/hexdump-byte-groups.txt"
xxd -c 8 "$SAMPLE" > "$OUTPUT_DIR/hexdump-8-columns.txt"
xxd -l 128 "$SAMPLE" > "$OUTPUT_DIR/hexdump-first-128.txt"
xxd -s 0x40 -l 96 "$SAMPLE" > "$OUTPUT_DIR/hexdump-offset-0x40.txt"
xxd -p "$SAMPLE" > "$OUTPUT_DIR/plain-hex.txt"
xxd -i "$SAMPLE" > "$OUTPUT_DIR/include-array.h"

xxd -r "$OUTPUT_DIR/hexdump-default.txt" "$ROUNDTRIP"
sha256sum "$ROUNDTRIP" > "$OUTPUT_DIR/roundtrip-sha256.txt"
if cmp -s "$SAMPLE" "$ROUNDTRIP"; then
  printf 'roundtrip_match\tyes\n' > "$OUTPUT_DIR/roundtrip.tsv"
else
  printf 'roundtrip_match\tno\n' > "$OUTPUT_DIR/roundtrip.tsv"
fi

cp "$SAMPLE" "$PATCHED"
printf '00000020: 5041 5443 4845 4431\n' > "$PATCH_HEX"
xxd -r "$PATCH_HEX" "$PATCHED"
xxd -s 0x20 -l 16 "$PATCHED" > "$OUTPUT_DIR/patched-window.txt"
sha256sum "$PATCHED" > "$OUTPUT_DIR/patched-sha256.txt"

{
  printf 'command\tpurpose\n'
  printf 'xxd packetlab-sample.bin\tShow the default canonical hex dump.\n'
  printf 'xxd -g 1 packetlab-sample.bin\tGroup output by single bytes for byte-level review.\n'
  printf 'xxd -c 8 packetlab-sample.bin\tUse narrower rows for small terminal views.\n'
  printf 'xxd -s 0x40 -l 96 packetlab-sample.bin\tInspect a bounded offset window.\n'
  printf 'xxd -p packetlab-sample.bin\tWrite plain continuous hex.\n'
  printf 'xxd -i packetlab-sample.bin\tGenerate a C include-style byte array.\n'
  printf 'xxd -r hexdump-default.txt roundtrip.bin\tRebuild bytes from a hex dump.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

jq -n \
  --arg fixture "$SAMPLE" \
  --arg sha256 "$(awk '{print $1}' "$OUTPUT_DIR/sample-sha256.txt")" \
  --arg bytes "$(wc -c < "$SAMPLE" | tr -d ' ')" \
  --arg plain_hex_chars "$(tr -d '\n' < "$OUTPUT_DIR/plain-hex.txt" | wc -c | tr -d ' ')" \
  '{
    fixture: $fixture,
    sha256: $sha256,
    bytes: ($bytes | tonumber),
    plain_hex_chars: ($plain_hex_chars | tonumber)
  }' > "$OUTPUT_DIR/xxd-summary.json"

if grep -qi 'Usage:' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -qi '^xxd ' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$SAMPLE" ] && grep -q '"sha256"' "$OUTPUT_DIR/fixture-manifest.json"; then
  fixture_generated="yes"
else
  fixture_generated="no"
fi

if grep -q '00000000: 504b 544c 4142 2d58 5844' "$OUTPUT_DIR/hexdump-default.txt"; then
  default_hexdump_found="yes"
else
  default_hexdump_found="no"
fi

if grep -q '00000040: 50 61 63 6b 65 74 4c 61' "$OUTPUT_DIR/hexdump-byte-groups.txt"; then
  byte_grouping_found="yes"
else
  byte_grouping_found="no"
fi

if grep -q '5061 636b 6574 4c61 6220 7878 6420 6c6f' "$OUTPUT_DIR/hexdump-offset-0x40.txt" \
  && grep -q '6361 6c20 6669 7874 7572 65' "$OUTPUT_DIR/hexdump-offset-0x40.txt"; then
  offset_window_found="yes"
else
  offset_window_found="no"
fi

expected_hex_chars=$(( $(wc -c < "$SAMPLE" | tr -d ' ') * 2 ))
actual_hex_chars="$(tr -d '\n' < "$OUTPUT_DIR/plain-hex.txt" | wc -c | tr -d ' ')"
if [ "$actual_hex_chars" = "$expected_hex_chars" ]; then
  plain_hex_length_ok="yes"
else
  plain_hex_length_ok="no"
fi

if grep -q 'unsigned char' "$OUTPUT_DIR/include-array.h"; then
  include_array_written="yes"
else
  include_array_written="no"
fi

if grep -q 'roundtrip_match.*yes' "$OUTPUT_DIR/roundtrip.tsv"; then
  reverse_roundtrip_ok="yes"
else
  reverse_roundtrip_ok="no"
fi

if grep -q 'PATCHED1' "$OUTPUT_DIR/patched-window.txt" && ! cmp -s "$SAMPLE" "$PATCHED"; then
  patch_applied="yes"
else
  patch_applied="no"
fi

if [ -s "$OUTPUT_DIR/xxd-summary.json" ] && [ -s "$OUTPUT_DIR/patched-sha256.txt" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixture_generated\t%s\n' "$fixture_generated"
  printf 'default_hexdump_found\t%s\n' "$default_hexdump_found"
  printf 'byte_grouping_found\t%s\n' "$byte_grouping_found"
  printf 'offset_window_found\t%s\n' "$offset_window_found"
  printf 'plain_hex_length_ok\t%s\n' "$plain_hex_length_ok"
  printf 'include_array_written\t%s\n' "$include_array_written"
  printf 'reverse_roundtrip_ok\t%s\n' "$reverse_roundtrip_ok"
  printf 'patch_applied\t%s\n' "$patch_applied"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$SAMPLE"
  printf 'fixture_size_bytes\t%s\n' "$(wc -c < "$SAMPLE" | tr -d ' ')"
  printf 'xxd_version\t%s\n' "$(cat "$OUTPUT_DIR/version.txt")"
  printf 'plain_hex_chars\t%s\n' "$actual_hex_chars"
  printf 'roundtrip_match\t%s\n' "$(awk -F'\t' '$1 == "roundtrip_match" {print $2}' "$OUTPUT_DIR/roundtrip.tsv")"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated xxd lab outputs."
