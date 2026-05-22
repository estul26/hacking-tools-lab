#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s <<'EOF'
set -eu

OUTPUT_DIR="/work/outputs"
LAB_IFACE="lab0"
PEER_IFACE="labpeer"
SPECIFIC_MAC="02:42:ac:10:00:55"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.json

macchanger --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
macchanger --version > "$OUTPUT_DIR/version.txt" 2>&1 || true

ip -br link > "$OUTPUT_DIR/interfaces-before.txt"
ETH0_BEFORE="$(cat /sys/class/net/eth0/address 2>/dev/null || true)"

ip link del "$LAB_IFACE" 2>/dev/null || true
ip link add "$LAB_IFACE" type veth peer name "$PEER_IFACE"
ip link set "$LAB_IFACE" down
ip link set "$PEER_IFACE" down

ip -br link show "$LAB_IFACE" > "$OUTPUT_DIR/lab-interface-before.txt"
ORIGINAL_MAC="$(cat "/sys/class/net/$LAB_IFACE/address")"

macchanger -s "$LAB_IFACE" > "$OUTPUT_DIR/show-original.txt" 2>&1
macchanger -m "$SPECIFIC_MAC" "$LAB_IFACE" > "$OUTPUT_DIR/set-specific.txt" 2>&1
macchanger -s "$LAB_IFACE" > "$OUTPUT_DIR/show-specific.txt" 2>&1
AFTER_SPECIFIC_MAC="$(cat "/sys/class/net/$LAB_IFACE/address")"

macchanger -r "$LAB_IFACE" > "$OUTPUT_DIR/set-random.txt" 2>&1
macchanger -s "$LAB_IFACE" > "$OUTPUT_DIR/show-random.txt" 2>&1
AFTER_RANDOM_MAC="$(cat "/sys/class/net/$LAB_IFACE/address")"

ip link set "$LAB_IFACE" up
ip link set "$PEER_IFACE" up
ip -br link show "$LAB_IFACE" > "$OUTPUT_DIR/lab-interface-after.txt"

ETH0_AFTER="$(cat /sys/class/net/eth0/address 2>/dev/null || true)"

{
  printf 'interface\tstage\tmac\n'
  printf 'eth0\tbefore\t%s\n' "$ETH0_BEFORE"
  printf '%s\toriginal\t%s\n' "$LAB_IFACE" "$ORIGINAL_MAC"
  printf '%s\tspecific\t%s\n' "$LAB_IFACE" "$AFTER_SPECIFIC_MAC"
  printf '%s\trandom\t%s\n' "$LAB_IFACE" "$AFTER_RANDOM_MAC"
  printf 'eth0\tafter\t%s\n' "$ETH0_AFTER"
} > "$OUTPUT_DIR/observed-macs.tsv"

jq -n \
  --arg lab_iface "$LAB_IFACE" \
  --arg peer_iface "$PEER_IFACE" \
  --arg original "$ORIGINAL_MAC" \
  --arg specific "$AFTER_SPECIFIC_MAC" \
  --arg random "$AFTER_RANDOM_MAC" \
  --arg eth0_before "$ETH0_BEFORE" \
  --arg eth0_after "$ETH0_AFTER" \
  '{
    lab_interface: $lab_iface,
    peer_interface: $peer_iface,
    original_mac: $original,
    specific_mac: $specific,
    random_mac: $random,
    eth0_before: $eth0_before,
    eth0_after: $eth0_after
  }' > "$OUTPUT_DIR/observed-macs.json"

{
  printf 'command\tpurpose\n'
  printf 'macchanger -s lab0\tShow current and permanent MAC address for the lab-only interface.\n'
  printf 'macchanger -m 02:42:ac:10:00:55 lab0\tSet a predictable locally administered MAC for repeatable practice.\n'
  printf 'macchanger -r lab0\tRandomize only the disposable lab interface MAC.\n'
  printf 'ip link del lab0\tRemove the temporary veth pair after practice.\n'
} > "$OUTPUT_DIR/safe-command-plan.tsv"

if grep -Eq 'GNU MAC Changer|macchanger' "$OUTPUT_DIR/help.txt"; then
  help_available="yes"
else
  help_available="no"
fi

if grep -Eiq 'GNU MAC changer|version|macchanger' "$OUTPUT_DIR/version.txt"; then
  version_available="yes"
else
  version_available="no"
fi

if [ -n "$ORIGINAL_MAC" ] && printf '%s\n' "$ORIGINAL_MAC" | grep -Eq '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'; then
  lab_interface_created="yes"
else
  lab_interface_created="no"
fi

if [ "$AFTER_SPECIFIC_MAC" = "$SPECIFIC_MAC" ]; then
  specific_mac_applied="yes"
else
  specific_mac_applied="no"
fi

if [ "$AFTER_RANDOM_MAC" != "$AFTER_SPECIFIC_MAC" ] && printf '%s\n' "$AFTER_RANDOM_MAC" | grep -Eq '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'; then
  random_mac_changed="yes"
else
  random_mac_changed="no"
fi

if [ "$ETH0_BEFORE" = "$ETH0_AFTER" ] && [ -n "$ETH0_BEFORE" ]; then
  eth0_unchanged="yes"
else
  eth0_unchanged="no"
fi

ip link del "$LAB_IFACE"
ip -br link > "$OUTPUT_DIR/interfaces-after-cleanup.txt"

if ip link show "$LAB_IFACE" >/dev/null 2>&1; then
  lab_interface_cleaned="no"
else
  lab_interface_cleaned="yes"
fi

if [ -s "$OUTPUT_DIR/observed-macs.json" ]; then
  json_summary_written="yes"
else
  json_summary_written="no"
fi

{
  printf 'check\tstatus\n'
  printf 'help_available\t%s\n' "$help_available"
  printf 'version_available\t%s\n' "$version_available"
  printf 'lab_interface_created\t%s\n' "$lab_interface_created"
  printf 'specific_mac_applied\t%s\n' "$specific_mac_applied"
  printf 'random_mac_changed\t%s\n' "$random_mac_changed"
  printf 'eth0_unchanged\t%s\n' "$eth0_unchanged"
  printf 'lab_interface_cleaned\t%s\n' "$lab_interface_cleaned"
  printf 'json_summary_written\t%s\n' "$json_summary_written"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'lab_interface\t%s\n' "$LAB_IFACE"
  printf 'specific_mac\t%s\n' "$AFTER_SPECIFIC_MAC"
  printf 'random_mac\t%s\n' "$AFTER_RANDOM_MAC"
  printf 'eth0_unchanged\t%s\n' "$eth0_unchanged"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Macchanger lab outputs."
