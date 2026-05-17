#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://target:8080}"
TARGET_IP="${TARGET_IP:-172.43.130.20}"
DOMAIN="${DOMAIN:-gobuster.lab}"
THREADS="${THREADS:-5}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BASE_URL" "$TARGET_IP" "$DOMAIN" "$THREADS" <<'EOF'
set -eu

BASE_URL="$1"
TARGET_IP="$2"
DOMAIN="$3"
THREADS="$4"
OUTPUT_DIR="/work/outputs"
WORDLIST_DIR="/work/wordlists"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/http-status.json

common_flags="-t $THREADS -z --no-error --no-color -q"

gobuster dir \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/paths.txt" \
  $common_flags \
  -o "$OUTPUT_DIR/dirs.txt"

gobuster dir \
  -u "$BASE_URL/files" \
  -w "$WORDLIST_DIR/files.txt" \
  -x txt,json,html \
  $common_flags \
  -o "$OUTPUT_DIR/extensions.txt"

gobuster vhost \
  -u "$BASE_URL" \
  -w "$WORDLIST_DIR/vhosts.txt" \
  --append-domain \
  --domain "$DOMAIN" \
  $common_flags \
  -o "$OUTPUT_DIR/vhosts.txt"

gobuster dns \
  -d "$DOMAIN" \
  -w "$WORDLIST_DIR/subdomains.txt" \
  -r "$TARGET_IP" \
  -i \
  $common_flags \
  -o "$OUTPUT_DIR/dns.txt"

gobuster fuzz \
  -u "$BASE_URL/search?FUZZ=packetlab" \
  -w "$WORDLIST_DIR/params.txt" \
  -b 400,404 \
  $common_flags \
  -o "$OUTPUT_DIR/params.txt"

gobuster fuzz \
  -u "$BASE_URL/tokens/FUZZ" \
  -w "$WORDLIST_DIR/passwords.txt" \
  -b 404 \
  $common_flags \
  -o "$OUTPUT_DIR/tokens.txt"

for name in dirs extensions vhosts dns params tokens; do
  awk -v scan="$name" '
    BEGIN { print "scan\tresult" }
    NF {
      gsub(/\t/, " ")
      print scan "\t" $0
    }
  ' "$OUTPUT_DIR/$name.txt" > "$OUTPUT_DIR/$name.tsv"
done

curl -sS "$BASE_URL/api/status" > "$OUTPUT_DIR/http-status.json"
EOF

echo "Generated gobuster lab outputs."
