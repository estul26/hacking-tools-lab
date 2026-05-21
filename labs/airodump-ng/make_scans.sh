#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BSSID="${BSSID:-02:11:22:33:44:55}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BSSID" <<'EOF'
set -eu

BSSID="$1"
OUTPUT_DIR="/work/outputs"
PCAP="$OUTPUT_DIR/packetlab-beacons.pcap"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv \
  "$OUTPUT_DIR"/*.pcap "$OUTPUT_DIR"/*.log "$OUTPUT_DIR"/airodump-* \
  "$OUTPUT_DIR"/filtered-* "$OUTPUT_DIR"/*.raw

airodump-ng --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
airodump-ng --help 2>&1 | sed -n '1,3p' > "$OUTPUT_DIR/version.txt"
airmon-ng > "$OUTPUT_DIR/airmon-interfaces.txt" 2>&1 || true

python3 /usr/local/bin/generate_capture.py "$PCAP"

timeout 2s airodump-ng -r "$PCAP" \
  --write "$OUTPUT_DIR/airodump" \
  --output-format csv,netxml \
  > "$OUTPUT_DIR/replay-screen.raw" 2>&1 || true
grep -aE 'BSSID|PacketLab|Finished reading' "$OUTPUT_DIR/replay-screen.raw" \
  | tail -20 > "$OUTPUT_DIR/replay-screen.txt" || true
rm -f "$OUTPUT_DIR/replay-screen.raw"

timeout 2s airodump-ng -r "$PCAP" \
  --bssid "$BSSID" \
  --write "$OUTPUT_DIR/filtered" \
  --output-format csv \
  > "$OUTPUT_DIR/filter-screen.raw" 2>&1 || true
grep -aE 'BSSID|PacketLab|Finished reading' "$OUTPUT_DIR/filter-screen.raw" \
  | tail -20 > "$OUTPUT_DIR/filter-screen.txt" || true
rm -f "$OUTPUT_DIR/filter-screen.raw"

timeout 3s airodump-ng \
  --write "$OUTPUT_DIR/no-radio" \
  --output-format csv \
  wlan0mon > "$OUTPUT_DIR/no-monitor-interface.txt" 2>&1 || true

awk -F',' '
function trim(value) {
  gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", value)
  return value
}
BEGIN {
  print "bssid\tchannel\tprivacy\tcipher\tbeacons\tessid"
}
NF >= 14 && $1 !~ /^BSSID/ && $1 !~ /^Station/ && trim($1) != "" {
  print trim($1) "\t" trim($4) "\t" trim($6) "\t" trim($7) "\t" trim($10) "\t" trim($14)
}
' "$OUTPUT_DIR/airodump-01.csv" > "$OUTPUT_DIR/access-points.tsv"

jq -Rn '
  [inputs
  | split("\t")
  | select(length == 6 and .[0] != "bssid")
  | {
      bssid: .[0],
      channel: .[1],
      privacy: .[2],
      cipher: .[3],
      beacons: (.[4] | tonumber),
      essid: .[5]
    }]
' "$OUTPUT_DIR/access-points.tsv" > "$OUTPUT_DIR/access-points.json"

{
  printf 'check\tstatus\n'
  if grep -Eiq 'Airodump-ng|usage:' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if [ -s "$PCAP" ]; then
    printf 'pcap_fixture_created\tyes\n'
  else
    printf 'pcap_fixture_created\tno\n'
  fi
  if grep -Fq 'PacketLab-WEP' "$OUTPUT_DIR/airodump-01.csv" && grep -Fq 'PacketLab-WPA2' "$OUTPUT_DIR/airodump-01.csv"; then
    printf 'csv_networks_seen\tyes\n'
  else
    printf 'csv_networks_seen\tno\n'
  fi
  if grep -Fq '<wireless-network' "$OUTPUT_DIR/airodump-01.kismet.netxml"; then
    printf 'netxml_written\tyes\n'
  else
    printf 'netxml_written\tno\n'
  fi
  if grep -Fq "$BSSID" "$OUTPUT_DIR/filtered-01.csv" && ! grep -Fq '02:AA:BB:CC:DD:EE' "$OUTPUT_DIR/filtered-01.csv"; then
    printf 'bssid_filter_worked\tyes\n'
  else
    printf 'bssid_filter_worked\tno\n'
  fi
  if grep -Eiq 'Failed initializing wireless card|No such device|nl80211 not found' "$OUTPUT_DIR/no-monitor-interface.txt"; then
    printf 'no_radio_failure_recorded\tyes\n'
  else
    printf 'no_radio_failure_recorded\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$(basename "$PCAP")"
  printf 'fixture_bytes\t%s\n' "$(wc -c < "$PCAP")"
  printf 'access_points\t%s\n' "$(awk 'NR > 1 {count++} END {print count + 0}' "$OUTPUT_DIR/access-points.tsv")"
  printf 'filtered_bssid\t%s\n' "$BSSID"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Airodump-ng lab outputs."
