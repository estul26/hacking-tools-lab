#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://wordpress}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"

for _ in $(seq 1 90); do
  if curl -fsS "$BASE_URL/wp-login.php" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done

echo "WordPress did not become reachable at $BASE_URL" >&2
exit 1
EOF

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T wpcli sh -s <<'EOF'
set -eu

cd /var/www/html

for _ in $(seq 1 90); do
  if wp core version --allow-root >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! wp core is-installed --allow-root >/dev/null 2>&1; then
  wp core install \
    --url=http://wordpress \
    --title="WPScan Local Lab" \
    --admin_user=admin \
    --admin_password=packetlab \
    --admin_email=admin@wpscan.lab \
    --skip-email \
    --allow-root
fi

wp option update blogdescription "Local WordPress target for WPScan practice." --allow-root >/dev/null
wp plugin activate local-lab-audit --allow-root >/dev/null
wp theme activate packetlab --allow-root >/dev/null

if ! wp user get author --field=ID --allow-root >/dev/null 2>&1; then
  wp user create author author@wpscan.lab --role=author --user_pass=authorpass --allow-root >/dev/null
fi

if ! wp user get editor --field=ID --allow-root >/dev/null 2>&1; then
  wp user create editor editor@wpscan.lab --role=editor --user_pass=editorpass --allow-root >/dev/null
fi

if [ "$(wp post list --post_type=post --name=packet-lab-report --format=count --allow-root)" = "0" ]; then
  wp post create \
    --post_type=post \
    --post_status=publish \
    --post_author=1 \
    --post_title="Packet Lab Report" \
    --post_name=packet-lab-report \
    --post_content='[local_lab_audit] This post gives WPScan user and content signals to enumerate.' \
    --allow-root >/dev/null
fi
EOF

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" <<'EOF'
set -eu

BASE_URL="$1"
OUTPUT_DIR="/work/outputs"
WORDLIST_DIR="/work/wordlists"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv

wpscan --update > "$OUTPUT_DIR/update.txt"
wpscan --version > "$OUTPUT_DIR/version.txt"
curl -sS "$BASE_URL/wp-json/" > "$OUTPUT_DIR/wp-json.json"
curl -sS "$BASE_URL/wp-login.php" > "$OUTPUT_DIR/login.html"

wpscan \
  --url "$BASE_URL" \
  --no-update \
  --random-user-agent \
  --format json \
  --output "$OUTPUT_DIR/baseline.json"

wpscan \
  --url "$BASE_URL" \
  --no-update \
  --random-user-agent \
  --enumerate u,p,t \
  --plugins-detection mixed \
  --format json \
  --output "$OUTPUT_DIR/enumeration.json"

wpscan \
  --url "$BASE_URL" \
  --no-update \
  --random-user-agent \
  --usernames admin \
  --passwords "$WORDLIST_DIR/passwords.txt" \
  --max-threads 2 \
  --password-attack wp-login \
  --format json \
  --output "$OUTPUT_DIR/password-audit.json"

jq -r '
  ["item","value"],
  ["wordpress_version", (.version.number // "unknown")],
  ["main_theme", (.main_theme.slug // "unknown")],
  ["plugins", (((.plugins // {}) | keys | map(select(. != "*"))) | join(","))],
  ["themes", (((.themes // {}) | keys | map(select(. != "*"))) | join(","))],
  ["users", (((.users // {}) | keys) | join(","))]
  | @tsv
' "$OUTPUT_DIR/enumeration.json" > "$OUTPUT_DIR/summary.tsv"

if jq -e '(.password_attack // {}) | to_entries[] | select(.value.password)' "$OUTPUT_DIR/password-audit.json" >/dev/null 2>&1; then
  jq -r '(.password_attack // {}) | to_entries[] | select(.value.password) | ["password_audit", .key, .value.password] | @tsv' \
    "$OUTPUT_DIR/password-audit.json" >> "$OUTPUT_DIR/summary.tsv"
fi
EOF

echo "Generated WPScan lab outputs."
