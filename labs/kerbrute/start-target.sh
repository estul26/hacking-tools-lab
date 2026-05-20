#!/usr/bin/env sh
set -eu

REALM="PACKETLAB.LOCAL"
MASTER_PASS="packetlab-master"

if [ ! -f /var/lib/krb5kdc/principal ]; then
  kdb5_util create -s -P "$MASTER_PASS" -r "$REALM"
fi

add_principal() {
  principal="$1"
  password="$2"
  if ! kadmin.local -q "getprinc $principal" 2>/dev/null | grep -Fq "Principal: $principal@$REALM"; then
    kadmin.local -q "addprinc -pw $password $principal" >/dev/null
  fi
}

add_principal "alice" "Winter2026!"
add_principal "bob" "Builder2026!"
add_principal "svc-backup" "Backup2026!"

exec krb5kdc -n
