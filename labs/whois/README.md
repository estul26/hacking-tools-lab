# Whois Guide And Local Lab

This lab teaches `whois` with a tiny WHOIS server published to `127.0.0.1`.
You can practice from your host and from a toolbox container. It is designed for
authorized local practice only.

WHOIS is a simple text protocol over TCP. A client connects to a WHOIS server,
sends one query line, and reads a text response. Real-world WHOIS data can be
split across registries, registrars, RIRs, and referral servers; this lab keeps
the data small and predictable.

## Safety Rules

- Query only WHOIS servers you own or have permission to test at scale.
- Do not scrape public WHOIS servers aggressively.
- Treat WHOIS data as a lead to verify, not guaranteed truth.
- Remember that real public WHOIS may redact contact data for privacy.

## Lab Topology

The Compose file creates a Docker lab network and publishes the WHOIS target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `target` | `172.37.80.20` | WHOIS server with local training records. |
| `toolbox` | `172.37.80.10` | Includes `whois` and `nc`. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:1043/tcp` | `target:43/tcp` | WHOIS queries. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/whois/docker-compose.yml up --build -d
docker compose -f labs/whois/docker-compose.yml ps
```

Clean up when finished:

```bash
docker compose -f labs/whois/docker-compose.yml down
```

## Lab Objects

The target server knows these objects:

| Query | Purpose |
| --- | --- |
| `example.test` | Domain-style record. |
| `packetlab.test` | Domain-style record with contact data. |
| `expired.test` | Domain with an expired/redemption-style status. |
| `172.37.80.20` | IP address WHOIS record. |
| `172.37.80.0/24` | Netblock WHOIS record. |
| `AS64512` | ASN WHOIS record. |
| `ABUSE-WHOIS-LAB` | Abuse contact handle. |
| `TECH-WHOIS-LAB` | Technical contact handle. |
| `registrar local` | Registrar-style record. |
| `help` | Local query help. |

## Basic Queries

WHOIS clients vary by operating system. The toolbox commands below are the
most reliable way to run the lab examples.

Query a domain:

```bash
docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 example.test
```

Query another domain:

```bash
docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 packetlab.test
```

Query an expired-style domain:

```bash
docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 expired.test
```

## IP, Netblock, And ASN

```bash
docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 172.37.80.20

docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 172.37.80.0/24

docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 AS64512
```

## Contacts And Registrar Records

```bash
docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 ABUSE-WHOIS-LAB

docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 TECH-WHOIS-LAB

docker compose -f labs/whois/docker-compose.yml exec toolbox \
  whois -h target -p 43 "registrar local"
```

## Raw WHOIS With Netcat

WHOIS is simple enough to query manually:

```bash
printf 'example.test\r\n' | nc -w 2 127.0.0.1 1043
```

Try a no-match query:

```bash
printf 'missing.test\r\n' | nc -w 2 127.0.0.1 1043
```

## Use The Toolbox

If your host WHOIS client supports custom host and port flags, you can also
query the localhost-published service directly:

```bash
whois -h 127.0.0.1 -p 1043 example.test
USE_HOST_WHOIS=1 sh labs/whois/make_queries.sh
```

If that fails, use the toolbox examples above or raw `nc`.

## Generate Practice Queries

Run a quick query sweep:

```bash
sh labs/whois/make_queries.sh
```

This writes sample outputs into `labs/whois/outputs`.

## How To Read WHOIS

Useful fields to notice:

| Field | Meaning |
| --- | --- |
| `Domain Name` | The queried domain object. |
| `Registrar` | Registrar responsible for a domain registration. |
| `Creation Date` | When the record was created. |
| `Registry Expiry Date` | Expiration date for a domain registration. |
| `Domain Status` | EPP-style domain state. |
| `Name Server` | Authoritative nameservers listed for a domain. |
| `NetRange` / `CIDR` | IP allocation range. |
| `ASNumber` / `ASName` | Autonomous system number data. |
| `Handle` | Contact or object identifier. |

## Practice Tasks

1. Query `example.test` and find its nameservers.
2. Query `packetlab.test` and find the registrant email.
3. Compare `example.test` and `expired.test` statuses.
4. Query `172.37.80.20` and identify its netblock.
5. Query `AS64512` and identify the organization.
6. Use `nc` to make a raw WHOIS request.
7. Run `sh labs/whois/make_queries.sh` and inspect the saved outputs.

## Troubleshooting

If Compose reports that port `1043` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:1043:43` to `127.0.0.1:11043:43`.

If your host `whois` does not support `-p`, use the toolbox or raw `nc`.
