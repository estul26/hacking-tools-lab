#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_HOST="${TARGET_HOST:-172.57.70.20}"
TARGET_PORT="${TARGET_PORT:-8080}"
BASE_URL="http://$TARGET_HOST:$TARGET_PORT"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_HOST" "$TARGET_PORT" "$BASE_URL" <<'EOF'
set -eu

TARGET_HOST="$1"
TARGET_PORT="$2"
BASE_URL="$3"
OUTPUT_DIR="/work/outputs"
USERS="/work/wordlists/users.txt"
PASSWORDS="/work/wordlists/passwords.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
hydra -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
sed -n '1,3p' "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/version.txt"

curl -sS -i "$BASE_URL/basic" > "$OUTPUT_DIR/basic-unauthorized.txt"
curl -sS -i -u admin:packetlab "$BASE_URL/basic" > "$OUTPUT_DIR/basic-authorized.txt"
curl -sS -i \
  -d "username=admin&password=wrong" \
  "$BASE_URL/login" > "$OUTPUT_DIR/form-invalid.txt"
curl -sS -i \
  -d "username=admin&password=packetlab" \
  "$BASE_URL/login" > "$OUTPUT_DIR/form-valid.txt"

hydra \
  -L "$USERS" \
  -P "$PASSWORDS" \
  -s "$TARGET_PORT" \
  -t 2 \
  -w 5 \
  -f \
  -I \
  -o "$OUTPUT_DIR/basic-hydra.txt" \
  "$TARGET_HOST" \
  http-get /basic > "$OUTPUT_DIR/basic-hydra.log" 2>&1 || true

hydra \
  -L "$USERS" \
  -P "$PASSWORDS" \
  -s "$TARGET_PORT" \
  -t 2 \
  -w 5 \
  -f \
  -I \
  -o "$OUTPUT_DIR/form-hydra.txt" \
  "$TARGET_HOST" \
  http-post-form "/login:username=^USER^&password=^PASS^:F=Invalid login" \
  > "$OUTPUT_DIR/form-hydra.log" 2>&1 || true

{
  printf 'scan\tmatches\tcredential\n'
  for name in basic form; do
    file="$OUTPUT_DIR/$name-hydra.txt"
    matches="$(grep -c "^\\[" "$file" 2>/dev/null || true)"
    credential="$(sed -n 's/^.*login: \([^ ]*\).*password: \([^ ]*\).*/\1:\2/p' "$file" | head -1)"
    printf '%s\t%s\t%s\n' "$name" "$matches" "${credential:-none}"
  done
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Hydra lab outputs."
