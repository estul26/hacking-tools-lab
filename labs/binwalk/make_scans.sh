#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
FIXTURE_DIR="/work/fixtures"
FIRMWARE="$FIXTURE_DIR/packetlab-firmware.bin"
EXTRACT_DIR="$OUTPUT_DIR/extracted"

mkdir -p "$OUTPUT_DIR" "$FIXTURE_DIR"
rm -rf "$EXTRACT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json "$FIXTURE_DIR"/*

python3 /usr/local/bin/generate_fixture.py \
  "$FIXTURE_DIR" \
  "$OUTPUT_DIR/fixture-manifest.json" \
  "$OUTPUT_DIR/expected-files.tsv"

binwalk -h > "$OUTPUT_DIR/help.txt" 2>&1
awk '/^Binwalk v/ {print $2; exit}' "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/version.txt"
file "$FIRMWARE" > "$OUTPUT_DIR/file-type.txt"
sha256sum "$FIRMWARE" > "$OUTPUT_DIR/firmware-sha256.txt"

binwalk "$FIRMWARE" > "$OUTPUT_DIR/signature-scan.txt"
binwalk -y 'gzip|PNG|Zlib' "$FIRMWARE" > "$OUTPUT_DIR/include-filter.txt"
binwalk -E -N "$FIRMWARE" > "$OUTPUT_DIR/entropy.txt" 2>&1 || true

mkdir -p "$EXTRACT_DIR"
binwalk -e --run-as=root -C "$EXTRACT_DIR" "$FIRMWARE" > "$OUTPUT_DIR/extract.txt" 2>&1 || true
find "$EXTRACT_DIR" -maxdepth 4 -type f | sort > "$OUTPUT_DIR/extracted-files.txt"

CARVED_TAR="$(find "$EXTRACT_DIR" -type f \( -name 'rootfs.tar' -o -name '400' \) | head -n 1 || true)"
if [ -n "$CARVED_TAR" ] && tar -tf "$CARVED_TAR" > "$OUTPUT_DIR/tar-list.txt" 2>"$OUTPUT_DIR/tar-list-errors.txt"; then
  mkdir -p "$OUTPUT_DIR/rootfs"
  tar -xf "$CARVED_TAR" -C "$OUTPUT_DIR/rootfs"
  find "$OUTPUT_DIR/rootfs" -type f | sed "s#^$OUTPUT_DIR/rootfs/##" | sort > "$OUTPUT_DIR/rootfs-files.txt"
else
  : > "$OUTPUT_DIR/tar-list.txt"
  : > "$OUTPUT_DIR/rootfs-files.txt"
fi

if [ -f "$OUTPUT_DIR/rootfs/etc/device.conf" ]; then
  sed -n '1,40p' "$OUTPUT_DIR/rootfs/etc/device.conf" > "$OUTPUT_DIR/device-conf.txt"
else
  : > "$OUTPUT_DIR/device-conf.txt"
fi

{
  printf 'command\tpurpose\n'
  printf 'binwalk firmware.bin\tScan for embedded signatures and offsets.\n'
  printf 'binwalk -y "gzip|PNG" firmware.bin\tFilter scan output to expected local signatures.\n'
  printf 'binwalk -e --run-as=root -C outputs/extracted firmware.bin\tExtract local fixture contents inside the lab container.\n'
  printf 'tar -tf carved-rootfs\tList the decompressed rootfs tar carved by Binwalk.\n'
  printf 'sha256sum firmware.bin\tRecord a hash before analysis.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

if grep -q '^Binwalk v' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -Eq '^v?[0-9]+[.][0-9]+' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -s "$FIRMWARE" ] && grep -q '"firmware_sha256"' "$OUTPUT_DIR/fixture-manifest.json"; then
  fixture_generated="yes"
else
  fixture_generated="no"
fi

if grep -q 'gzip compressed data' "$OUTPUT_DIR/signature-scan.txt"; then
  gzip_found="yes"
else
  gzip_found="no"
fi

if grep -q 'PNG image' "$OUTPUT_DIR/signature-scan.txt"; then
  png_found="yes"
else
  png_found="no"
fi

if [ -n "$CARVED_TAR" ] && [ -s "$CARVED_TAR" ]; then
  carved_rootfs_found="yes"
else
  carved_rootfs_found="no"
fi

if grep -q 'etc/device.conf' "$OUTPUT_DIR/rootfs-files.txt" \
  && grep -q 'www/index.html' "$OUTPUT_DIR/rootfs-files.txt" \
  && grep -q 'bin/startup.sh' "$OUTPUT_DIR/rootfs-files.txt"; then
  rootfs_files_extracted="yes"
else
  rootfs_files_extracted="no"
fi

if grep -q 'secret=local-training-only' "$OUTPUT_DIR/device-conf.txt"; then
  config_reviewed="yes"
else
  config_reviewed="no"
fi

if [ -s "$OUTPUT_DIR/firmware-sha256.txt" ]; then
  hash_recorded="yes"
else
  hash_recorded="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'fixture_generated\t%s\n' "$fixture_generated"
  printf 'gzip_found\t%s\n' "$gzip_found"
  printf 'png_found\t%s\n' "$png_found"
  printf 'carved_rootfs_found\t%s\n' "$carved_rootfs_found"
  printf 'rootfs_files_extracted\t%s\n' "$rootfs_files_extracted"
  printf 'config_reviewed\t%s\n' "$config_reviewed"
  printf 'hash_recorded\t%s\n' "$hash_recorded"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$FIRMWARE"
  printf 'firmware_size_bytes\t%s\n' "$(wc -c < "$FIRMWARE" | tr -d ' ')"
  printf 'binwalk_version\t%s\n' "$(cat "$OUTPUT_DIR/version.txt")"
  printf 'signature_hits\t%s\n' "$(awk 'NR > 3 && NF {count++} END {print count + 0}' "$OUTPUT_DIR/signature-scan.txt")"
  printf 'rootfs_files\t%s\n' "$(wc -l < "$OUTPUT_DIR/rootfs-files.txt" | tr -d ' ')"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Binwalk lab outputs."
