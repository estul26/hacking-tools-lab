# Subfinder Guide And Local Workflow Lab

This lab teaches ProjectDiscovery `subfinder` with a local, repeatable workflow.
You can practice source listing, passive-output handling, JSONL parsing, scope
filtering, and local validation against hostnames you control.

Subfinder is a passive subdomain discovery tool. It asks online data sources
about real public domains; it does not brute-force local DNS and it cannot make
internet sources know about Docker-only domains. For that reason, this lab uses
real `subfinder` for version and source workflow, plus a local subfinder-shaped
fixture to practice the downstream handling safely and repeatably.

## Safety Rules

- Enumerate only domains you own or have explicit permission to test.
- Keep domains, sources, resolver choices, and output handling inside scope.
- Do not assume passive results are live assets; validate them separately.
- Review API-key-backed sources before use because they may reveal account data.
- Use rate limits and max-time limits until you understand source behavior.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the validation
target to localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.51.210.10` | Runs `subfinder`, `curl`, `jq`, and stores output. |
| `target` | `172.51.210.20` | Local HTTP validation target for fixture subdomains. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18097` | `target:8080` | Local validation target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/subfinder/docker-compose.yml up --build -d
docker compose -f labs/subfinder/docker-compose.yml ps
docker compose -f labs/subfinder/docker-compose.yml exec scanner subfinder -version -duc
```

Open the validation target:

```bash
open http://127.0.0.1:18097/health
```

Clean up when finished:

```bash
docker compose -f labs/subfinder/docker-compose.yml down
```

## List Sources

Subfinder can show the passive sources compiled into the tool:

```bash
docker compose -f labs/subfinder/docker-compose.yml exec scanner \
  subfinder -ls -duc -nc
```

Sources marked with `*` require API keys. Sources marked with `~` can work
without keys but may return better results when configured.

## Passive Enumeration Boundary

This local domain is intentionally not discoverable from passive internet
sources:

```bash
docker compose -f labs/subfinder/docker-compose.yml exec scanner \
  sh -c 'timeout 10s subfinder -dL scope/domains.txt -duc -silent -max-time 1 || true'
```

Empty output is expected for `packetlab.local`. That is a lesson, not a bug:
passive sources only know what they have observed publicly.

## Work With Subfinder JSONL

Use the local fixture to practice processing subfinder-style output:

```bash
docker compose -f labs/subfinder/docker-compose.yml exec scanner \
  jq -r '.host' fixtures/passive-results.jsonl | sort -u
```

Filter to the allowed scope:

```bash
docker compose -f labs/subfinder/docker-compose.yml exec scanner \
  sh -c 'sort -u scope/allow-subdomains.txt >/tmp/allow && jq -r ".host" fixtures/passive-results.jsonl | sort -u | comm -12 /tmp/allow -'
```

## Validate Locally

Manually validate one discovered hostname against the local target:

```bash
docker compose -f labs/subfinder/docker-compose.yml exec scanner \
  curl -i -H "Host: api.packetlab.local" http://172.51.210.20:8080/
```

The expected response is JSON from the local API validation surface.

## Optional Real Passive Run

For a domain you own or have permission to test, run:

```bash
docker compose -f labs/subfinder/docker-compose.yml exec scanner \
  subfinder -d example-authorized-domain.com -duc -silent -oJ \
  -o outputs/authorized-domain.jsonl
```

Replace the example domain with your authorized scope. Do not use this command
against random public domains.

## Useful Options

| Option | Use |
| --- | --- |
| `-d DOMAIN` | Enumerate one domain. |
| `-dL FILE` | Read domains from a file. |
| `-s crtsh,anubis` | Use specific sources. |
| `-all` | Use all sources, including slower ones. |
| `-recursive` | Use sources that can recursively enumerate subdomains. |
| `-m FILE` | Match only subdomains in a list. |
| `-f FILE` | Filter out subdomains in a list. |
| `-rl 5` | Limit global request rate. |
| `-max-time 2` | Limit enumeration runtime in minutes. |
| `-oJ` | Write JSONL output. |
| `-cs` | Include source names in JSONL output. |
| `-nW` | Show only active subdomains after resolving. |
| `-duc` | Disable update checks during local practice. |
| `-ls` | List available passive sources. |

## Generate Practice Outputs

Run a quick Subfinder workflow:

```bash
sh labs/subfinder/make_scans.sh
```

This writes version output, source listing, an expected empty passive local run,
a fixture JSONL file, filtered subdomain lists, local validation results, and a
TSV summary into `labs/subfinder/outputs`.

## Practice Tasks

1. List sources and identify which require API keys.
2. Run the local passive command and explain why it returns no names.
3. Extract hosts from `fixtures/passive-results.jsonl` with `jq`.
4. Filter fixture results to `scope/allow-subdomains.txt`.
5. Validate `api.packetlab.local` and `admin.packetlab.local` with `curl`.
6. Compare `outputs/subdomains.txt`, `outputs/in-scope.txt`, and `outputs/validation.tsv`.
7. Write a safe command for a real domain you are authorized to assess.

## Troubleshooting

If validation cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/subfinder/docker-compose.yml exec scanner \
  curl -sS http://172.51.210.20:8080/health | jq .
```

If a real passive run returns little or no data, check your selected sources,
API keys, rate limits, and whether the domain has public passive data.

If Compose reports that port `18097` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18097:8080` to `127.0.0.1:28097:8080`.
