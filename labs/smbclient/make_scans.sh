#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_HOST="${TARGET_HOST:-172.64.86.20}"
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
AUTH="-U $LAB_USER%$LAB_PASS"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.tsv "$OUTPUT_DIR"/*.log

for _ in $(seq 1 60); do
  if nc -z "$TARGET_HOST" 445 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

nc -z "$TARGET_HOST" 445 > "$OUTPUT_DIR/smb-port.txt" 2>&1
smbclient --version > "$OUTPUT_DIR/version.txt" 2>&1 || true
smbclient --help > "$OUTPUT_DIR/help.txt" 2>&1 || true

smbclient -L "//$TARGET_HOST" $AUTH -m SMB3 \
  > "$OUTPUT_DIR/share-list.txt" 2>&1
smbclient "//$TARGET_HOST/labshare" $AUTH -m SMB3 -c 'ls' \
  > "$OUTPUT_DIR/labshare-ls.txt" 2>&1
smbclient "//$TARGET_HOST/labshare" $AUTH -m SMB3 -c 'cd docs; ls' \
  > "$OUTPUT_DIR/docs-ls.txt" 2>&1
smbclient "//$TARGET_HOST/labshare" $AUTH -m SMB3 -c 'get docs/notes.txt /work/outputs/notes-downloaded.txt' \
  > "$OUTPUT_DIR/download.log" 2>&1
smbclient "//$TARGET_HOST/dropbox" $AUTH -m SMB3 \
  -c 'put /work/upload/lab-upload.txt lab-upload.txt; ls; del lab-upload.txt' \
  > "$OUTPUT_DIR/upload-delete.txt" 2>&1
smbclient "//$TARGET_HOST/labshare" -U "$LAB_USER%wrong-password" -m SMB3 -c 'ls' \
  > "$OUTPUT_DIR/auth-failure.txt" 2>&1 || true

{
  printf 'check\tstatus\n'
  if grep -Eiq 'Version|smbclient' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if grep -Eq 'labshare|dropbox' "$OUTPUT_DIR/share-list.txt"; then
    printf 'shares_listed\tyes\n'
  else
    printf 'shares_listed\tno\n'
  fi
  if grep -Fq 'readme.txt' "$OUTPUT_DIR/labshare-ls.txt"; then
    printf 'labshare_listed\tyes\n'
  else
    printf 'labshare_listed\tno\n'
  fi
  if grep -Eq 'notes.txt|inventory.txt' "$OUTPUT_DIR/docs-ls.txt"; then
    printf 'docs_listed\tyes\n'
  else
    printf 'docs_listed\tno\n'
  fi
  if grep -Fq 'Quarterly local lab notes' "$OUTPUT_DIR/notes-downloaded.txt"; then
    printf 'file_downloaded\tyes\n'
  else
    printf 'file_downloaded\tno\n'
  fi
  if grep -Fq 'lab-upload.txt' "$OUTPUT_DIR/upload-delete.txt"; then
    printf 'upload_seen\tyes\n'
  else
    printf 'upload_seen\tno\n'
  fi
  if grep -Eiq 'NT_STATUS_LOGON_FAILURE|LOGON_FAILURE|session setup failed' "$OUTPUT_DIR/auth-failure.txt"; then
    printf 'bad_auth_rejected\tyes\n'
  else
    printf 'bad_auth_rejected\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'target\t%s\n' "$TARGET_HOST"
  printf 'credential\t%s:%s\n' "$LAB_USER" "$LAB_PASS"
  printf 'shares\t%s\n' "$(grep -Ec 'labshare|dropbox' "$OUTPUT_DIR/share-list.txt" || true)"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated smbclient lab outputs."
