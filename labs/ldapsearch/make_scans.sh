#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_HOST="${TARGET_HOST:-172.63.85.20}"
BASE_DN="${BASE_DN:-dc=packetlab,dc=local}"
BIND_DN="${BIND_DN:-cn=admin,dc=packetlab,dc=local}"
BIND_PASS="${BIND_PASS:-packetlab-admin}"
OUTPUT_DIR="${OUTPUT_DIR:-/work/outputs}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- \
  "$TARGET_HOST" "$BASE_DN" "$BIND_DN" "$BIND_PASS" "$OUTPUT_DIR" <<'EOF'
set -eu

TARGET_HOST="$1"
BASE_DN="$2"
BIND_DN="$3"
BIND_PASS="$4"
OUTPUT_DIR="$5"
LDAP_URI="ldap://$TARGET_HOST:389"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.ldif "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if nc -z "$TARGET_HOST" 389 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

nc -z "$TARGET_HOST" 389 > "$OUTPUT_DIR/ldap-port.txt" 2>&1
ldapsearch -VV > "$OUTPUT_DIR/version.txt" 2>&1 || true
ldapsearch -H > "$OUTPUT_DIR/help.txt" 2>&1 || true

ldapsearch -x -H "$LDAP_URI" -s base -b "" namingContexts \
  > "$OUTPUT_DIR/root-dse.ldif" 2>&1
ldapsearch -x -H "$LDAP_URI" -b "$BASE_DN" -s base dn dc o \
  > "$OUTPUT_DIR/base.ldif" 2>&1
ldapsearch -x -H "$LDAP_URI" -b "ou=People,$BASE_DN" "(objectClass=inetOrgPerson)" uid cn mail description \
  > "$OUTPUT_DIR/people.ldif" 2>&1
ldapsearch -x -H "$LDAP_URI" -b "ou=Groups,$BASE_DN" "(objectClass=groupOfNames)" cn member description \
  > "$OUTPUT_DIR/groups.ldif" 2>&1
ldapsearch -x -H "$LDAP_URI" -D "$BIND_DN" -w "$BIND_PASS" -b "$BASE_DN" "(uid=svc-*)" dn uid description \
  > "$OUTPUT_DIR/service-accounts.ldif" 2>&1
ldapsearch -x -H "$LDAP_URI" -D "$BIND_DN" -w wrong-password -b "$BASE_DN" "(uid=alice)" dn \
  > "$OUTPUT_DIR/bind-failure.txt" 2>&1 || true

{
  printf 'uid\tcn\tmail\n'
  awk '
    /^uid: / {uid=$2}
    /^cn: / {$1=""; sub(/^ /, ""); cn=$0}
    /^mail: / {mail=$2}
    /^$/ && uid != "" {print uid "\t" cn "\t" mail; uid=cn=mail=""}
    END {if (uid != "") print uid "\t" cn "\t" mail}
  ' "$OUTPUT_DIR/people.ldif"
} > "$OUTPUT_DIR/people.tsv"

{
  printf 'group\tmember_count\n'
  awk '
    /^cn: / {group=$2; count=0}
    /^member: / {count++}
    /^$/ && group != "" {print group "\t" count; group=""; count=0}
    END {if (group != "") print group "\t" count}
  ' "$OUTPUT_DIR/groups.ldif"
} > "$OUTPUT_DIR/groups.tsv"

{
  printf 'check\tstatus\n'
  if grep -Fq "$BASE_DN" "$OUTPUT_DIR/root-dse.ldif"; then
    printf 'naming_context_seen\tyes\n'
  else
    printf 'naming_context_seen\tno\n'
  fi
  if grep -Fq "dn: $BASE_DN" "$OUTPUT_DIR/base.ldif"; then
    printf 'base_dn_seen\tyes\n'
  else
    printf 'base_dn_seen\tno\n'
  fi
  if grep -Eq '^uid: (alice|bob|svc-backup)$' "$OUTPUT_DIR/people.ldif"; then
    printf 'people_seen\tyes\n'
  else
    printf 'people_seen\tno\n'
  fi
  if grep -Eq '^cn: (helpdesk|engineering)$' "$OUTPUT_DIR/groups.ldif"; then
    printf 'groups_seen\tyes\n'
  else
    printf 'groups_seen\tno\n'
  fi
  if grep -Fq 'uid: svc-backup' "$OUTPUT_DIR/service-accounts.ldif"; then
    printf 'authenticated_filter_seen\tyes\n'
  else
    printf 'authenticated_filter_seen\tno\n'
  fi
  if grep -Eiq 'Invalid credentials|ldap_bind|err=49' "$OUTPUT_DIR/bind-failure.txt"; then
    printf 'bad_bind_rejected\tyes\n'
  else
    printf 'bad_bind_rejected\tno\n'
  fi
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'item\tvalue\n'
  printf 'target\t%s\n' "$TARGET_HOST"
  printf 'base_dn\t%s\n' "$BASE_DN"
  printf 'people\t%s\n' "$(awk 'NR > 1 {count++} END {print count + 0}' "$OUTPUT_DIR/people.tsv")"
  printf 'groups\t%s\n' "$(awk 'NR > 1 {count++} END {print count + 0}' "$OUTPUT_DIR/groups.tsv")"
  printf 'validation_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/validation.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated ldapsearch lab outputs."
