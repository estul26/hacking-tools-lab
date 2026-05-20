# BloodHound.py Guide And Local Graph Fixture Lab

This lab teaches BloodHound.py workflow basics with the real
`bloodhound-python` CLI and a deterministic local graph fixture. You can
practice tool help, collection planning, scope checks, object review,
relationship review, and high-value object identification without touching a
real Active Directory environment.

BloodHound.py collects Active Directory data through LDAP, DNS, Kerberos, SMB,
and related services. A full AD domain controller is intentionally outside this
small Docker lab. The lab uses the real tool for help/version practice, then
uses a BloodHound-style local fixture to practice safe review habits.

## Safety Rules

- Run BloodHound.py only against domains you own or have explicit permission to assess.
- Keep domains, DNS servers, collection methods, credentials, and runtime inside scope.
- Do not collect from production Active Directory without written authorization.
- Treat collected directory data as sensitive, even when no passwords are collected.
- Store and share BloodHound output only where your authorization allows it.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes a tiny validation
API to localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.62.84.10` | Runs `bloodhound-python`, `curl`, `jq`, and stores output. |
| `target` | `172.62.84.20` | Serves local fixture objects for validation practice. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18109` | `target:8080` | Local object validation API. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml up --build -d
docker compose -f labs/bloodhound-python/docker-compose.yml ps
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  dpkg-query -W -f='${Version}\n' bloodhound.py
```

Open the validation target:

```bash
open http://127.0.0.1:18109/health
```

Clean up when finished:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml down
```

## Local Fixture

The fixture lives at `fixtures/packetlab-graph.json` and models a tiny
authorized domain named `PACKETLAB.LOCAL`.

It includes:

| Object type | Examples |
| --- | --- |
| Users | `ALICE@PACKETLAB.LOCAL`, `BOB@PACKETLAB.LOCAL`, `HELPDESK-SVC@PACKETLAB.LOCAL` |
| Groups | `HELPDESK@PACKETLAB.LOCAL`, `WORKSTATION ADMINS@PACKETLAB.LOCAL`, `DOMAIN ADMINS@PACKETLAB.LOCAL` |
| Computers | `WS1.PACKETLAB.LOCAL`, `DC1.PACKETLAB.LOCAL` |
| Edges | `MemberOf`, `AdminTo`, `CanRDP` |

## BloodHound.py Help

Show general help:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  bloodhound-python -h
```

Show package version information:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  dpkg-query -W -f='${Version}\n' bloodhound.py
```

For a real authorized AD environment, collection commands usually require a
domain, nameserver or domain controller, user credentials, and explicit
collection methods. Do not point this tool at networks outside your written
scope.

## Generate Practice Outputs

Run the local workflow:

```bash
sh labs/bloodhound-python/make_scans.sh
```

This writes help/version output, the copied graph fixture, user/group/computer
tables, relationship tables, high-value object lists, scope checks, validation
results, and a TSV summary into `labs/bloodhound-python/outputs`.

## Review The Graph

List users:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  jq -r '.users[] | [.name, .enabled] | @tsv' fixtures/packetlab-graph.json
```

List high-value groups:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  jq -r '.groups[] | select(.highvalue == true) | .name' fixtures/packetlab-graph.json
```

List useful relationship hints:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  jq -r '.edges[] | [.source, .relationship, .target] | @tsv' fixtures/packetlab-graph.json
```

Validate one object through the local API:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  curl -sS http://172.62.84.20:8080/objects/DC1.PACKETLAB.LOCAL | jq .
```

## Useful Options

| Option | Use |
| --- | --- |
| `-d DOMAIN` | Set the AD domain for a real authorized collection. |
| `-u USER` | Set the collection username. |
| `-p PASS` | Set the collection password. |
| `-ns IP` | Set the DNS nameserver. |
| `-dc HOST` | Set the domain controller hostname. |
| `-c METHOD` | Select collection methods. |
| `--zip` | Zip collection output for import. |
| `--dns-tcp` | Use TCP for DNS lookups. |
| `--auth-method` | Select authentication method supported by your environment. |

## Practice Tasks

1. Run `bloodhound-python -h` and identify required real-environment inputs.
2. Compare users, groups, and computers in the local fixture.
3. Identify which objects are marked high-value.
4. Trace `ALICE@PACKETLAB.LOCAL` through group membership to workstation admin rights.
5. Explain why `BOB@PACKETLAB.LOCAL` is more sensitive than `ALICE@PACKETLAB.LOCAL` in this fixture.
6. Inspect `outputs/out-of-scope-objects.txt` after running the helper.
7. Write a safe BloodHound.py collection plan for a domain you are authorized to assess.

## Troubleshooting

If the local workflow cannot validate objects, confirm the target is healthy:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  curl -sS http://172.62.84.20:8080/health | jq .
```

If help/version output is missing, confirm the package installed:

```bash
docker compose -f labs/bloodhound-python/docker-compose.yml exec scanner \
  command -v bloodhound-python
```

If Compose reports that port `18109` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18109:8080` to `127.0.0.1:28109:8080`.
