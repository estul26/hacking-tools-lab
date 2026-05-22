#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
PHOTO="$FIXTURE_DIR/lab-photo.png"
SANITIZED="$OUTPUT_DIR/lab-photo-sanitized.png"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.csv "$OUTPUT_DIR"/*.png "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py "$FIXTURE_DIR" "$OUTPUT_DIR/fixture-manifest.json"

exiftool -overwrite_original \
  -Artist="PacketLab Analyst" \
  -Copyright="PacketLab Local Training" \
  -ImageDescription="Local ExifTool metadata fixture" \
  -Software="ExifTool Lab Generator" \
  -DateTimeOriginal="2026:01:01 12:00:00" \
  -GPSLatitude="51.0447" \
  -GPSLatitudeRef="N" \
  -GPSLongitude="114.0719" \
  -GPSLongitudeRef="W" \
  -GPSAltitude="1045 m" \
  "$PHOTO" > "$OUTPUT_DIR/write-metadata.txt" 2>&1

exiftool -ver > "$OUTPUT_DIR/version.txt" 2>&1
exiftool -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
file "$PHOTO" > "$OUTPUT_DIR/file-type.txt"
sha256sum "$PHOTO" > "$OUTPUT_DIR/photo-sha256.txt"

exiftool "$PHOTO" > "$OUTPUT_DIR/all-tags.txt"
exiftool -G1 -a -s "$PHOTO" > "$OUTPUT_DIR/grouped-tags.txt"
exiftool -j "$PHOTO" > "$OUTPUT_DIR/metadata.json"
exiftool -csv -Artist -ImageDescription -DateTimeOriginal -GPSLatitude -GPSLongitude -GPSAltitude "$PHOTO" \
  > "$OUTPUT_DIR/selected-tags.csv"

jq -r '.[0] | [
  .SourceFile,
  .Artist,
  .ImageDescription,
  .DateTimeOriginal,
  .GPSLatitude,
  .GPSLongitude,
  .GPSAltitude
] | @tsv' "$OUTPUT_DIR/metadata.json" > "$OUTPUT_DIR/selected-tags.tsv"
sed -i '1iSourceFile\tArtist\tImageDescription\tDateTimeOriginal\tGPSLatitude\tGPSLongitude\tGPSAltitude' \
  "$OUTPUT_DIR/selected-tags.tsv"

cp "$PHOTO" "$SANITIZED"
exiftool -all= -overwrite_original "$SANITIZED" > "$OUTPUT_DIR/strip-metadata.txt" 2>&1
exiftool "$SANITIZED" > "$OUTPUT_DIR/sanitized-tags.txt"
exiftool -j "$SANITIZED" > "$OUTPUT_DIR/sanitized-metadata.json"
sha256sum "$SANITIZED" > "$OUTPUT_DIR/sanitized-sha256.txt"

{
  printf 'command\tpurpose\n'
  printf 'exiftool file.png\tShow common metadata tags.\n'
  printf 'exiftool -G1 -a -s file.png\tShow grouped tag names, duplicates, and short names.\n'
  printf 'exiftool -j file.png\tWrite machine-readable JSON output.\n'
  printf 'exiftool -all= -overwrite_original copy.png\tStrip metadata from a copy.\n'
  printf 'sha256sum file.png\tRecord evidence hashes before and after metadata changes.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

if grep -Eq '^[0-9]+([.][0-9]+)+' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if grep -qi 'ExifTool' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -q 'PacketLab Analyst' "$OUTPUT_DIR/all-tags.txt"; then
  artist_found="yes"
else
  artist_found="no"
fi

if grep -q 'GPS Latitude' "$OUTPUT_DIR/all-tags.txt" && grep -q 'GPS Longitude' "$OUTPUT_DIR/all-tags.txt"; then
  gps_found="yes"
else
  gps_found="no"
fi

if jq -e '.[0].Artist == "PacketLab Analyst"' "$OUTPUT_DIR/metadata.json" >/dev/null; then
  json_metadata_written="yes"
else
  json_metadata_written="no"
fi

if [ -s "$SANITIZED" ] && [ -s "$OUTPUT_DIR/sanitized-tags.txt" ]; then
  sanitized_written="yes"
else
  sanitized_written="no"
fi

if grep -q 'PacketLab Analyst' "$OUTPUT_DIR/sanitized-tags.txt"; then
  sanitized_artist_removed="no"
else
  sanitized_artist_removed="yes"
fi

if grep -q 'GPS Latitude\|GPS Longitude' "$OUTPUT_DIR/sanitized-tags.txt"; then
  sanitized_gps_removed="no"
else
  sanitized_gps_removed="yes"
fi

if [ -s "$OUTPUT_DIR/photo-sha256.txt" ] && [ -s "$OUTPUT_DIR/sanitized-sha256.txt" ]; then
  hashes_recorded="yes"
else
  hashes_recorded="no"
fi

{
  printf 'check\tstatus\n'
  printf 'version_available\t%s\n' "$version_available"
  printf 'help_available\t%s\n' "$help_available"
  printf 'artist_found\t%s\n' "$artist_found"
  printf 'gps_found\t%s\n' "$gps_found"
  printf 'json_metadata_written\t%s\n' "$json_metadata_written"
  printf 'sanitized_written\t%s\n' "$sanitized_written"
  printf 'sanitized_artist_removed\t%s\n' "$sanitized_artist_removed"
  printf 'sanitized_gps_removed\t%s\n' "$sanitized_gps_removed"
  printf 'hashes_recorded\t%s\n' "$hashes_recorded"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$PHOTO"
  printf 'sanitized_copy\t%s\n' "$SANITIZED"
  printf 'exiftool_version\t%s\n' "$(cat "$OUTPUT_DIR/version.txt")"
  printf 'selected_metadata_fields\t%s\n' "$(awk -F',' 'NR == 1 {print NF}' "$OUTPUT_DIR/selected-tags.csv")"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated ExifTool lab outputs."
