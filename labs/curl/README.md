# Curl Guide And Local Lab

This lab teaches `curl` with a Docker target published to `127.0.0.1`, so you
can practice HTTP requests from your host and from a toolbox container. It is
designed for authorized local practice only.

`curl` is a command-line client for transferring data with URLs. It is commonly
used to inspect HTTP services, send API requests, debug headers, follow
redirects, handle cookies, authenticate, upload data, download files, and test
timeouts.

## Safety Rules

- Send requests only to systems you own or have permission to test.
- Be careful with tokens, cookies, credentials, and request bodies in shell history.
- Use `-v` and `--trace` only when it is safe to record request and response details.
- Treat downloaded files as untrusted until you know where they came from.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `target` | `172.34.50.20` | HTTP target with endpoints for common curl workflows. |
| `toolbox` | `172.34.50.10` | Includes `curl` and `jq`. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18080` | `target:8080` | Curl practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/curl/docker-compose.yml up --build -d
docker compose -f labs/curl/docker-compose.yml ps
```

Open the target in a browser:

```bash
open http://127.0.0.1:18080
```

Clean up when finished:

```bash
docker compose -f labs/curl/docker-compose.yml down
```

## Basic Requests

Fetch the home page:

```bash
curl http://127.0.0.1:18080/
```

Show response headers and body:

```bash
curl -i http://127.0.0.1:18080/api/status
```

Show only response headers:

```bash
curl -I http://127.0.0.1:18080/api/status
```

Fail on HTTP errors, stay quiet except for errors, and print the body:

```bash
curl -fsS http://127.0.0.1:18080/health
```

## Headers And Query Strings

Send a custom header:

```bash
curl -s -H "X-Lab-Trace: demo" http://127.0.0.1:18080/api/headers | jq
```

Send query parameters:

```bash
curl -s "http://127.0.0.1:18080/api/query?tool=curl&mode=lab" | jq
```

Verbose mode shows connection details, request headers, and response headers:

```bash
curl -v http://127.0.0.1:18080/api/status
```

## POST Forms And JSON

Send form data:

```bash
curl -s -d "name=curl&feature=forms" \
  http://127.0.0.1:18080/forms | jq
```

Send JSON:

```bash
curl -s -H "Content-Type: application/json" \
  -d '{"tool":"curl","mode":"json"}' \
  http://127.0.0.1:18080/api/echo | jq
```

Upload raw data with `PUT`:

```bash
curl -s -X PUT --data-binary @README.md \
  http://127.0.0.1:18080/upload | jq
```

## Redirects

Show a redirect without following it:

```bash
curl -i http://127.0.0.1:18080/redirect
```

Follow redirects:

```bash
curl -L http://127.0.0.1:18080/redirect-chain/1
```

## Cookies

Save and send cookies:

```bash
curl -c labs/curl/outputs/cookies.txt \
  http://127.0.0.1:18080/cookies/set

curl -b labs/curl/outputs/cookies.txt \
  http://127.0.0.1:18080/cookies/check
```

## Authentication

The lab has a Basic auth endpoint. The credentials are `curl` / `packetlab`.

```bash
curl -i http://127.0.0.1:18080/auth/basic
curl -s -u curl:packetlab http://127.0.0.1:18080/auth/basic | jq
```

## Downloads And Ranges

Save a file:

```bash
curl -fsS http://127.0.0.1:18080/download/report.txt \
  -o labs/curl/outputs/report.txt
```

Use the server-provided filename:

```bash
cd labs/curl/outputs
curl -fsS -OJ http://127.0.0.1:18080/download/report.txt
cd -
```

Request only part of a file:

```bash
curl -i -r 0-24 http://127.0.0.1:18080/range/data.txt
```

## Timeouts And Status Codes

Practice timeouts:

```bash
curl --max-time 1 http://127.0.0.1:18080/slow?seconds=2
curl --max-time 3 http://127.0.0.1:18080/slow?seconds=2
```

Practice HTTP status handling:

```bash
curl -i http://127.0.0.1:18080/status/404
curl -fsS http://127.0.0.1:18080/status/500
```

## Use The Toolbox

If your host does not have `curl` or `jq`, use the toolbox:

```bash
docker compose -f labs/curl/docker-compose.yml exec toolbox \
  curl -s http://target:8080/api/status

docker compose -f labs/curl/docker-compose.yml exec toolbox \
  sh -lc "curl -s -H 'X-Lab-Trace: toolbox' http://target:8080/api/headers | jq"
```

## Generate Practice Requests

Run a quick host-side request sweep:

```bash
sh labs/curl/make_requests.sh
```

This touches health checks, headers, query strings, redirects, cookies, Basic
auth, JSON, forms, upload, ranges, and download output.

## Practice Tasks

1. Fetch `/api/status` with headers visible.
2. Send a custom `X-Lab-Trace` header and find it in `/api/headers`.
3. Send JSON to `/api/echo`.
4. Follow the redirect chain and compare it with the non-`-L` output.
5. Save a cookie, then send it to `/cookies/check`.
6. Authenticate to `/auth/basic`.
7. Download `report.txt` into `labs/curl/outputs/`.
8. Trigger a timeout, then fix it by increasing `--max-time`.

## Troubleshooting

If Compose reports that port `18080` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18080:8080` to `127.0.0.1:28080:8080`.

If `curl -fsS` returns no output, remember that `-f` makes curl fail on HTTP
errors and `-s` hides progress output. Remove `-s` or add `-i` while debugging.
