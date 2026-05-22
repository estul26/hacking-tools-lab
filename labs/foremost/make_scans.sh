#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
IMAGE="$FIXTURE_DIR/packetlab-disk.img"
CARVE_DIR="$OUTPUT_DIR/carved"
AUDIT_ONLY_DIR="$OUTPUT_DIR/audit-only"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -rf "$CARVE_DIR" "$AUDIT_ONLY_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

foremost -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
awk '/^foremost version/ {print $3; exit}' "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/version.txt"
file "$IMAGE" > "$OUTPUT_DIR/image-file-type.txt"
sha256sum "$IMAGE" > "$OUTPUT_DIR/image-sha256.txt"

foremost -i "$IMAGE" -o "$CARVE_DIR" -t png,gif,zip > "$OUTPUT_DIR/foremost-carve.txt" 2>&1
foremost -w -i "$IMAGE" -o "$AUDIT_ONLY_DIR" -t png,gif,zip > "$OUTPUT_DIR/foremost-audit-only.txt" 2>&1
foremost -q -i "$IMAGE" -o "$OUTPUT_DIR/quick-carved" -t png,gif,zip > "$OUTPUT_DIR/foremost-quick.txt" 2>&1

find "$CARVE_DIR" -maxdepth 3 -type f | sort > "$OUTPUT_DIR/carved-files.txt"
find "$AUDIT_ONLY_DIR" -maxdepth 3 -type f | sort > "$OUTPUT_DIR/audit-only-files.txt"
file "$CARVE_DIR"/*/* > "$OUTPUT_DIR/carved-file-types.txt"
sha256sum "$CARVE_DIR"/*/* > "$OUTPUT_DIR/carved-sha256.txt"
unzip -l "$CARVE_DIR"/zip/*.zip > "$OUTPUT_DIR/zip-list.txt"

{
  printf 'type\tcount\n'
  printf 'png\t%s\n' "$(find "$CARVE_DIR/png" -type f -name '*.png' 2>/dev/null | wc -l | tr -d ' ')"
  printf 'gif\t%s\n' "$(find "$CARVE_DIR/gif" -type f -name '*.gif' 2>/dev/null | wc -l | tr -d ' ')"
  printf 'zip\t%s\n' "$(find "$CARVE_DIR/zip" -type f -name '*.zip' 2>/dev/null | wc -l | tr -d ' ')"
} > "$OUTPUT_DIR/carved-counts.tsv"

{
  printf 'command\tpurpose\n'
  printf 'foremost -i packetlab-disk.img -o outputs/carved -t png,gif,zip\tCarve selected local file types into a controlled output directory.\n'
  printf 'foremost -w -i packetlab-disk.img -o outputs/audit-only -t png,gif,zip\tWrite audit output without recovered files.\n'
  printf 'foremost -q -i packetlab-disk.img -o outputs/quick-carved -t png,gif,zip\tUse quick mode for 512-byte-aligned practice fixtures.\n'
  printf 'file outputs/carved/*/*\tVerify recovered file types before opening anything.\n'
  printf 'sha256sum packetlab-disk.img\tRecord the image hash before carving.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

jq -n \
  --arg image "$IMAGE" \
  --arg sha256 "$(awk '{print $1}' "$OUTPUT_DIR/image-sha256.txt")" \
  --arg carved_files "$(find "$CARVE_DIR" -type f ! -name 'audit.txt' | wc -l | tr -d ' ')" \
  '{
    image: $image,
    sha256: $sha256,
    carved_files: ($carved_files | tonumber)
  }' > "$OUTPUT_DIR/foremost-summary.json"

if grep -qi 'foremost version' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -Eq '^[0-9]+[.][0-9]+' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$IMAGE" ] && grep -q '"artifacts"' "$OUTPUT_DIR/fixture-manifest.json"; then
  fixture_generated="yes"
else
  fixture_generated="no"
fi

if grep -q 'PNG image data' "$OUTPUT_DIR/carved-file-types.txt"; then
  png_carved="yes"
else
  png_carved="no"
fi

if grep -q 'GIF image data' "$OUTPUT_DIR/carved-file-types.txt"; then
  gif_carved="yes"
else
  gif_carved="no"
fi

if grep -q 'Zip archive data' "$OUTPUT_DIR/carved-file-types.txt"; then
  zip_carved="yes"
else
  zip_carved="no"
fi

if grep -q 'case-note.txt' "$OUTPUT_DIR/zip-list.txt" && grep -q 'evidence/path.txt' "$OUTPUT_DIR/zip-list.txt"; then
  zip_contents_reviewed="yes"
else
  zip_contents_reviewed="no"
fi

if [ -s "$CARVE_DIR/audit.txt" ] && grep -q 'packetlab-disk.img' "$CARVE_DIR/audit.txt"; then
  audit_written="yes"
else
  audit_written="no"
fi

if [ -s "$AUDIT_ONLY_DIR/audit.txt" ] \
  && ! find "$AUDIT_ONLY_DIR" -type f ! -name 'audit.txt' | grep -q .; then
  audit_only_worked="yes"
else
  audit_only_worked="no"
fi

if [ -s "$OUTPUT_DIR/image-sha256.txt" ] && [ -s "$OUTPUT_DIR/foremost-summary.json" ]; then
  summary_written="yes"
else
  summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixture_generated\t%s\n' "$fixture_generated"
  printf 'png_carved\t%s\n' "$png_carved"
  printf 'gif_carved\t%s\n' "$gif_carved"
  printf 'zip_carved\t%s\n' "$zip_carved"
  printf 'zip_contents_reviewed\t%s\n' "$zip_contents_reviewed"
  printf 'audit_written\t%s\n' "$audit_written"
  printf 'audit_only_worked\t%s\n' "$audit_only_worked"
  printf 'summary_written\t%s\n' "$summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$IMAGE"
  printf 'fixture_size_bytes\t%s\n' "$(wc -c < "$IMAGE" | tr -d ' ')"
  printf 'foremost_version\t%s\n' "$(cat "$OUTPUT_DIR/version.txt")"
  printf 'carved_files\t%s\n' "$(find "$CARVE_DIR" -type f ! -name 'audit.txt' | wc -l | tr -d ' ')"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Foremost lab outputs."
