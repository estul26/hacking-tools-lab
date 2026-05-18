#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.53.230.20:8080}"
DOMAIN="${DOMAIN:-packetlab.local}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" "$DOMAIN" <<'EOF'
set -eu

BASE_URL="$1"
DOMAIN="$2"
OUTPUT_DIR="/work/outputs"
FIXTURE="/work/fixtures/results.json"
DOMAINS="/work/scope/domains.txt"
ALLOW_HOSTS="/work/scope/allow-hosts.txt"
ALLOW_EMAILS="/work/scope/allow-emails.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
theHarvester -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
awk '/theHarvester [0-9]/{print $3; found=1; exit} END {if (!found) print "unknown"}' \
  "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/version.txt"

cat > "$OUTPUT_DIR/local-osint-note.txt" <<NOTE
This local lab uses a deterministic theHarvester-shaped fixture for $DOMAIN.
theHarvester gathers OSINT from public data sources, and Docker-only training
domains do not exist in those sources. Use the real tool for help/version and
authorized public-domain workflows, then practice local parsing and validation here.
NOTE

cp "$FIXTURE" "$OUTPUT_DIR/results.json"

jq -r '.hosts[]' "$OUTPUT_DIR/results.json" | sort -u > "$OUTPUT_DIR/hosts.txt"
jq -r '.emails[]' "$OUTPUT_DIR/results.json" | sort -u > "$OUTPUT_DIR/emails.txt"
sort -u "$ALLOW_HOSTS" > "$OUTPUT_DIR/allow-hosts.sorted.txt"
sort -u "$ALLOW_EMAILS" > "$OUTPUT_DIR/allow-emails.sorted.txt"
comm -12 "$OUTPUT_DIR/allow-hosts.sorted.txt" "$OUTPUT_DIR/hosts.txt" > "$OUTPUT_DIR/in-scope-hosts.txt"
comm -12 "$OUTPUT_DIR/allow-emails.sorted.txt" "$OUTPUT_DIR/emails.txt" > "$OUTPUT_DIR/in-scope-emails.txt"

{
  printf 'host\tstatus\ttitle\n'
  while IFS= read -r host; do
    response="$(curl -sS -H "Host: $host" -o /tmp/theharvester-lab-body -w "%{http_code}" "$BASE_URL/")"
    title="$(sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' /tmp/theharvester-lab-body | head -1)"
    printf '%s\t%s\t%s\n' "$host" "$response" "$title"
  done < "$OUTPUT_DIR/in-scope-hosts.txt"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'domain_count\t%s\n' "$(wc -l < "$DOMAINS" | tr -d ' ')"
  printf 'fixture_hosts\t%s\n' "$(wc -l < "$OUTPUT_DIR/hosts.txt" | tr -d ' ')"
  printf 'fixture_emails\t%s\n' "$(wc -l < "$OUTPUT_DIR/emails.txt" | tr -d ' ')"
  printf 'in_scope_hosts\t%s\n' "$(wc -l < "$OUTPUT_DIR/in-scope-hosts.txt" | tr -d ' ')"
  printf 'in_scope_emails\t%s\n' "$(wc -l < "$OUTPUT_DIR/in-scope-emails.txt" | tr -d ' ')"
  printf 'locally_validated\t%s\n' "$(awk 'NR > 1 && $2 ~ /^(200|401)$/ {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated theHarvester lab outputs."
