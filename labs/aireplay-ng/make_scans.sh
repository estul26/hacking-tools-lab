#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BSSID="${BSSID:-02:11:22:33:44:55}"
STATION="${STATION:-02:66:77:88:99:AA}"
INTERFACE="${INTERFACE:-wlan0mon}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BSSID" "$STATION" "$INTERFACE" <<'EOF'
set -eu

BSSID="$1"
STATION="$2"
INTERFACE="$3"
OUTPUT_DIR="/work/outputs"
PCAP="$OUTPUT_DIR/packetlab-replay-source.pcap"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv \
  "$OUTPUT_DIR"/*.pcap "$OUTPUT_DIR"/*.log

aireplay-ng --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
aireplay-ng --help 2>&1 | sed -n '1,3p' > "$OUTPUT_DIR/version.txt"
airmon-ng > "$OUTPUT_DIR/airmon-interfaces.txt" 2>&1 || true

python3 /usr/local/bin/generate_frames.py "$PCAP"

timeout 5s aireplay-ng --test "$INTERFACE" \
  > "$OUTPUT_DIR/injection-test-no-radio.txt" 2>&1 || true

timeout 5s aireplay-ng --fakeauth 0 \
  -a "$BSSID" \
  -h "$STATION" \
  "$INTERFACE" > "$OUTPUT_DIR/fakeauth-no-radio.txt" 2>&1 || true

timeout 5s aireplay-ng --interactive \
  -r "$PCAP" \
  "$INTERFACE" > "$OUTPUT_DIR/replay-source-no-radio.txt" 2>&1 || true

awk '
  /^      --/ {
    name=$1
    alias=$NF
    gsub(/[()]/, "", alias)
    desc=""
    for (i=2; i<NF; i++) {
      desc = desc (desc == "" ? "" : " ") $i
    }
    if (name ~ /^--(deauth|fakeauth|interactive|arpreplay|chopchop|fragment|caffe-latte|cfrag|migmode|test)$/) {
      print name "\t" alias "\t" desc
    }
  }
' "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/attack-modes.tsv"

{
  printf 'purpose\tcommand\n'
  printf 'injection-test\t%s\n' "aireplay-ng --test $INTERFACE"
  printf 'fake-auth-lab-only\t%s\n' "aireplay-ng --fakeauth 0 -a $BSSID -h $STATION $INTERFACE"
  printf 'replay-from-local-pcap-lab-only\t%s\n' "aireplay-ng --interactive -r outputs/packetlab-replay-source.pcap $INTERFACE"
} > "$OUTPUT_DIR/command-plan.tsv"

jq -Rn '
  [inputs
  | split("\t")
  | select(length == 2 and .[0] != "purpose")
  | {purpose: .[0], command: .[1]}]
' "$OUTPUT_DIR/command-plan.tsv" > "$OUTPUT_DIR/command-plan.json"

{
  printf 'check\tstatus\n'
  if grep -Eiq 'Aireplay-ng|usage:' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if [ -s "$PCAP" ]; then
    printf 'pcap_fixture_created\tyes\n'
  else
    printf 'pcap_fixture_created\tno\n'
  fi
  if grep -Fq -- '--deauth' "$OUTPUT_DIR/attack-modes.tsv" && grep -Fq -- '--test' "$OUTPUT_DIR/attack-modes.tsv"; then
    printf 'attack_modes_extracted\tyes\n'
  else
    printf 'attack_modes_extracted\tno\n'
  fi
  if grep -Eiq 'No such device|Failed initializing wireless card|nl80211 not found' "$OUTPUT_DIR/injection-test-no-radio.txt"; then
    printf 'test_mode_no_radio_recorded\tyes\n'
  else
    printf 'test_mode_no_radio_recorded\tno\n'
  fi
  if grep -Eiq 'No such device|Failed initializing wireless card|nl80211 not found' "$OUTPUT_DIR/fakeauth-no-radio.txt"; then
    printf 'fakeauth_no_radio_recorded\tyes\n'
  else
    printf 'fakeauth_no_radio_recorded\tno\n'
  fi
  if grep -Eiq 'No such device|Failed initializing wireless card|nl80211 not found' "$OUTPUT_DIR/replay-source-no-radio.txt"; then
    printf 'replay_source_no_radio_recorded\tyes\n'
  else
    printf 'replay_source_no_radio_recorded\tno\n'
  fi
  if jq -e 'length == 3' "$OUTPUT_DIR/command-plan.json" >/dev/null; then
    printf 'command_plan_written\tyes\n'
  else
    printf 'command_plan_written\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'fixture\t%s\n' "$(basename "$PCAP")"
  printf 'fixture_bytes\t%s\n' "$(wc -c < "$PCAP")"
  printf 'bssid\t%s\n' "$BSSID"
  printf 'station\t%s\n' "$STATION"
  printf 'interface\t%s\n' "$INTERFACE"
  printf 'attack_modes\t%s\n' "$(awk 'END {print NR + 0}' "$OUTPUT_DIR/attack-modes.tsv")"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Aireplay-ng lab outputs."
