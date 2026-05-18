#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.54.240.20:8080}"
DOMAIN="${DOMAIN:-packetlab.local}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" "$DOMAIN" <<'EOF'
set -eu

BASE_URL="$1"
DOMAIN="$2"
OUTPUT_DIR="/work/outputs"
FIXTURE="/work/fixtures/urls.txt"
DOMAINS="/work/scope/domains.txt"
ALLOW_HOSTS="/work/scope/allow-hosts.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
waybackurls -h > "$OUTPUT_DIR/help.txt" 2>&1 || true

cat > "$OUTPUT_DIR/local-archive-note.txt" <<NOTE
This local lab uses a deterministic waybackurls-shaped fixture for $DOMAIN.
waybackurls queries public archive sources, and Docker-only training domains do
not exist in those archives. Use the real binary for help and authorized public
domain workflows, then practice local URL parsing and validation here.
NOTE

sort -u "$FIXTURE" > "$OUTPUT_DIR/urls.txt"

python3 - "$OUTPUT_DIR/urls.txt" "$OUTPUT_DIR/parsed.tsv" <<'PY'
import sys
from urllib.parse import urlparse

with open(sys.argv[1], encoding="utf-8") as source, open(sys.argv[2], "w", encoding="utf-8") as out:
    out.write("url\tscheme\thost\tpath\tquery\n")
    for line in source:
        url = line.strip()
        if not url:
            continue
        parsed = urlparse(url)
        out.write(f"{url}\t{parsed.scheme}\t{parsed.hostname or ''}\t{parsed.path or '/'}\t{parsed.query}\n")
PY

awk -F '\t' 'NR > 1 {print $3}' "$OUTPUT_DIR/parsed.tsv" | sort -u > "$OUTPUT_DIR/hosts.txt"
awk -F '\t' 'NR > 1 && $5 != "" {print $1}' "$OUTPUT_DIR/parsed.tsv" | sort -u > "$OUTPUT_DIR/parameterized-urls.txt"
sort -u "$ALLOW_HOSTS" > "$OUTPUT_DIR/allow-hosts.sorted.txt"
comm -12 "$OUTPUT_DIR/allow-hosts.sorted.txt" "$OUTPUT_DIR/hosts.txt" > "$OUTPUT_DIR/in-scope-hosts.txt"

python3 - "$OUTPUT_DIR/urls.txt" "$OUTPUT_DIR/in-scope-hosts.txt" "$OUTPUT_DIR/in-scope-urls.txt" <<'PY'
import sys
from urllib.parse import urlparse

with open(sys.argv[2], encoding="utf-8") as allowed_file:
    allowed = {line.strip() for line in allowed_file if line.strip()}

with open(sys.argv[1], encoding="utf-8") as source, open(sys.argv[3], "w", encoding="utf-8") as out:
    for line in source:
        url = line.strip()
        if urlparse(url).hostname in allowed:
            out.write(url + "\n")
PY

{
  printf 'url\tstatus\n'
  while IFS= read -r url; do
    target_url="$(python3 - "$url" "$BASE_URL" <<'PY'
import sys
from urllib.parse import urlparse, urlunparse

original = urlparse(sys.argv[1])
base = urlparse(sys.argv[2])
target = urlunparse((base.scheme, base.netloc, original.path or "/", "", original.query, ""))
print(target)
PY
)"
    host="$(python3 - "$url" <<'PY'
import sys
from urllib.parse import urlparse
print(urlparse(sys.argv[1]).hostname or "")
PY
)"
    code="$(curl -sS -H "Host: $host" -o /tmp/waybackurls-lab-body -w "%{http_code}" "$target_url")"
    printf '%s\t%s\n' "$url" "$code"
  done < "$OUTPUT_DIR/in-scope-urls.txt"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'domain_count\t%s\n' "$(wc -l < "$DOMAINS" | tr -d ' ')"
  printf 'fixture_urls\t%s\n' "$(wc -l < "$FIXTURE" | tr -d ' ')"
  printf 'unique_urls\t%s\n' "$(wc -l < "$OUTPUT_DIR/urls.txt" | tr -d ' ')"
  printf 'unique_hosts\t%s\n' "$(wc -l < "$OUTPUT_DIR/hosts.txt" | tr -d ' ')"
  printf 'in_scope_hosts\t%s\n' "$(wc -l < "$OUTPUT_DIR/in-scope-hosts.txt" | tr -d ' ')"
  printf 'in_scope_urls\t%s\n' "$(wc -l < "$OUTPUT_DIR/in-scope-urls.txt" | tr -d ' ')"
  printf 'parameterized_urls\t%s\n' "$(wc -l < "$OUTPUT_DIR/parameterized-urls.txt" | tr -d ' ')"
  printf 'locally_validated\t%s\n' "$(awk 'NR > 1 && $2 ~ /^(200|401|403)$/ {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated waybackurls lab outputs."
