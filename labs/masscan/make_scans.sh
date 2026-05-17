#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_IP="${TARGET_IP:-172.40.100.20}"
TARGET_RANGE="${TARGET_RANGE:-172.40.100.0/24}"
PORTS="${PORTS:-80,2222,2525,6379,8000}"
RATE="${RATE:-100}"
WAIT="${WAIT:-0}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_IP" "$TARGET_RANGE" "$PORTS" "$RATE" "$WAIT" <<'EOF'
set -eu

TARGET_IP="$1"
TARGET_RANGE="$2"
PORTS="$3"
RATE="$4"
WAIT="$5"
SCAN_DIR="/work/scans"

mkdir -p "$SCAN_DIR"
rm -f \
  "$SCAN_DIR/target-raw.txt" \
  "$SCAN_DIR/target-open.lst" \
  "$SCAN_DIR/target-open.gnmap" \
  "$SCAN_DIR/target-open.json" \
  "$SCAN_DIR/range-web-raw.txt" \
  "$SCAN_DIR/range-web.lst" \
  "$SCAN_DIR/follow-up-nmap.txt" \
  "$SCAN_DIR/http-status.json"

write_outputs() {
  raw_file="$1"
  list_file="$2"
  grepable_file="$3"
  json_file="$4"
  timestamp="$(date +%s)"

  {
    echo "#masscan"
    awk -v ts="$timestamp" '
      /Discovered open port/ {
        split($4, port_proto, "/")
        print "open " port_proto[2] " " port_proto[1] " " $6 " " ts
      }
    ' "$raw_file" | sort -k4,4 -k3,3n
    echo "# end"
  } > "$list_file"

  {
    echo "# Masscan-compatible summary generated from raw Masscan output"
    awk -v ts="$timestamp" '
      /Discovered open port/ {
        split($4, port_proto, "/")
        printf "Timestamp: %s\tHost: %s ()\tPorts: %s/open/%s//unknown//\n", ts, $6, port_proto[1], port_proto[2]
      }
    ' "$raw_file" | sort -k4,4 -k6,6n
  } > "$grepable_file"

  awk '
    /Discovered open port/ {
      split($4, port_proto, "/")
      print $6 " " port_proto[1] " " port_proto[2]
    }
  ' "$raw_file" | jq -R -s '
    split("\n")
    | map(select(length > 0) | split(" "))
    | map({ip: .[0], ports: [{port: (.[1] | tonumber), proto: .[2], status: "open"}]})
  ' > "$json_file"
}

write_list_only() {
  raw_file="$1"
  list_file="$2"
  timestamp="$(date +%s)"

  {
    echo "#masscan"
    awk -v ts="$timestamp" '
      /Discovered open port/ {
        split($4, port_proto, "/")
        print "open " port_proto[2] " " port_proto[1] " " $6 " " ts
      }
    ' "$raw_file" | sort -k4,4 -k3,3n
    echo "# end"
  } > "$list_file"
}

masscan "$TARGET_IP" -p"$PORTS" --rate "$RATE" --wait "$WAIT" --open-only \
  > "$SCAN_DIR/target-raw.txt"
write_outputs \
  "$SCAN_DIR/target-raw.txt" \
  "$SCAN_DIR/target-open.lst" \
  "$SCAN_DIR/target-open.gnmap" \
  "$SCAN_DIR/target-open.json"

masscan "$TARGET_RANGE" -p80,8000 --rate "$RATE" --wait "$WAIT" --open-only \
  > "$SCAN_DIR/range-web-raw.txt"
write_list_only "$SCAN_DIR/range-web-raw.txt" "$SCAN_DIR/range-web.lst"

nmap -sV -Pn -p "$PORTS" "$TARGET_IP" > "$SCAN_DIR/follow-up-nmap.txt"
curl -sS "http://$TARGET_IP/api/status" > "$SCAN_DIR/http-status.json"
EOF

echo "Generated masscan lab scan outputs."
