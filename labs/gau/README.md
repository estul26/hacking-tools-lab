# Gau Guide And Local URL Collection Workflow Lab

This lab teaches `gau` with a local, repeatable workflow. You can practice help
and version checks, URL collection output handling, host extraction, extension
filtering, parameter triage, scope filtering, and local validation against
assets you control.

`gau` reads domains from standard input or arguments, queries public URL
sources, and prints known URLs. Public sources will not know about Docker-only
domains such as `packetlab.local`, so this lab uses the real binary for command
discovery and a local gau-shaped fixture for safe downstream practice.

## Safety Rules

- Collect URLs only for domains you own or have explicit permission to assess.
- Keep domains, providers, filters, config files, and validation requests inside scope.
- Treat collected URLs as historical leads; do not assume every path is still live.
- Review sensitive-looking paths before sharing reports or screenshots.
- Use bounded validation when processing large URL sets.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the validation
target to localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.55.250.10` | Runs `gau`, `curl`, `jq`, `python3`, and stores output. |
| `target` | `172.55.250.20` | Local HTTP validation target for URL collection practice. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18101` | `target:8080` | Local validation target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/gau/docker-compose.yml up --build -d
docker compose -f labs/gau/docker-compose.yml ps
docker compose -f labs/gau/docker-compose.yml exec scanner gau --help
docker compose -f labs/gau/docker-compose.yml exec scanner gau --version
```

Open the validation target:

```bash
open http://127.0.0.1:18101/health
```

Clean up when finished:

```bash
docker compose -f labs/gau/docker-compose.yml down
```

## Local Collection Boundary

`packetlab.local` is intentionally not discoverable from public URL sources.
That is expected: Wayback, Common Crawl, OTX, URLScan, and similar providers
only contain data they observed publicly.

The helper script records this boundary in `outputs/local-archive-note.txt`.

## Work With Gau-Style URLs

Use the local fixture to practice processing gau-style output:

```bash
docker compose -f labs/gau/docker-compose.yml exec scanner \
  sort -u fixtures/urls.txt
```

Extract hosts:

```bash
docker compose -f labs/gau/docker-compose.yml exec scanner \
  python3 - <<'PY'
from urllib.parse import urlparse
for url in open("fixtures/urls.txt", encoding="utf-8"):
    print(urlparse(url.strip()).hostname)
PY
```

List URLs with query parameters:

```bash
docker compose -f labs/gau/docker-compose.yml exec scanner \
  sh -c 'python3 -c "import sys; from urllib.parse import urlparse; [print(line.strip()) for line in open(sys.argv[1], encoding=\"utf-8\") if urlparse(line.strip()).query]" fixtures/urls.txt | sort -u'
```

## Validate Locally

Manually validate one collected path against the local target:

```bash
docker compose -f labs/gau/docker-compose.yml exec scanner \
  curl -i -H "Host: api.packetlab.local" \
  "http://172.55.250.20:8080/v1/users?id=1"
```

The expected response is JSON from the local API validation surface.

## Optional Real URL Collection

For a domain you own or have permission to assess, run:

```bash
docker compose -f labs/gau/docker-compose.yml exec scanner \
  sh -c 'printf "%s\n" example-authorized-domain.com | gau --threads 5 --o outputs/authorized-urls.txt'
```

Replace the example domain with your authorized scope. Do not run this command
against random public domains.

## Useful Options

| Option | Use |
| --- | --- |
| `stdin` | Read line-delimited domains from standard input. |
| `--subs` | Include subdomains of the target domain. |
| `--threads 5` | Set worker count for requests. |
| `--providers wayback,commoncrawl,otx,urlscan` | Choose URL providers. |
| `--blacklist png,jpg,css` | Filter selected extensions. |
| `--fp` | Remove different URLs that share the same parameter names. |
| `--from YYYYMM` | Fetch URLs from a starting archive date. |
| `--to YYYYMM` | Fetch URLs up to an ending archive date. |
| `--o FILE` | Save output to a file. |
| `--json` | Emit JSON output when supported. |
| `--version` | Show version information. |
| `--help` | Show help and available arguments. |

## Generate Practice Outputs

Run a quick gau workflow:

```bash
sh labs/gau/make_scans.sh
```

This writes help and version output, a local archive note, unique URL lists,
parsed URL fields, host and extension filters, parameterized URL lists, local
validation results, and a TSV summary into `labs/gau/outputs`.

## Practice Tasks

1. Review `gau --help` and identify provider and filtering options.
2. Explain why `packetlab.local` should not appear in public URL providers.
3. Deduplicate `fixtures/urls.txt` and count unique URLs.
4. Extract hosts, paths, extensions, and query strings from collected URLs.
5. Filter hosts to `scope/allow-hosts.txt`.
6. Compare `outputs/urls.txt`, `outputs/parameterized-urls.txt`, and `outputs/validation.tsv`.
7. Write a safe command for a real domain you are authorized to assess.

## Troubleshooting

If validation cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/gau/docker-compose.yml exec scanner \
  curl -sS http://172.55.250.20:8080/health | jq .
```

If a real collection returns little or no data, check selected providers,
network access, date filters, and whether the domain has public URL history.

If Compose reports that port `18101` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18101:8080` to `127.0.0.1:28101:8080`.
