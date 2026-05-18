# Waybackurls Guide And Local Archive Workflow Lab

This lab teaches `waybackurls` with a local, repeatable workflow. You can
practice help output review, archive URL handling, host extraction, parameter
triage, scope filtering, and local validation against assets you control.

`waybackurls` reads domains from standard input, queries public archive sources,
and prints known URLs. Public archives will not know about Docker-only domains
such as `packetlab.local`, so this lab uses the real binary for command
discovery and a local waybackurls-shaped fixture for safe downstream practice.

## Safety Rules

- Query archived URLs only for domains you own or have explicit permission to assess.
- Keep domains, source data, filters, and validation requests inside scope.
- Treat archived URLs as historical leads; do not assume every path is still live.
- Review sensitive-looking paths before sharing reports or screenshots.
- Use bounded workflows when validating large archived URL sets.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the validation
target to localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.54.240.10` | Runs `waybackurls`, `curl`, `jq`, `python3`, and stores output. |
| `target` | `172.54.240.20` | Local HTTP validation target for archived URL practice. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18100` | `target:8080` | Local validation target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/waybackurls/docker-compose.yml up --build -d
docker compose -f labs/waybackurls/docker-compose.yml ps
docker compose -f labs/waybackurls/docker-compose.yml exec scanner waybackurls -h
```

Open the validation target:

```bash
open http://127.0.0.1:18100/health
```

Clean up when finished:

```bash
docker compose -f labs/waybackurls/docker-compose.yml down
```

## Local Archive Boundary

`packetlab.local` is intentionally not discoverable from public archive
sources. That is expected: the Internet Archive, Common Crawl, and similar
sources only contain data they observed publicly.

The helper script records this boundary in `outputs/local-archive-note.txt`.

## Work With Archived URLs

Use the local fixture to practice processing waybackurls-style output:

```bash
docker compose -f labs/waybackurls/docker-compose.yml exec scanner \
  sort -u fixtures/urls.txt
```

Extract hosts:

```bash
docker compose -f labs/waybackurls/docker-compose.yml exec scanner \
  python3 - <<'PY'
from urllib.parse import urlparse
for url in open("fixtures/urls.txt", encoding="utf-8"):
    print(urlparse(url.strip()).hostname)
PY
```

Filter hosts to the allowed scope:

```bash
docker compose -f labs/waybackurls/docker-compose.yml exec scanner \
  sh -c 'python3 -c "import sys; from urllib.parse import urlparse; [print(urlparse(line.strip()).hostname) for line in open(sys.argv[1], encoding=\"utf-8\") if line.strip()]" fixtures/urls.txt | sort -u | comm -12 scope/allow-hosts.txt -'
```

## Validate Locally

Manually validate one archived path against the local target:

```bash
docker compose -f labs/waybackurls/docker-compose.yml exec scanner \
  curl -i -H "Host: api.packetlab.local" \
  "http://172.54.240.20:8080/api/v1/users?id=1"
```

The expected response is JSON from the local API validation surface.

## Optional Real Archive Run

For a domain you own or have permission to assess, run:

```bash
docker compose -f labs/waybackurls/docker-compose.yml exec scanner \
  sh -c 'printf "%s\n" example-authorized-domain.com | waybackurls'
```

Replace the example domain with your authorized scope. Do not run this command
against random public domains.

## Useful Options

| Option | Use |
| --- | --- |
| `stdin` | Read line-delimited domains from standard input. |
| `-dates` | Include archive capture dates when supported. |
| `-no-subs` | Avoid fetching URLs for subdomains. |
| `-get-versions` | Fetch archived versions for input URLs. |
| `-h` | Show help and available arguments. |

## Generate Practice Outputs

Run a quick waybackurls workflow:

```bash
sh labs/waybackurls/make_scans.sh
```

This writes help output, a local archive note, unique URL lists, parsed URL
fields, host and parameter filters, local validation results, and a TSV summary
into `labs/waybackurls/outputs`.

## Practice Tasks

1. Review `waybackurls -h` and identify input and output options.
2. Explain why `packetlab.local` should not appear in public archives.
3. Deduplicate `fixtures/urls.txt` and count unique URLs.
4. Extract hosts, paths, and query strings from archived URLs.
5. Filter hosts to `scope/allow-hosts.txt`.
6. Validate `api.packetlab.local` and `admin.packetlab.local` paths with `curl`.
7. Write a safe command for a real domain you are authorized to assess.

## Troubleshooting

If validation cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/waybackurls/docker-compose.yml exec scanner \
  curl -sS http://172.54.240.20:8080/health | jq .
```

If a real archive run returns little or no data, check whether the domain has
public archived history and whether your network can reach the upstream archive
sources.

If Compose reports that port `18100` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18100:8080` to `127.0.0.1:28100:8080`.
