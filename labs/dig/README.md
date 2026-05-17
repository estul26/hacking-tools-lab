# Dig Guide And Local Lab

This lab teaches `dig` with a tiny authoritative DNS server published to
`127.0.0.1`. You can practice from your host and from a toolbox container. It is
designed for authorized local practice only.

`dig` is a DNS lookup tool from BIND. It is useful for inspecting record types,
querying a specific DNS server, checking reverse lookups, comparing UDP and TCP,
and reading DNS response flags and status codes.

## Safety Rules

- Query only DNS servers you own or have permission to test.
- Be careful with large query loops against real infrastructure.
- Use this lab before testing production DNS behavior.
- Remember that DNS answers may be cached outside this lab when you query real resolvers.

## Lab Topology

The Compose file creates a Docker lab network and publishes the DNS target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `target` | `172.36.70.20` | Authoritative DNS server for `dig.lab.test`. |
| `toolbox` | `172.36.70.10` | Includes `dig` from BIND tools. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:1053/udp` | `target:5353/udp` | Normal DNS queries. |
| `127.0.0.1:1053/tcp` | `target:5353/tcp` | DNS over TCP with `+tcp`. |

The ports are bound to `127.0.0.1`, not `0.0.0.0`, so they stay on your machine
and are not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/dig/docker-compose.yml up --build -d
docker compose -f labs/dig/docker-compose.yml ps
```

Clean up when finished:

```bash
docker compose -f labs/dig/docker-compose.yml down
```

## Zone Records

The lab serves `dig.lab.test` with these useful records:

| Name | Type | Purpose |
| --- | --- | --- |
| `dig.lab.test` | `A`, `NS`, `MX`, `SOA`, `TXT` | Zone apex records. |
| `www.dig.lab.test` | `A`, `TXT` | Web-style host. |
| `api.dig.lab.test` | `CNAME` | Alias to `www.dig.lab.test`. |
| `mail.dig.lab.test` | `A` | Mail host for the MX record. |
| `ns1.dig.lab.test` | `A` | Name server host. |
| `ipv6.dig.lab.test` | `AAAA` | IPv6 example. |
| `text.dig.lab.test` | `TXT` | TXT strings. |
| `_service._tcp.dig.lab.test` | `SRV` | Service discovery example. |
| `20.70.36.172.in-addr.arpa` | `PTR` | Reverse lookup for `172.36.70.20`. |
| `noanswer.dig.lab.test` | `TXT` only | Existing name with no `A` answer. |
| `servfail.dig.lab.test` | special | Returns `SERVFAIL`. |

## Basic Queries

Query the lab server directly:

```bash
dig @127.0.0.1 -p 1053 www.dig.lab.test A
```

Short output:

```bash
dig @127.0.0.1 -p 1053 www.dig.lab.test A +short
```

Query the zone apex:

```bash
dig @127.0.0.1 -p 1053 dig.lab.test SOA
dig @127.0.0.1 -p 1053 dig.lab.test NS
dig @127.0.0.1 -p 1053 dig.lab.test MX
```

## Common Record Types

```bash
dig @127.0.0.1 -p 1053 api.dig.lab.test A
dig @127.0.0.1 -p 1053 text.dig.lab.test TXT
dig @127.0.0.1 -p 1053 ipv6.dig.lab.test AAAA
dig @127.0.0.1 -p 1053 _service._tcp.dig.lab.test SRV
```

The `api` query shows a CNAME chain and its final `A` answer.

## Reverse Lookup

Use `-x` for PTR lookups:

```bash
dig @127.0.0.1 -p 1053 -x 172.36.70.20
dig @127.0.0.1 -p 1053 -x 172.36.70.20 +short
```

## UDP And TCP

DNS normally uses UDP:

```bash
dig @127.0.0.1 -p 1053 www.dig.lab.test A
```

Force TCP:

```bash
dig @127.0.0.1 -p 1053 +tcp www.dig.lab.test A
```

The lab supports both so you can compare response headers.

## Failure Cases

NXDOMAIN for a missing name:

```bash
dig @127.0.0.1 -p 1053 missing.dig.lab.test A
```

Existing name with no `A` record:

```bash
dig @127.0.0.1 -p 1053 noanswer.dig.lab.test A
dig @127.0.0.1 -p 1053 noanswer.dig.lab.test TXT
```

Server failure:

```bash
dig @127.0.0.1 -p 1053 servfail.dig.lab.test A
```

## Useful Flags

| Flag | Use |
| --- | --- |
| `+short` | Print only answer data. |
| `+noall +answer` | Hide everything except the answer section. |
| `+comments` | Show status and flags. |
| `+tcp` | Query over TCP instead of UDP. |
| `+time=1 +tries=1` | Make tests fail fast. |
| `-x IP` | Reverse lookup. |
| `@server` | Query a specific DNS server. |
| `-p port` | Query a non-standard DNS port. |

## Use The Toolbox

If your host does not have `dig`, use the toolbox:

```bash
docker compose -f labs/dig/docker-compose.yml exec toolbox \
  dig @target -p 5353 www.dig.lab.test A

docker compose -f labs/dig/docker-compose.yml exec toolbox \
  dig @target -p 5353 dig.lab.test MX +short

docker compose -f labs/dig/docker-compose.yml exec toolbox \
  dig @target -p 5353 +tcp www.dig.lab.test A +short
```

## Generate Practice Queries

Run a quick query sweep:

```bash
sh labs/dig/make_queries.sh
```

This writes sample outputs into `labs/dig/outputs`.

## Practice Tasks

1. Find the `A` record for `www.dig.lab.test`.
2. Resolve `api.dig.lab.test` and identify the CNAME target.
3. Find the mail exchanger for `dig.lab.test`.
4. Query the TXT records for `text.dig.lab.test`.
5. Run a reverse lookup for `172.36.70.20`.
6. Compare UDP and TCP output.
7. Compare NXDOMAIN with a name that exists but has no `A` answer.
8. Save query output with `sh labs/dig/make_queries.sh`.

## Troubleshooting

If Compose reports that port `1053` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:1053:5353/udp` to `127.0.0.1:11053:5353/udp` and make the same TCP
change.

If queries time out, confirm the target is running:

```bash
docker compose -f labs/dig/docker-compose.yml ps
```
