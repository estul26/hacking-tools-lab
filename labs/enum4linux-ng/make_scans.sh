#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_HOST="${TARGET_HOST:-172.65.87.20}"
LAB_USER="${LAB_USER:-labuser}"
LAB_PASS="${LAB_PASS:-labpass!}"
OUTPUT_DIR="${OUTPUT_DIR:-/work/outputs}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_HOST" "$LAB_USER" "$LAB_PASS" "$OUTPUT_DIR" <<'EOF'
set -eu

TARGET_HOST="$1"
LAB_USER="$2"
LAB_PASS="$3"
OUTPUT_DIR="$4"
JSON_BASE="$OUTPUT_DIR/authenticated"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if nc -z "$TARGET_HOST" 445 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

nc -z "$TARGET_HOST" 445 > "$OUTPUT_DIR/smb-port.txt" 2>&1
enum4linux-ng --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
sed -n '1p' "$OUTPUT_DIR/help.txt" > "$OUTPUT_DIR/version.txt"

smbclient -L "//$TARGET_HOST" -U "$LAB_USER%$LAB_PASS" -m SMB3 \
  > "$OUTPUT_DIR/smbclient-shares.txt" 2>&1

enum4linux-ng -A "$TARGET_HOST" \
  -u "$LAB_USER" -p "$LAB_PASS" \
  -oJ "$JSON_BASE" \
  > "$OUTPUT_DIR/authenticated.txt" 2>&1 || true

enum4linux-ng -S "$TARGET_HOST" \
  -u "$LAB_USER" -p "$LAB_PASS" \
  > "$OUTPUT_DIR/share-enum.txt" 2>&1 || true

enum4linux-ng -A "$TARGET_HOST" \
  -u "$LAB_USER" -p wrong-password \
  > "$OUTPUT_DIR/auth-failure.txt" 2>&1 || true

{
  printf 'check\tstatus\n'
  if grep -Eiq 'enum4linux-ng|usage:' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if grep -Fq 'ENUM4LAB' "$OUTPUT_DIR/authenticated.txt" || grep -Fq 'Enum4linux-ng Local Lab' "$OUTPUT_DIR/authenticated.txt"; then
    printf 'target_identity_seen\tyes\n'
  else
    printf 'target_identity_seen\tno\n'
  fi
  if grep -Eq 'labshare|reports' "$OUTPUT_DIR/authenticated.txt" "$OUTPUT_DIR/share-enum.txt" "$OUTPUT_DIR/smbclient-shares.txt"; then
    printf 'shares_seen\tyes\n'
  else
    printf 'shares_seen\tno\n'
  fi
  if grep -Eq 'WORKGROUP|workgroup' "$OUTPUT_DIR/authenticated.txt"; then
    printf 'workgroup_seen\tyes\n'
  else
    printf 'workgroup_seen\tno\n'
  fi
  if [ -s "$OUTPUT_DIR/authenticated.json" ] && jq -e 'type == "object"' "$OUTPUT_DIR/authenticated.json" >/dev/null; then
    printf 'json_output_valid\tyes\n'
  else
    printf 'json_output_valid\tno\n'
  fi
  if grep -Eiq 'logon failure|STATUS_LOGON_FAILURE|failed|denied|invalid' "$OUTPUT_DIR/auth-failure.txt"; then
    printf 'bad_auth_rejected\tyes\n'
  else
    printf 'bad_auth_rejected\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'target\t%s\n' "$TARGET_HOST"
  printf 'credential\t%s:%s\n' "$LAB_USER" "$LAB_PASS"
  printf 'shares_from_smbclient\t%s\n' "$(grep -Ec 'labshare|reports' "$OUTPUT_DIR/smbclient-shares.txt" || true)"
  printf 'json_written\t%s\n' "$([ -s "$OUTPUT_DIR/authenticated.json" ] && printf yes || printf no)"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated enum4linux-ng lab outputs."
