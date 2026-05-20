#!/usr/bin/env sh
set -eu

LDAP_URI="ldap://127.0.0.1:389"
BASE_DN="dc=packetlab,dc=local"
ADMIN_DN="cn=admin,$BASE_DN"
ADMIN_PASS="packetlab-admin"

mkdir -p /run/slapd
chown openldap:openldap /run/slapd

slapd -d 0 -h "ldap://0.0.0.0:389/" -u openldap -g openldap &
SLAPD_PID=$!

trap 'kill "$SLAPD_PID" 2>/dev/null || true' INT TERM EXIT

for _ in $(seq 1 60); do
  if ldapsearch -x -H "$LDAP_URI" -b "$BASE_DN" -s base dn >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! ldapsearch -x -H "$LDAP_URI" -b "ou=People,$BASE_DN" -s base dn >/dev/null 2>&1; then
  ldapadd -x -H "$LDAP_URI" -D "$ADMIN_DN" -w "$ADMIN_PASS" -f /seed/packetlab.ldif
fi

wait "$SLAPD_PID"
