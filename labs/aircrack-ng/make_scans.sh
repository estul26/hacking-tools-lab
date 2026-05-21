#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BSSID="${BSSID:-02:11:22:33:44:55}"
WEP_KEY_HEX="${WEP_KEY_HEX:-4142434445}"
WEP_KEY_ASCII="${WEP_KEY_ASCII:-ABCDE}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BSSID" "$WEP_KEY_HEX" "$WEP_KEY_ASCII" <<'EOF'
set -eu

BSSID="$1"
WEP_KEY_HEX="$2"
WEP_KEY_ASCII="$3"
OUTPUT_DIR="/work/outputs"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv \
  "$OUTPUT_DIR"/*.ivs "$OUTPUT_DIR"/*.log

aircrack-ng --help > "$OUTPUT_DIR/aircrack-help.txt" 2>&1 || true
aircrack-ng --help 2>&1 | sed -n '1,3p' > "$OUTPUT_DIR/version.txt"
makeivs-ng --help > "$OUTPUT_DIR/makeivs-help.txt" 2>&1 || true
ivstools --help > "$OUTPUT_DIR/ivstools-help.txt" 2>&1 || true
airdecap-ng --help > "$OUTPUT_DIR/airdecap-help.txt" 2>&1 || true

makeivs-ng -b "$BSSID" -k "$WEP_KEY_HEX" -w "$OUTPUT_DIR/toy-left.ivs" \
  -c 100000 -s 7 > "$OUTPUT_DIR/makeivs-left.log" 2>&1
makeivs-ng -b "$BSSID" -k "$WEP_KEY_HEX" -w "$OUTPUT_DIR/toy-right.ivs" \
  -c 100000 -s 8 > "$OUTPUT_DIR/makeivs-right.log" 2>&1

ivstools --merge "$OUTPUT_DIR/toy-left.ivs" "$OUTPUT_DIR/toy-right.ivs" \
  "$OUTPUT_DIR/toy-merged.ivs" > "$OUTPUT_DIR/ivstools-merge.txt" 2>&1

aircrack-ng -a 1 -b "$BSSID" -n 64 -q \
  -l "$OUTPUT_DIR/cracked-key.txt" \
  "$OUTPUT_DIR/toy-merged.ivs" > "$OUTPUT_DIR/aircrack-wep.txt" 2>&1 || true

aircrack-ng -a 1 -b 02:aa:bb:cc:dd:ee -n 64 -q \
  "$OUTPUT_DIR/toy-merged.ivs" > "$OUTPUT_DIR/wrong-bssid.txt" 2>&1 || true

{
  printf 'file\tbytes\n'
  for file in "$OUTPUT_DIR"/toy-left.ivs "$OUTPUT_DIR"/toy-right.ivs "$OUTPUT_DIR"/toy-merged.ivs; do
    printf '%s\t%s\n' "$(basename "$file")" "$(wc -c < "$file")"
  done
} > "$OUTPUT_DIR/capture-sizes.tsv"

{
  printf 'check\tstatus\n'
  if grep -Eiq 'Aircrack-ng|usage:' "$OUTPUT_DIR/aircrack-help.txt"; then
    printf 'aircrack_help_available\tyes\n'
  else
    printf 'aircrack_help_available\tno\n'
  fi
  if grep -Eiq 'makeivs-ng|usage:' "$OUTPUT_DIR/makeivs-help.txt"; then
    printf 'makeivs_help_available\tyes\n'
  else
    printf 'makeivs_help_available\tno\n'
  fi
  if [ -s "$OUTPUT_DIR/toy-merged.ivs" ]; then
    printf 'ivs_fixture_created\tyes\n'
  else
    printf 'ivs_fixture_created\tno\n'
  fi
  if grep -Fq "KEY FOUND! [ 41:42:43:44:45 ]" "$OUTPUT_DIR/aircrack-wep.txt"; then
    printf 'wep_key_found\tyes\n'
  else
    printf 'wep_key_found\tno\n'
  fi
  if [ "$(tr -d '\r\n ' < "$OUTPUT_DIR/cracked-key.txt")" = "$WEP_KEY_HEX" ]; then
    printf 'key_file_written\tyes\n'
  else
    printf 'key_file_written\tno\n'
  fi
  if grep -Eiq 'No matching network found|No networks found|Quitting aircrack-ng' "$OUTPUT_DIR/wrong-bssid.txt"; then
    printf 'wrong_bssid_rejected\tyes\n'
  else
    printf 'wrong_bssid_rejected\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'bssid\t%s\n' "$BSSID"
  printf 'toy_wep_key_hex\t%s\n' "$WEP_KEY_HEX"
  printf 'toy_wep_key_ascii\t%s\n' "$WEP_KEY_ASCII"
  printf 'merged_ivs_bytes\t%s\n' "$(wc -c < "$OUTPUT_DIR/toy-merged.ivs")"
  printf 'cracked_key_file\t%s\n' "$(tr -d '\r\n ' < "$OUTPUT_DIR/cracked-key.txt" 2>/dev/null || true)"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Aircrack-ng lab outputs."
