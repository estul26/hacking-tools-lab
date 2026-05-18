# theHarvester Guide And Local OSINT Workflow Lab

This lab teaches `theHarvester` with a local, repeatable workflow. You can
practice help output review, OSINT output handling, host and email extraction,
scope filtering, and local validation against assets you control.

`theHarvester` gathers emails, hosts, IPs, and related metadata from public
sources. Those public sources will not know about Docker-only domains such as
`packetlab.local`, and some sources need API keys or browser dependencies. This
lab uses the real tool for command discovery and version checks, plus a local
theHarvester-shaped fixture for safe downstream practice.

## Safety Rules

- Run OSINT collection only for domains and organizations you own or have explicit permission to assess.
- Keep domains, sources, API keys, proxies, and output files inside scope.
- Do not collect or publish personal data unless your authorization explicitly covers it.
- Treat OSINT results as leads; validate ownership and exposure separately.
- Review source terms and rate limits before using public engines.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the validation
target to localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.53.230.10` | Runs `theHarvester`, `curl`, `jq`, and stores output. |
| `target` | `172.53.230.20` | Local HTTP validation target for fixture hosts and contacts. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18099` | `target:8080` | Local validation target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/theharvester/docker-compose.yml up --build -d
docker compose -f labs/theharvester/docker-compose.yml ps
docker compose -f labs/theharvester/docker-compose.yml exec scanner theHarvester -h
```

Open the validation target:

```bash
open http://127.0.0.1:18099/health
```

Clean up when finished:

```bash
docker compose -f labs/theharvester/docker-compose.yml down
```

## Local OSINT Boundary

`packetlab.local` is intentionally not discoverable from public OSINT sources.
That is a lesson, not a bug: public search and breach sources only know about
data they have observed outside your Docker lab.

The helper script records this boundary in `outputs/local-osint-note.txt`.

## Work With theHarvester-Style JSON

Use the local fixture to practice parsing host and email findings:

```bash
docker compose -f labs/theharvester/docker-compose.yml exec scanner \
  jq -r '.hosts[]' fixtures/results.json | sort -u
```

Extract discovered emails:

```bash
docker compose -f labs/theharvester/docker-compose.yml exec scanner \
  jq -r '.emails[]' fixtures/results.json | sort -u
```

Filter hosts to the allowed scope:

```bash
docker compose -f labs/theharvester/docker-compose.yml exec scanner \
  sh -c 'sort -u scope/allow-hosts.txt >/tmp/allow && jq -r ".hosts[]" fixtures/results.json | sort -u | comm -12 /tmp/allow -'
```

## Validate Locally

Manually validate one discovered hostname against the local target:

```bash
docker compose -f labs/theharvester/docker-compose.yml exec scanner \
  curl -i -H "Host: api.packetlab.local" http://172.53.230.20:8080/
```

The expected response is JSON from the local API validation surface.

## Optional Real OSINT Run

For a domain you own or have permission to assess, choose appropriate sources
and run a bounded query:

```bash
docker compose -f labs/theharvester/docker-compose.yml exec scanner \
  theHarvester -d example-authorized-domain.com -b anubis,crtsh -l 100
```

Replace the example domain with your authorized scope. Do not run this command
against random public domains.

## Useful Options

| Option | Use |
| --- | --- |
| `-d DOMAIN` | Domain to search. |
| `-b SOURCE` | Data source or comma-separated source list. |
| `-l 100` | Limit the number of results. |
| `-S 0` | Start at a result offset. |
| `-f FILE` | Save output using the tool's export formats when supported. |
| `-c` | Perform DNS brute force when configured for an authorized target. |
| `-r` | Perform DNS resolution on discovered subdomains. |
| `-n` | Enable DNS server lookup. |
| `-s` | Query Shodan for discovered hosts when authorized and configured. |
| `-e DNS_SERVER` | Choose the DNS server used for lookup. |
| `-p` | Use proxies when configured. |
| `-h` | Show help and available arguments. |

## Generate Practice Outputs

Run a quick theHarvester workflow:

```bash
sh labs/theharvester/make_scans.sh
```

This writes help output, extracted version text, a local OSINT note, fixture
JSON, filtered host and email lists, local validation results, and a TSV
summary into `labs/theharvester/outputs`.

## Practice Tasks

1. Review `theHarvester -h` and identify source-selection options.
2. Explain why `packetlab.local` should not appear in public OSINT sources.
3. Extract hosts and emails from `fixtures/results.json` with `jq`.
4. Filter hosts and emails to the allowed scope files.
5. Validate `api.packetlab.local` and `admin.packetlab.local` with `curl`.
6. Compare `outputs/hosts.txt`, `outputs/emails.txt`, and `outputs/validation.tsv`.
7. Write a safe command for a real domain you are authorized to assess.

## Troubleshooting

If validation cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/theharvester/docker-compose.yml exec scanner \
  curl -sS http://172.53.230.20:8080/health | jq .
```

If a real OSINT run returns little or no data, check your selected sources, API
keys, source availability, and whether the domain has public data.

If Compose reports that port `18099` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18099:8080` to `127.0.0.1:28099:8080`.
