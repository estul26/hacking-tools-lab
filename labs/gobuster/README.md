# Gobuster Guide And Local Lab

This lab teaches `gobuster` with a Docker web target and DNS responder
published to `127.0.0.1`. You can practice directory discovery, extension
probing, virtual-host discovery, DNS subdomain discovery, and fuzz mode against
targets you control.

Gobuster is a fast enumeration tool for web content, virtual hosts, DNS
subdomains, object buckets, and generic request fuzzing. It is useful for
finding candidate paths and names, but every finding still needs manual
validation.

## Safety Rules

- Enumerate only systems and domains you own or have explicit permission to test.
- Use small wordlists and modest thread counts until you understand the target.
- Do not run Gobuster against production systems without a written scope.
- Treat Gobuster output as discovery leads, not proof of a vulnerability.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.43.130.10` | Runs `gobuster`, `curl`, `dig`, `jq`, and stores output. |
| `target` | `172.43.130.20` | HTTP and DNS target with predictable discoveries. |

Host-reachable endpoints:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18089` | `target:8080` | Gobuster practice HTTP target. |
| `127.0.0.1:15354/udp` | `target:53/udp` | Gobuster practice DNS target. |

The ports are bound to `127.0.0.1`, not `0.0.0.0`, so they stay on your
machine and are not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/gobuster/docker-compose.yml up --build -d
docker compose -f labs/gobuster/docker-compose.yml ps
docker compose -f labs/gobuster/docker-compose.yml exec scanner gobuster version
```

Open the target:

```bash
open http://127.0.0.1:18089
```

Clean up when finished:

```bash
docker compose -f labs/gobuster/docker-compose.yml down
```

## Directory Discovery

Find interesting paths:

```bash
docker compose -f labs/gobuster/docker-compose.yml exec scanner \
  gobuster dir -u http://target:8080 -w wordlists/paths.txt \
  -t 5 -z --no-error --no-color
```

Expected matches include `/admin`, `/backup`, `/dev`, `/debug`, `/portal`,
`/private`, `/status`, `/health`, `/login`, and `/api/status`.

## Extension Probing

Find files under `/files` by adding extensions:

```bash
docker compose -f labs/gobuster/docker-compose.yml exec scanner \
  gobuster dir -u http://target:8080/files -w wordlists/files.txt \
  -x txt,json,html -t 5 -z --no-error --no-color
```

Expected matches include `config.txt`, `config.json`, `report.html`, and
`notes.txt`.

## Virtual Host Discovery

Fuzz the `Host` header:

```bash
docker compose -f labs/gobuster/docker-compose.yml exec scanner \
  gobuster vhost -u http://target:8080 -w wordlists/vhosts.txt \
  --append-domain --domain gobuster.lab -t 5 -z --no-error --no-color
```

Expected matches are `admin.gobuster.lab`, `api.gobuster.lab`,
`dev.gobuster.lab`, and `staging.gobuster.lab`.

## DNS Subdomain Discovery

Ask the local DNS responder for subdomains:

```bash
docker compose -f labs/gobuster/docker-compose.yml exec scanner \
  gobuster dns -d gobuster.lab -w wordlists/subdomains.txt \
  -r 172.43.130.20 -i -t 5 -z --no-error --no-color
```

Expected matches are `admin.gobuster.lab`, `api.gobuster.lab`,
`dev.gobuster.lab`, and `staging.gobuster.lab`, all resolving to
`172.43.130.20`.

## Fuzz Mode

Find accepted query parameter names:

```bash
docker compose -f labs/gobuster/docker-compose.yml exec scanner \
  gobuster fuzz -u "http://target:8080/search?FUZZ=packetlab" \
  -w wordlists/params.txt -b 400,404 -t 5 -z --no-error --no-color
```

Expected matches are `q`, `query`, and `debug`.

Find the local training token:

```bash
docker compose -f labs/gobuster/docker-compose.yml exec scanner \
  gobuster fuzz -u http://target:8080/tokens/FUZZ \
  -w wordlists/passwords.txt -b 404 -t 5 -z --no-error --no-color
```

The expected match is `packetlab`.

## Useful Options

| Option | Use |
| --- | --- |
| `dir` | Directory and file discovery mode. |
| `dns` | DNS subdomain discovery mode. |
| `vhost` | Virtual-host discovery mode. |
| `fuzz` | Replace `FUZZ` in a URL, header, or body. |
| `-w FILE` | Wordlist path. |
| `-u URL` | Target URL. |
| `-x txt,json` | Add extensions during `dir` mode. |
| `-s 200,403` | Include only these status codes in `dir` mode. |
| `-b 404` | Exclude these status codes. |
| `-t 5` | Limit worker threads. |
| `-z` | Hide progress output. |
| `-o FILE` | Save output to a file. |

## Generate Practice Scans

Run a quick Gobuster sweep:

```bash
sh labs/gobuster/make_scans.sh
```

This writes raw Gobuster output, TSV summaries, and an HTTP status check into
`labs/gobuster/outputs`.

## Practice Tasks

1. Find the hidden content paths and compare status codes.
2. Discover which files exist under `/files` with `-x`.
3. Find valid `*.gobuster.lab` virtual hosts.
4. Discover valid DNS subdomains for `gobuster.lab`.
5. Use fuzz mode to find accepted `/search` parameter names.
6. Fuzz the token path and verify the successful response manually.
7. Run `sh labs/gobuster/make_scans.sh` and inspect the saved TSV summaries.

## Troubleshooting

If Gobuster returns too much noise, add filters such as `-b 404`, `-s 200,403`,
or `--exclude-length SIZE`.

If DNS mode finds no records, confirm the target DNS responder is reachable:

```bash
docker compose -f labs/gobuster/docker-compose.yml exec scanner \
  dig @172.43.130.20 admin.gobuster.lab +short
```

If Compose reports that port `18089` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18089:8080` to `127.0.0.1:28089:8080`.
