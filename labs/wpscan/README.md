# WPScan Guide And Local WordPress Lab

This lab teaches `wpscan` with a real Docker WordPress target published to
`127.0.0.1`. You can practice WordPress detection, version checks, plugin
enumeration, theme enumeration, user enumeration, and a tiny local password
audit against a site you control.

WPScan is a WordPress security scanner. It can identify WordPress metadata,
enumerate users and components, and, when configured with an API token, enrich
findings with vulnerability database data. This lab does not require an API
token. The helper updates WPScan's local scanner database before running scans;
the target itself stays the local Docker WordPress site.

## Safety Rules

- Scan only WordPress sites you own or have explicit permission to test.
- Keep scans scoped to approved hosts, ports, paths, and accounts.
- Do not run password audits against production systems without written scope.
- Use conservative thread counts and small wordlists until you understand load.
- Treat WPScan results as leads to verify manually.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes WordPress to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.48.180.10` | Runs `wpscan`, `curl`, `jq`, and stores output. |
| `wordpress` | `172.48.180.20` | Real WordPress target with a local plugin and theme. |
| `wpcli` | `172.48.180.30` | Bootstraps users, theme, plugin, and content. |
| `db` | `172.48.180.40` | MariaDB database for WordPress. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18094` | `wordpress:80` | WPScan practice WordPress site. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/wpscan/docker-compose.yml up --build -d
docker compose -f labs/wpscan/docker-compose.yml ps
docker compose -f labs/wpscan/docker-compose.yml exec scanner wpscan --version
docker compose -f labs/wpscan/docker-compose.yml exec scanner wpscan --update
```

Run the bootstrap and scan helper once to install WordPress content and create
predictable output:

```bash
sh labs/wpscan/make_scans.sh
```

Open the target:

```bash
open http://127.0.0.1:18094
```

Clean up containers when finished:

```bash
docker compose -f labs/wpscan/docker-compose.yml down
```

Remove the local WordPress database and files for a full reset:

```bash
docker compose -f labs/wpscan/docker-compose.yml down -v
```

## Basic Scan

Run a normal local scan:

```bash
docker compose -f labs/wpscan/docker-compose.yml exec scanner \
  wpscan --url http://wordpress --no-update --random-user-agent
```

Expected output includes WordPress detection, WordPress version metadata, the
active `packetlab` theme, and the local `local-lab-audit` plugin.

## Enumerate Components

Enumerate users, plugins, and themes:

```bash
docker compose -f labs/wpscan/docker-compose.yml exec scanner \
  wpscan --url http://wordpress --no-update --random-user-agent \
  --enumerate u,p,t --plugins-detection mixed
```

Expected users include `admin`, `author`, and `editor`. Expected components
include the `local-lab-audit` plugin and `packetlab` theme.

## Save JSON Output

Save a JSON report for later review:

```bash
docker compose -f labs/wpscan/docker-compose.yml exec scanner \
  wpscan --url http://wordpress --no-update --random-user-agent \
  --enumerate u,p,t --plugins-detection mixed \
  --format json --output outputs/enumeration.json
```

Summarize it with `jq`:

```bash
docker compose -f labs/wpscan/docker-compose.yml exec scanner \
  jq '.version.number, (.plugins | keys), (.themes | keys), (.users | keys)' \
  outputs/enumeration.json
```

## Local Password Audit

Use the tiny local wordlist against the local `admin` account:

```bash
docker compose -f labs/wpscan/docker-compose.yml exec scanner \
  wpscan --url http://wordpress --no-update --random-user-agent \
  --usernames admin --passwords wordlists/passwords.txt \
  --max-threads 2 --password-attack wp-login
```

The expected lab credential is `admin` / `packetlab`. Do not reuse this pattern
against systems outside your approved scope.

## Useful Options

| Option | Use |
| --- | --- |
| `--url URL` | Target WordPress URL. |
| `--no-update` | Skip update checks during local practice. |
| `--random-user-agent` | Randomize the scanner user agent. |
| `--enumerate u,p,t` | Enumerate users, plugins, and themes. |
| `--plugins-detection mixed` | Combine passive and aggressive plugin checks. |
| `--format json` | Save machine-readable output. |
| `--output FILE` | Write output to a file. |
| `--usernames admin` | Limit password audit to a known local user. |
| `--passwords FILE` | Password list for a local audit. |
| `--max-threads 2` | Keep request concurrency modest. |
| `--api-token TOKEN` | Optional WPScan vulnerability database token. |

## Generate Practice Scans

Run a quick WPScan sweep:

```bash
sh labs/wpscan/make_scans.sh
```

This bootstraps the local WordPress site if needed, updates WPScan's local
scanner database, then writes baseline JSON, enumeration JSON, password-audit
JSON, a TSV summary, update output, version output, REST API output, and the
login page into `labs/wpscan/outputs`.

## Practice Tasks

1. Detect the WordPress version and identify confidence signals.
2. Enumerate local users and compare REST API and author archive methods.
3. Enumerate the `local-lab-audit` plugin.
4. Enumerate the active `packetlab` theme.
5. Save and inspect JSON output with `jq`.
6. Run the local password audit and explain why it must stay scoped.
7. Reset the lab with `docker compose -f labs/wpscan/docker-compose.yml down -v`.

## Troubleshooting

If WPScan cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/wpscan/docker-compose.yml exec scanner \
  curl -sS http://wordpress/wp-json/ | jq .
```

If WordPress setup looks stale, reset the lab volumes:

```bash
docker compose -f labs/wpscan/docker-compose.yml down -v
docker compose -f labs/wpscan/docker-compose.yml up --build -d
sh labs/wpscan/make_scans.sh
```

If Compose reports that port `18094` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18094:80` to `127.0.0.1:28094:80`.
