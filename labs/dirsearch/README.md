# Dirsearch Guide And Local Lab

This lab teaches `dirsearch` with a Docker web target published to
`127.0.0.1`. You can practice directory discovery, extension replacement,
recursive discovery, status filtering, authenticated requests, and saved
reports against a target you control.

Dirsearch is a Python web path scanner. It sends requests from a wordlist,
optionally expands file extensions, and reports interesting HTTP responses so
you can manually verify candidate content.

## Safety Rules

- Scan only web apps you own or have explicit permission to test.
- Use small wordlists, modest thread counts, and rate limits first.
- Do not run Dirsearch against production systems without a written scope.
- Treat findings as leads to verify manually, not proof of a vulnerability.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.44.140.10` | Runs `dirsearch`, `curl`, `jq`, and stores output. |
| `target` | `172.44.140.20` | HTTP target with predictable discoveries. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18090` | `target:8080` | Dirsearch practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/dirsearch/docker-compose.yml up --build -d
docker compose -f labs/dirsearch/docker-compose.yml ps
docker compose -f labs/dirsearch/docker-compose.yml exec scanner dirsearch --version
```

Open the target:

```bash
open http://127.0.0.1:18090
```

Clean up when finished:

```bash
docker compose -f labs/dirsearch/docker-compose.yml down
```

## Directory Discovery

Find interesting paths and keep only useful status codes:

```bash
docker compose -f labs/dirsearch/docker-compose.yml exec scanner \
  dirsearch -u http://target:8080 -w wordlists/paths.txt \
  -e txt,json,html,js,css -i 200,301,401,403 \
  --threads 5 --max-rate 20 --no-color --quiet-mode
```

Expected matches include `/admin`, `/backup`, `/dev`, `/debug`, `/portal`,
`/private`, `/status`, `/health`, `/login`, `/api/status`, `/api/users`,
`/docs`, `/files`, and `/assets`.

## Extension Replacement

Find files from wordlist entries that use `%EXT%`:

```bash
docker compose -f labs/dirsearch/docker-compose.yml exec scanner \
  dirsearch -u http://target:8080 -w wordlists/files.txt \
  -e txt,json,html,js,css -i 200 \
  --threads 5 --max-rate 20 --no-color --quiet-mode
```

Expected matches include `/files/config.txt`, `/files/config.json`,
`/files/report.html`, `/files/notes.txt`, `/assets/app.js`, and
`/assets/style.css`.

## Recursive Discovery

Recursively search discovered directories:

```bash
docker compose -f labs/dirsearch/docker-compose.yml exec scanner \
  dirsearch -u http://target:8080 -w wordlists/recursive.txt \
  -e txt,json,html,js,css -i 200,301,403 \
  -r -R 2 --recursion-status 200,301 \
  --threads 5 --max-rate 20 --no-color --quiet-mode
```

Expected recursive discoveries include `/api/`, `/api/users`, `/api/v1/`,
`/api/v1/status`, `/docs/`, `/docs/api`, and `/docs/reference`.

## Authenticated Requests

Use Basic Auth for protected admin paths:

```bash
docker compose -f labs/dirsearch/docker-compose.yml exec scanner \
  dirsearch -u http://target:8080 -w wordlists/admin.txt \
  -e txt,json,html --auth dirsearch:packetlab --auth-type basic \
  -i 200,403 --threads 5 --max-rate 20 --no-color --quiet-mode
```

Expected authenticated matches include `/admin`, `/admin/panel`,
`/admin/logs`, `/admin/users`, and `/admin/backup`.

## Save Reports

Save a plain report:

```bash
docker compose -f labs/dirsearch/docker-compose.yml exec scanner \
  dirsearch -u http://target:8080 -w wordlists/files.txt \
  -e txt,json,html,js,css -i 200 --format plain \
  -o outputs/files.txt --threads 5 --max-rate 20 --no-color --quiet-mode
```

Save JSON:

```bash
docker compose -f labs/dirsearch/docker-compose.yml exec scanner \
  dirsearch -u http://target:8080 -w wordlists/files.txt \
  -e txt,json,html,js,css -i 200 --format json \
  -o outputs/files.json --threads 5 --max-rate 20 --no-color --quiet-mode
```

## Useful Options

| Option | Use |
| --- | --- |
| `-u URL` | Target URL. |
| `-w FILE` | Wordlist path. |
| `-e txt,json` | Extension list used for `%EXT%` replacement. |
| `-i 200,403` | Include only these status codes. |
| `-x 404,500-599` | Exclude these status codes. |
| `-r` | Enable recursive scanning. |
| `-R 2` | Limit recursion depth. |
| `--recursion-status 200,301` | Recurse only on these statuses. |
| `--auth user:pass` | Send credentials. |
| `--auth-type basic` | Use Basic Auth. |
| `--threads 5` | Limit worker threads. |
| `--max-rate 20` | Limit requests per second. |
| `--format json` | Save in a structured report format. |
| `-o FILE` | Save output to a file. |

## Generate Practice Scans

Run a quick Dirsearch sweep:

```bash
sh labs/dirsearch/make_scans.sh
```

This writes plain reports, TSV summaries, JSON file-discovery output, and an
HTTP status check into `labs/dirsearch/outputs`.

## Practice Tasks

1. Find hidden content paths and compare `200`, `301`, `401`, and `403`.
2. Discover files that exist through `%EXT%` extension replacement.
3. Run a recursive scan and find nested `/api/v1/status`.
4. Compare unauthenticated `/admin` results with authenticated admin discovery.
5. Save the same scan as plain text and JSON.
6. Lower `--max-rate` to `5` and compare scan behavior.
7. Run `sh labs/dirsearch/make_scans.sh` and inspect the TSV summaries.

## Troubleshooting

If Dirsearch returns too much noise, tighten the status-code include list with
`-i`, use `-x` to exclude statuses, or use response-size filters.

If recursion misses nested paths, confirm the scan includes `-r`, a sufficient
`-R` depth, and a useful `--recursion-status` list.

If Compose reports that port `18090` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18090:8080` to `127.0.0.1:28090:8080`.
