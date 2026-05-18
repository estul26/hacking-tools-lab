#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.52.220.20:8080}"
RESOLVER="${RESOLVER:-172.52.220.20}"
DOMAIN="${DOMAIN:-packetlab.local}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$BASE_URL" "$RESOLVER" "$DOMAIN" <<'EOF'
set -eu

BASE_URL="$1"
RESOLVER="$2"
DOMAIN="$3"
OUTPUT_DIR="/work/outputs"
FIXTURE="/work/fixtures/enum.txt"
WORDLIST="/work/wordlists/names.txt"
ALLOW="/work/scope/allow-subdomains.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.jsonl "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
amass -version > "$OUTPUT_DIR/version.txt" 2>&1
if ! timeout 90s amass enum -list -nocolor > "$OUTPUT_DIR/sources.txt" 2>&1; then
  printf 'Amass source listing did not finish within 90 seconds.\n' > "$OUTPUT_DIR/sources.txt"
fi
if [ ! -s "$OUTPUT_DIR/sources.txt" ]; then
  printf 'Amass source listing returned no output.\n' > "$OUTPUT_DIR/sources.txt"
fi

cat > "$OUTPUT_DIR/local-enum-note.txt" <<NOTE
This local lab uses a deterministic Amass-shaped enumeration fixture for packetlab.local.
Amass v4 builds an untrusted resolver pool before enum runs, and that pool is not
designed around a Docker-only private resolver such as $RESOLVER. Use real Amass for
source/version practice here, then validate the local discoveries against the lab target.
NOTE

cp "$FIXTURE" "$OUTPUT_DIR/enum.txt"

grep -E "^[A-Za-z0-9_.-]+\\.$DOMAIN$" "$OUTPUT_DIR/enum.txt" | sort -u > "$OUTPUT_DIR/subdomains.txt" || true
sort -u "$ALLOW" > "$OUTPUT_DIR/allow-subdomains.sorted.txt"
comm -12 "$OUTPUT_DIR/allow-subdomains.sorted.txt" "$OUTPUT_DIR/subdomains.txt" > "$OUTPUT_DIR/in-scope.txt"

{
  printf 'host\tstatus\ttitle\n'
  while IFS= read -r host; do
    response="$(curl -sS -H "Host: $host" -o /tmp/amass-lab-body -w "%{http_code}" "$BASE_URL/")"
    title="$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' /tmp/amass-lab-body | head -1)"
    printf '%s\t%s\t%s\n' "$host" "$response" "$title"
  done < "$OUTPUT_DIR/in-scope.txt"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'domain\t%s\n' "$DOMAIN"
  printf 'wordlist_names\t%s\n' "$(wc -l < "$WORDLIST" | tr -d ' ')"
  printf 'fixture_subdomains\t%s\n' "$(wc -l < "$FIXTURE" | tr -d ' ')"
  printf 'discovered_subdomains\t%s\n' "$(wc -l < "$OUTPUT_DIR/subdomains.txt" | tr -d ' ')"
  printf 'in_scope_subdomains\t%s\n' "$(wc -l < "$OUTPUT_DIR/in-scope.txt" | tr -d ' ')"
  printf 'locally_validated\t%s\n' "$(awk 'NR > 1 && $2 ~ /^(200|401)$/ {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Amass lab outputs."
