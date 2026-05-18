# Feroxbuster Guide And Local Lab

This lab teaches `feroxbuster` with a Docker web target published to
`127.0.0.1`. You can practice content discovery, extension probing, recursive
scanning, status filtering, authenticated requests, link extraction, and JSON
output against a target you control.

Feroxbuster is a fast recursive web content discovery tool. It sends requests
from a wordlist, can recurse into discovered directories, can add extensions,
and can extract links from HTML and JavaScript responses.

## Safety Rules

- Scan only web apps you own or have explicit permission to test.
- Start with small wordlists, modest thread counts, and explicit rate limits.
- Do not run Feroxbuster against production systems without a written scope.
- Treat findings as leads to verify manually, not proof of a vulnerability.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.45.150.10` | Runs `feroxbuster`, `curl`, `jq`, and stores output. |
| `target` | `172.45.150.20` | HTTP target with predictable discoveries. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18091` | `target:8080` | Feroxbuster practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml up --build -d
docker compose -f labs/feroxbuster/docker-compose.yml ps
docker compose -f labs/feroxbuster/docker-compose.yml exec scanner feroxbuster --version
```

Open the target:

```bash
open http://127.0.0.1:18091
```

Clean up when finished:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml down
```

## Content Discovery

Find interesting paths without recursion:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml exec scanner \
  feroxbuster -u http://target:8080 -w wordlists/paths.txt \
  --status-codes 200 301 401 403 --threads 5 --rate-limit 20 \
  --no-recursion --dont-extract-links --dont-filter --quiet --no-state
```

Expected matches include `/admin`, `/backup`, `/dev`, `/debug`, `/portal`,
`/private`, `/status`, `/health`, `/login`, `/api/status`, `/api/users`,
`/docs`, `/files`, `/assets`, and `/reports`.

## Extension Probing

Add extensions to file candidates:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml exec scanner \
  feroxbuster -u http://target:8080 -w wordlists/files.txt \
  -x txt json html js css --status-codes 200 \
  --threads 5 --rate-limit 20 --no-recursion --dont-extract-links \
  --dont-filter --quiet --no-state
```

Expected matches include `/files/config.txt`, `/files/config.json`,
`/files/report.html`, `/files/notes.txt`, `/assets/app.js`,
`/assets/style.css`, and `/reports/daily.json`.

## Recursive Discovery

Let Feroxbuster recurse into discovered directories:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml exec scanner \
  feroxbuster -u http://target:8080 -w wordlists/recursive.txt \
  --status-codes 200 301 403 --depth 2 \
  --threads 5 --rate-limit 20 --dont-filter --quiet --no-state
```

Expected recursive discoveries include `/api/`, `/api/users`, `/api/v1/`,
`/api/v1/status`, `/docs/`, `/docs/guide`, `/docs/reference`,
`/reports/`, and `/reports/daily.json`.

## Authenticated Requests

Use an Authorization header for protected admin paths:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml exec scanner \
  feroxbuster -u http://target:8080 -w wordlists/admin.txt \
  -H "Authorization: Basic ZmVyb3g6cGFja2V0bGFi" \
  --status-codes 200 403 --threads 5 --rate-limit 20 \
  --no-recursion --dont-extract-links --dont-filter --quiet --no-state
```

The Basic Auth credentials are `ferox` / `packetlab`. Expected authenticated
matches include `/admin`, `/admin/panel`, `/admin/logs`, `/admin/users`,
`/admin/tokens`, and `/admin/backup`.

## Link Extraction

Feroxbuster extracts links from response bodies by default. The lab home page
and `/portal` page include links that can lead to nested docs and reports. Add
`--dont-extract-links` when you want strict wordlist-only behavior.

## Save Output

Save a text report:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml exec scanner \
  feroxbuster -u http://target:8080 -w wordlists/files.txt \
  -x txt json html js css --status-codes 200 \
  --threads 5 --rate-limit 20 --no-recursion --dont-extract-links \
  --dont-filter --quiet --no-state -o outputs/extensions.txt
```

Save JSON:

```bash
docker compose -f labs/feroxbuster/docker-compose.yml exec scanner \
  feroxbuster -u http://target:8080 -w wordlists/files.txt \
  -x txt json html js css --status-codes 200 \
  --threads 5 --rate-limit 20 --no-recursion --dont-extract-links \
  --dont-filter --quiet --no-state --json -o outputs/extensions.json
```

## Useful Options

| Option | Use |
| --- | --- |
| `-u URL` | Target URL. |
| `-w FILE` | Wordlist path. |
| `-x txt json` | Add extensions to candidate paths. |
| `--status-codes 200 403` | Include only these status codes. |
| `-C 404` | Filter out these status codes. |
| `--no-recursion` | Disable recursive scanning. |
| `--depth 2` | Limit recursion depth. |
| `--dont-extract-links` | Disable link extraction from responses. |
| `--dont-filter` | Disable automatic wildcard-like response filtering. |
| `-H "Name: Value"` | Send a custom header. |
| `--threads 5` | Limit worker threads. |
| `--rate-limit 20` | Limit requests per second per directory. |
| `--json` | Write JSON entries to the output file. |
| `-o FILE` | Save output to a file. |
| `--no-state` | Disable state-file output. |

## Generate Practice Scans

Run a quick Feroxbuster sweep:

```bash
sh labs/feroxbuster/make_scans.sh
```

This writes text reports, TSV summaries, JSON extension output, and an HTTP
status check into `labs/feroxbuster/outputs`.

## Practice Tasks

1. Find hidden content paths and compare `200`, `301`, `401`, and `403`.
2. Discover files by adding `txt`, `json`, `html`, `js`, and `css` extensions.
3. Run a recursive scan and find nested `/api/v1/status`.
4. Compare link extraction with `--dont-extract-links`.
5. Compare unauthenticated `/admin` discovery with the authenticated scan.
6. Save the same scan as text and JSON.
7. Run `sh labs/feroxbuster/make_scans.sh` and inspect the TSV summaries.

## Troubleshooting

If Feroxbuster returns too much noise, tighten `--status-codes`, add filters
such as `-C`, `--filter-size`, or disable link extraction with
`--dont-extract-links`.

If recursion misses nested paths, confirm the scan does not include
`--no-recursion`, increase `--depth`, and make sure the wordlist contains
directory names.

If Compose reports that port `18091` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18091:8080` to `127.0.0.1:28091:8080`.
