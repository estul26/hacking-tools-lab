# HTTPX Guide And Local Lab

This lab teaches ProjectDiscovery `httpx` with a Docker web target published to
`127.0.0.1`. You can practice HTTP probing, status-code review, title
extraction, redirect handling, server and technology fingerprinting, favicon
hashing, response timing, and JSONL reporting against a target you control.

ProjectDiscovery `httpx` is an HTTP toolkit for quickly probing web endpoints
and enriching URL lists with response metadata. This is different from the
Python `httpx` library; in this lab, `httpx` means the command-line recon tool.

## Safety Rules

- Probe only systems you own or have explicit permission to test.
- Keep probing scoped to approved hosts, ports, paths, and request rates.
- Use conservative rate limits until you understand target load.
- Do not treat fingerprints as proof; verify interesting results manually.
- Avoid sending headers, credentials, or payloads outside your written scope.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.50.200.10` | Runs `httpx`, `curl`, `jq`, and stores output. |
| `target` | `172.50.200.20` | HTTP target with predictable probe results. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18096` | `target:8080` | HTTPX practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/httpx/docker-compose.yml up --build -d
docker compose -f labs/httpx/docker-compose.yml ps
docker compose -f labs/httpx/docker-compose.yml exec scanner httpx -version
```

Open the target:

```bash
open http://127.0.0.1:18096
```

Clean up when finished:

```bash
docker compose -f labs/httpx/docker-compose.yml down
```

## Probe One Target

Run a simple probe:

```bash
docker compose -f labs/httpx/docker-compose.yml exec scanner \
  httpx -u http://172.50.200.20:8080 -duc -status-code -title -web-server -tech-detect
```

Expected output includes status `200`, title `HTTPX Local Lab`, the local server
banner, and technology hints from the response.

## Probe A URL List

Probe the lab URL list:

```bash
docker compose -f labs/httpx/docker-compose.yml exec scanner \
  httpx -list targets/urls.txt -duc -status-code -title -location \
  -content-length -response-time -silent
```

Expected statuses include `200`, `302`, `401`, `403`, and `404`.

## Follow Redirects

Compare redirect behavior:

```bash
docker compose -f labs/httpx/docker-compose.yml exec scanner \
  httpx -u http://172.50.200.20:8080/redirect -duc -status-code -location -silent

docker compose -f labs/httpx/docker-compose.yml exec scanner \
  httpx -u http://172.50.200.20:8080/redirect -duc -status-code -location \
  -follow-redirects -title -silent
```

The first command should show `/redirect` returning `302`; the second follows
the redirect to the login page.

## Save JSONL Output

Save machine-readable output:

```bash
docker compose -f labs/httpx/docker-compose.yml exec scanner \
  httpx -list targets/urls.txt -status-code -title -web-server \
  -tech-detect -location -content-length -response-time -favicon \
  -json -duc -silent -o outputs/probes.jsonl
```

Summarize it:

```bash
docker compose -f labs/httpx/docker-compose.yml exec scanner \
  jq -r '[.url, .status_code, .title, .webserver, .location] | @tsv' \
  outputs/probes.jsonl
```

## Header Review

Capture response headers from the protected admin endpoint:

```bash
docker compose -f labs/httpx/docker-compose.yml exec scanner \
  httpx -u http://172.50.200.20:8080/admin/ -duc -status-code -include-response-header \
  -json -silent -o outputs/admin-headers.jsonl
```

The expected header includes `WWW-Authenticate: Basic realm="httpx-lab-admin"`.

## Useful Options

| Option | Use |
| --- | --- |
| `-u URL` | Probe one URL. |
| `-list FILE` | Probe targets from a file. |
| `-status-code` | Show HTTP status code. |
| `-title` | Extract HTML title. |
| `-web-server` | Show server banner. |
| `-tech-detect` | Detect technologies from response signals. |
| `-location` | Show redirect location. |
| `-follow-redirects` | Follow redirects before reporting. |
| `-content-length` | Show response body length. |
| `-response-time` | Show request timing. |
| `-favicon` | Calculate favicon hash. |
| `-json` | Write JSONL output. |
| `-o FILE` | Save output to a file. |
| `-rl 20` | Limit requests per second. |
| `-duc` | Disable update checks during local practice. |
| `-silent` | Print only probe output. |

## Generate Practice Scans

Run a quick HTTPX sweep:

```bash
sh labs/httpx/make_scans.sh
```

This writes JSONL probes, redirect-follow output, admin-header output, a TSV
summary, version output, and an HTTP status check into `labs/httpx/outputs`.

## Practice Tasks

1. Probe one target and identify the title, server, and status code.
2. Probe `targets/urls.txt` and group results by status code.
3. Compare `/redirect` with and without `-follow-redirects`.
4. Inspect JSONL output with `jq`.
5. Capture headers from `/admin/` and find the Basic Auth realm.
6. Use `-favicon` and compare the favicon hash across paths.
7. Explain which `httpx` fields are fingerprints and which are direct evidence.

## Troubleshooting

If `httpx` cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/httpx/docker-compose.yml exec scanner \
  curl -sS http://172.50.200.20:8080/api/status | jq .
```

If Compose reports that port `18096` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18096:8080` to `127.0.0.1:28096:8080`.
