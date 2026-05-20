#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASE_URL="${BASE_URL:-http://172.62.84.20:8080}"
DOMAIN="${DOMAIN:-PACKETLAB.LOCAL}"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec -T scanner sh -s -- "$BASE_URL" "$DOMAIN" <<'EOF'
set -eu

BASE_URL="$1"
DOMAIN="$2"
OUTPUT_DIR="/work/outputs"
FIXTURE="/work/fixtures/packetlab-graph.json"
ALLOW_OBJECTS="/work/scope/allowed-objects.txt"

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.tsv

for _ in $(seq 1 60); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

curl -fsS "$BASE_URL/health" > "$OUTPUT_DIR/http-status.json"
bloodhound-python -h > "$OUTPUT_DIR/help.txt" 2>&1 || true
dpkg-query -W -f='${Version}\n' bloodhound.py > "$OUTPUT_DIR/version.txt" 2>&1 || true

cat > "$OUTPUT_DIR/local-collection-note.txt" <<NOTE
This local lab uses a deterministic BloodHound-style graph fixture for $DOMAIN.
BloodHound.py collects from Active Directory through LDAP, DNS, Kerberos, SMB,
and related services. A realistic AD controller is intentionally outside this
small Docker lab, so use the real tool for help/version/config practice and
practice local graph parsing, scope review, and validation here.
NOTE

cp "$FIXTURE" "$OUTPUT_DIR/packetlab-graph.json"

jq -r '.users[] | [.name, .samaccountname, .enabled] | @tsv' \
  "$OUTPUT_DIR/packetlab-graph.json" > "$OUTPUT_DIR/users.tsv"
jq -r '.groups[] | [.name, .highvalue] | @tsv' \
  "$OUTPUT_DIR/packetlab-graph.json" > "$OUTPUT_DIR/groups.tsv"
jq -r '.computers[] | [.name, .operatingsystem, .highvalue] | @tsv' \
  "$OUTPUT_DIR/packetlab-graph.json" > "$OUTPUT_DIR/computers.tsv"
jq -r '.edges[] | [.source, .relationship, .target] | @tsv' \
  "$OUTPUT_DIR/packetlab-graph.json" > "$OUTPUT_DIR/edges.tsv"

jq -r '.users[].name, .groups[].name, .computers[].name' \
  "$OUTPUT_DIR/packetlab-graph.json" | sort -u > "$OUTPUT_DIR/objects.txt"
sort -u "$ALLOW_OBJECTS" > "$OUTPUT_DIR/allowed-objects.sorted.txt"
comm -23 "$OUTPUT_DIR/objects.txt" "$OUTPUT_DIR/allowed-objects.sorted.txt" \
  > "$OUTPUT_DIR/out-of-scope-objects.txt"

jq -r '.groups[] | select(.highvalue == true) | .name' \
  "$OUTPUT_DIR/packetlab-graph.json" > "$OUTPUT_DIR/highvalue-groups.txt"
jq -r '.computers[] | select(.highvalue == true) | .name' \
  "$OUTPUT_DIR/packetlab-graph.json" > "$OUTPUT_DIR/highvalue-computers.txt"
jq -r '.edges[] | select(.relationship == "AdminTo" or .relationship == "CanRDP") | [.source, .relationship, .target] | @tsv' \
  "$OUTPUT_DIR/packetlab-graph.json" > "$OUTPUT_DIR/session-path-hints.tsv"

{
  printf 'object\tstatus\ttype\n'
  while IFS= read -r object; do
    encoded="$(printf '%s' "$object" | jq -sRr @uri)"
    response="$(curl -sS -o /tmp/bloodhound-python-object.json -w "%{http_code}" "$BASE_URL/objects/$encoded")"
    type="$(jq -r '.type // "missing"' /tmp/bloodhound-python-object.json)"
    printf '%s\t%s\t%s\n' "$object" "$response" "$type"
  done < "$OUTPUT_DIR/objects.txt"
} > "$OUTPUT_DIR/validation.tsv"

{
  printf 'check\tstatus\n'
  if grep -Eiq 'usage:|bloodhound' "$OUTPUT_DIR/help.txt"; then
    printf 'help_available\tyes\n'
  else
    printf 'help_available\tno\n'
  fi
  if jq -e ".domain == \"$DOMAIN\"" "$OUTPUT_DIR/packetlab-graph.json" >/dev/null; then
    printf 'domain_fixture_loaded\tyes\n'
  else
    printf 'domain_fixture_loaded\tno\n'
  fi
  if [ ! -s "$OUTPUT_DIR/out-of-scope-objects.txt" ]; then
    printf 'scope_filter_clean\tyes\n'
  else
    printf 'scope_filter_clean\tno\n'
  fi
  if awk -F'\t' 'NR > 1 {total++; if ($2 == "200") ok++} END {exit(total > 0 && ok == total ? 0 : 1)}' "$OUTPUT_DIR/validation.tsv"; then
    printf 'objects_validated\tyes\n'
  else
    printf 'objects_validated\tno\n'
  fi
  if grep -Fq 'DOMAIN ADMINS@PACKETLAB.LOCAL' "$OUTPUT_DIR/highvalue-groups.txt"; then
    printf 'highvalue_group_seen\tyes\n'
  else
    printf 'highvalue_group_seen\tno\n'
  fi
  if grep -Fq 'AdminTo' "$OUTPUT_DIR/session-path-hints.tsv"; then
    printf 'admin_edge_seen\tyes\n'
  else
    printf 'admin_edge_seen\tno\n'
  fi
} > "$OUTPUT_DIR/checks.tsv"

{
  printf 'item\tvalue\n'
  printf 'domain\t%s\n' "$DOMAIN"
  printf 'users\t%s\n' "$(wc -l < "$OUTPUT_DIR/users.tsv" | tr -d ' ')"
  printf 'groups\t%s\n' "$(wc -l < "$OUTPUT_DIR/groups.tsv" | tr -d ' ')"
  printf 'computers\t%s\n' "$(wc -l < "$OUTPUT_DIR/computers.tsv" | tr -d ' ')"
  printf 'edges\t%s\n' "$(wc -l < "$OUTPUT_DIR/edges.tsv" | tr -d ' ')"
  printf 'highvalue_groups\t%s\n' "$(wc -l < "$OUTPUT_DIR/highvalue-groups.txt" | tr -d ' ')"
  printf 'out_of_scope_objects\t%s\n' "$(wc -l < "$OUTPUT_DIR/out-of-scope-objects.txt" | tr -d ' ')"
  printf 'checks_passed\t%s\n' "$(awk -F'\t' 'NR > 1 && $2 == "yes" {count++} END {print count + 0}' "$OUTPUT_DIR/checks.tsv")"
} > "$OUTPUT_DIR/summary.tsv"
EOF

echo "Generated BloodHound.py lab outputs."
