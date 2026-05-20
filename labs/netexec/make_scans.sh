#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_HOST="${TARGET_HOST:-172.61.83.20}"
OUTPUT_DIR="${OUTPUT_DIR:-/work/outputs}"
LAB_USER="${LAB_USER:-labuser}"
LAB_PASS="${LAB_PASS:-labpass!}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_HOST" "$OUTPUT_DIR" "$LAB_USER" "$LAB_PASS" <<'EOF'
set -eu

TARGET_HOST="$1"
OUTPUT_DIR="$2"
LAB_USER="$3"
LAB_PASS="$4"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if nc -z "$TARGET_HOST" 22 >/dev/null 2>&1 && nc -z "$TARGET_HOST" 445 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

nc -z "$TARGET_HOST" 22 > "$OUTPUT_DIR/ssh-port.txt" 2>&1
nc -z "$TARGET_HOST" 445 > "$OUTPUT_DIR/smb-port.txt" 2>&1

nxc --help > "$OUTPUT_DIR/help.txt" 2>&1 || true
nxc --version > "$OUTPUT_DIR/version.txt" 2>&1 || true
nxc ssh --help > "$OUTPUT_DIR/ssh-help.txt" 2>&1 || true
nxc smb --help > "$OUTPUT_DIR/smb-help.txt" 2>&1 || true

nxc ssh "$TARGET_HOST" -u "$LAB_USER" -p "$LAB_PASS" \
  > "$OUTPUT_DIR/ssh-success.txt" 2>&1 || true
nxc ssh "$TARGET_HOST" -u "$LAB_USER" -p wrong-password \
  > "$OUTPUT_DIR/ssh-failure.txt" 2>&1 || true
nxc smb "$TARGET_HOST" -u "$LAB_USER" -p "$LAB_PASS" \
  > "$OUTPUT_DIR/smb-success.txt" 2>&1 || true
nxc smb "$TARGET_HOST" -u "$LAB_USER" -p "$LAB_PASS" --shares \
  > "$OUTPUT_DIR/smb-shares.txt" 2>&1 || true
nxc smb "$TARGET_HOST" -u "$LAB_USER" -p wrong-password \
  > "$OUTPUT_DIR/smb-failure.txt" 2>&1 || true

{
  printf 'check\tstatus\n'
  if grep -Eiq 'NetExec|nxc|usage:' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if grep -Eiq 'Pwn3d!|SUCCESS|Authentication successful|labuser' "$OUTPUT_DIR/ssh-success.txt"; then
    printf 'ssh_success_seen\tyes\n'
  else
    printf 'ssh_success_seen\tno\n'
  fi
  if grep -Eiq '\[-\].*wrong-password|STATUS_LOGON_FAILURE|Authentication failed|FAIL|denied' "$OUTPUT_DIR/ssh-failure.txt"; then
    printf 'ssh_failure_seen\tyes\n'
  else
    printf 'ssh_failure_seen\tno\n'
  fi
  if grep -Eiq 'Pwn3d!|SUCCESS|Signing|SMB|labuser' "$OUTPUT_DIR/smb-success.txt"; then
    printf 'smb_success_seen\tyes\n'
  else
    printf 'smb_success_seen\tno\n'
  fi
  if grep -Eiq 'labshare|READ|WRITE' "$OUTPUT_DIR/smb-shares.txt"; then
    printf 'smb_share_seen\tyes\n'
  else
    printf 'smb_share_seen\tno\n'
  fi
  if grep -Eiq 'STATUS_LOGON_FAILURE|FAIL|denied' "$OUTPUT_DIR/smb-failure.txt"; then
    printf 'smb_failure_seen\tyes\n'
  else
    printf 'smb_failure_seen\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'target\t%s\n' "$TARGET_HOST"
  printf 'credential\t%s:%s\n' "$LAB_USER" "$LAB_PASS"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
  printf 'ssh_result\t%s\n' "$(grep -Ehio '\[\+\].*Shell access|\[-\].*wrong-password|Pwn3d!|SUCCESS|Authentication successful|FAIL|denied' "$OUTPUT_DIR/ssh-success.txt" "$OUTPUT_DIR/ssh-failure.txt" 2>/dev/null | head -1 | tr '\t' ' ' || true)"
  printf 'smb_share\t%s\n' "$(grep -Ei 'labshare|READ|WRITE' "$OUTPUT_DIR/smb-shares.txt" 2>/dev/null | head -1 | tr '\t' ' ' || true)"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated NetExec lab outputs."
