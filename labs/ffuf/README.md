# FFUF Guide And Local Lab

This lab teaches `ffuf` with a Docker web target published to `127.0.0.1`.
You can practice content discovery, extension fuzzing, virtual-host fuzzing,
parameter fuzzing, and POST body fuzzing against a target you control.

`ffuf`, short for Fuzz Faster U Fool, is a web fuzzer. It sends many similar
HTTP requests while replacing a marker such as `FUZZ` with words from a
wordlist, then filters the responses by status, size, words, lines, or other
signals.

## Safety Rules

- Fuzz only web apps you own or have explicit permission to test.
- Use conservative thread and rate limits until you know the target can handle the traffic.
- Do not fuzz login forms, APIs, or production systems without a written scope.
- Treat discoveries as leads to verify manually, not proof of a vulnerability.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.42.120.10` | Runs `ffuf`, `curl`, `jq`, and stores fuzz output. |
| `target` | `172.42.120.20` | HTTP target with predictable fuzzing discoveries. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18088` | `target:8080` | FFUF practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/ffuf/docker-compose.yml up --build -d
docker compose -f labs/ffuf/docker-compose.yml ps
docker compose -f labs/ffuf/docker-compose.yml exec scanner ffuf -V
```

Open the target:

```bash
open http://127.0.0.1:18088
```

Clean up when finished:

```bash
docker compose -f labs/ffuf/docker-compose.yml down
```

## Content Discovery

Find interesting paths:

```bash
docker compose -f labs/ffuf/docker-compose.yml exec scanner \
  ffuf -w wordlists/paths.txt -u http://target:8080/FUZZ \
  -mc 200,401,403 -t 5 -rate 20
```

Expected matches include `/admin`, `/backup`, `/dev`, `/debug`, `/portal`,
`/private`, `/status`, `/health`, and `/login`.

## Extension Fuzzing

Find files by extension:

```bash
docker compose -f labs/ffuf/docker-compose.yml exec scanner \
  ffuf -w wordlists/extensions.txt -u http://target:8080/files/config.FUZZ \
  -mc 200 -t 5 -rate 20
```

Expected matches are `txt` and `json`.

## Virtual Host Fuzzing

Fuzz the `Host` header:

```bash
docker compose -f labs/ffuf/docker-compose.yml exec scanner \
  ffuf -w wordlists/vhosts.txt -u http://target:8080/ \
  -H "Host: FUZZ.ffuf.lab" -mc 200 -t 5 -rate 20
```

Expected matches are `admin`, `api`, and `dev`.

## Parameter Fuzzing

Find accepted query parameter names:

```bash
docker compose -f labs/ffuf/docker-compose.yml exec scanner \
  ffuf -w wordlists/params.txt -u "http://target:8080/search?FUZZ=packetlab" \
  -mc 200 -t 5 -rate 20
```

Expected matches are `q`, `query`, and `debug`.

## POST Body Fuzzing

Find the local training password for the `admin` user:

```bash
docker compose -f labs/ffuf/docker-compose.yml exec scanner \
  ffuf -w wordlists/passwords.txt -u http://target:8080/login \
  -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin&password=FUZZ" -mc 200 -t 5 -rate 20
```

The expected match is `packetlab`.

## Useful Options

| Option | Use |
| --- | --- |
| `-w FILE` | Wordlist path. |
| `-u URL` | Target URL containing `FUZZ`. |
| `-H HEADER` | Add or fuzz an HTTP header. |
| `-X METHOD` | Set the HTTP method. |
| `-d DATA` | Send a request body. |
| `-mc 200,403` | Match only these status codes. |
| `-fc 404` | Filter these status codes. |
| `-fs SIZE` | Filter response size. |
| `-t 5` | Limit worker threads. |
| `-rate 20` | Limit requests per second. |
| `-of json -o FILE` | Save JSON output. |

## Generate Practice Fuzzes

Run a quick fuzz sweep:

```bash
sh labs/ffuf/make_fuzz.sh
```

This writes JSON and TSV summaries for paths, extensions, virtual hosts,
parameters, and login fuzzing into `labs/ffuf/outputs`.

## Practice Tasks

1. Find the hidden content paths and compare status codes.
2. Discover which `config` extensions exist.
3. Find valid `*.ffuf.lab` virtual hosts with the `Host` header.
4. Discover accepted `/search` parameter names.
5. Fuzz the POST login password and verify the successful response manually.
6. Save JSON output with `-of json -o`.
7. Run `sh labs/ffuf/make_fuzz.sh` and inspect the TSV summaries.

## Troubleshooting

If ffuf returns too much noise, add filters such as `-fc 404`, `-fs SIZE`, or
use a tighter `-mc` status-code match.

If Compose reports that port `18088` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18088:8080` to `127.0.0.1:28088:8080`.
