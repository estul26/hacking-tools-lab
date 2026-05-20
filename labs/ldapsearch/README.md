# Ldapsearch Guide And Local OpenLDAP Lab

This lab teaches `ldapsearch` against a deliberately small local OpenLDAP
directory. You can practice anonymous searches, base-scope queries,
authenticated binds, filters, attribute selection, LDIF review, and TSV
summaries without touching a real directory service.

LDAP directories often contain sensitive identity, group, email, and asset
data. This lab keeps the target on a private Docker network and uses toy
entries under `dc=packetlab,dc=local`.

## Safety Rules

- Query LDAP only on systems you own or have explicit permission to assess.
- Keep base DNs, filters, attributes, credentials, and query volume inside scope.
- Do not dump production directories without written authorization.
- Treat directory data as sensitive, even when it does not include passwords.
- Avoid broad subtree searches until you understand directory size and impact.
- Keep this lab on the private Docker network unless your authorization covers another target.

## Lab Topology

The Compose file creates a private Docker bridge network. No LDAP port is
published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.63.85.10` | Runs `ldapsearch`, `nc`, `jq`, and stores output. |
| `target` | `172.63.85.20` | Runs OpenLDAP with toy Packetlab entries. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated LDIF, TSV, validation, help, and version files. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml up --build -d
docker compose -f labs/ldapsearch/docker-compose.yml ps
docker compose -f labs/ldapsearch/docker-compose.yml exec scanner ldapsearch -VV
```

Clean up when finished:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml down
```

## Local Directory

The target uses this base DN:

```text
dc=packetlab,dc=local
```

The lab admin bind is:

```text
cn=admin,dc=packetlab,dc=local
packetlab-admin
```

Toy entries include:

| Type | Entries |
| --- | --- |
| People | `alice`, `bob`, `svc-backup` |
| Groups | `helpdesk`, `engineering` |
| Units | `ou=People`, `ou=Groups` |

## Basic Searches

Read the Root DSE naming context:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml exec scanner \
  ldapsearch -x -H ldap://172.63.85.20:389 -s base -b "" namingContexts
```

Search people and select a few attributes:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml exec scanner \
  ldapsearch -x -H ldap://172.63.85.20:389 \
  -b ou=People,dc=packetlab,dc=local \
  "(objectClass=inetOrgPerson)" uid cn mail
```

Search groups:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml exec scanner \
  ldapsearch -x -H ldap://172.63.85.20:389 \
  -b ou=Groups,dc=packetlab,dc=local \
  "(objectClass=groupOfNames)" cn member
```

Run an authenticated search for service-style users:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml exec scanner \
  ldapsearch -x -H ldap://172.63.85.20:389 \
  -D cn=admin,dc=packetlab,dc=local -w packetlab-admin \
  -b dc=packetlab,dc=local "(uid=svc-*)" dn uid description
```

## Useful Options

| Option | Use |
| --- | --- |
| `-x` | Use simple authentication. |
| `-H URI` | Set the LDAP URI. |
| `-b BASE` | Set the search base DN. |
| `-s base` | Search only the base object. |
| `-s one` | Search one level under the base. |
| `-s sub` | Search the full subtree. |
| `-D DN` | Bind as a specific DN. |
| `-w PASS` | Provide the bind password. |
| `-LLL` | Print compact LDIF without comments/version. |
| `(uid=alice)` | Example LDAP filter. |

## Generate Practice Outputs

Run a quick ldapsearch workflow:

```bash
sh labs/ldapsearch/make_scans.sh
```

This writes version/help output, Root DSE output, base DN output, people and
group searches, authenticated filter results, a rejected bad bind, validation
results, and a TSV summary into `labs/ldapsearch/outputs`.

## Practice Tasks

1. Read the Root DSE and identify `namingContexts`.
2. Search only the base DN with `-s base`.
3. Compare `ou=People` and `ou=Groups` searches.
4. Filter for `uid=svc-*` with the lab admin bind.
5. Use `-LLL` and compare the compact LDIF output.
6. Inspect `outputs/people.tsv` and `outputs/groups.tsv`.
7. Write a safe ldapsearch command for a directory you are authorized to query.

## Troubleshooting

If ldapsearch cannot connect, confirm the LDAP port is reachable from the
scanner:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml exec scanner nc -z 172.63.85.20 389
```

If searches return no entries, check the target logs:

```bash
docker compose -f labs/ldapsearch/docker-compose.yml logs target
```

If bind tests fail unexpectedly, confirm the lab credentials in this README
match `start-target.sh`.
