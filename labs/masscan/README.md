# Masscan Guide And Local Lab

This lab teaches `masscan` with a single Docker target on a private local
network. It is designed for authorized local practice only.

`masscan` is a high-speed port scanner. It is useful for quickly finding open
ports across large authorized address ranges, but it does not replace careful
validation. In this lab, every example uses a low packet rate and a local Docker
target so the behavior stays controlled.

## Safety Rules

- Scan only systems and networks you own or have clear permission to test.
- Always define a tight target range before running Masscan.
- Always set a deliberate `--rate`; do not use high rates on shared networks.
- Verify Masscan findings with a slower tool such as Nmap or a protocol client.
- Keep scan outputs with your authorization notes when doing real work.

## Lab Topology

The Compose file creates a Docker lab network and publishes target services to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.40.100.10` | Runs `masscan`, `nmap`, `curl`, and stores scan output. |
| `target-services` | `172.40.100.20` | Runs predictable TCP services for Masscan practice. |

Host-reachable endpoints:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18084` | `target-services:80` | HTTP target. |
| `127.0.0.1:12223` | `target-services:2222` | SSH-like banner. |
| `127.0.0.1:12528` | `target-services:2525` | SMTP-like banner. |
| `127.0.0.1:16383` | `target-services:6379` | Redis-like service. |
| `127.0.0.1:18085` | `target-services:8000` | MySQL-like banner. |

All published ports are bound to `127.0.0.1`, not `0.0.0.0`, so they stay on
your machine and are not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/masscan/docker-compose.yml up --build -d
docker compose -f labs/masscan/docker-compose.yml ps
docker compose -f labs/masscan/docker-compose.yml exec scanner \
  sh -lc 'masscan --version || true'
```

Check the localhost HTTP target:

```bash
curl http://127.0.0.1:18084/api/status
```

Clean up when finished:

```bash
docker compose -f labs/masscan/docker-compose.yml down
```

## Basic Scan

Scan the local target at a low rate:

```bash
docker compose -f labs/masscan/docker-compose.yml exec scanner \
  masscan 172.40.100.20 -p80,2222,2525,6379,8000 --rate 100 --wait 0 --open-only
```

The expected open TCP ports are `80`, `2222`, `2525`, `6379`, and `8000`.

## Scan A Local Range

Scan only web-style ports across the Docker lab subnet:

```bash
docker compose -f labs/masscan/docker-compose.yml exec scanner \
  masscan 172.40.100.0/24 -p80,8000 --rate 100 --wait 0 --open-only
```

This stays inside the `masscan-lab` Docker network.

## Save Output

Masscan can write several useful formats:

```bash
docker compose -f labs/masscan/docker-compose.yml exec scanner \
  masscan 172.40.100.20 -p80,2222,2525,6379,8000 \
  --rate 100 --wait 0 --open-only -oL scans/target-open.lst

docker compose -f labs/masscan/docker-compose.yml exec scanner \
  masscan 172.40.100.20 -p80,2222,2525,6379,8000 \
  --rate 100 --wait 0 --open-only -oG scans/target-open.gnmap

docker compose -f labs/masscan/docker-compose.yml exec scanner \
  masscan 172.40.100.20 -p80,2222,2525,6379,8000 \
  --rate 100 --wait 0 --open-only -oJ scans/target-open.json
```

The files are saved on your host under `labs/masscan/scans`.

## Verify Findings

Masscan tells you a port answered, not what the service truly is. Follow up
with Nmap or a protocol client:

```bash
docker compose -f labs/masscan/docker-compose.yml exec scanner \
  nmap -sV -Pn -p 80,2222,2525,6379,8000 172.40.100.20

docker compose -f labs/masscan/docker-compose.yml exec scanner \
  curl -i http://172.40.100.20/api/status
```

## Useful Options

| Option | Use |
| --- | --- |
| `-p80,443` | Scan exact ports. |
| `-p1-1024` | Scan a range of ports. |
| `--rate 100` | Limit packets per second. |
| `--wait 0` | Exit after immediate local replies in this lab. |
| `--open-only` | Print only open results. |
| `-oL FILE` | Write list output. |
| `-oG FILE` | Write grepable output. |
| `-oJ FILE` | Write JSON output. |
| `--exclude IP` | Remove a host from scope. |
| `--excludefile FILE` | Remove hosts listed in a file from scope. |

## Generate Practice Scans

Run a quick scan sweep:

```bash
sh labs/masscan/make_scans.sh
```

This writes raw Masscan output, list, grepable, JSON, range-scan, Nmap
follow-up, and HTTP status outputs into `labs/masscan/scans`.

## Practice Tasks

1. Scan only `172.40.100.20` and confirm the five open TCP ports.
2. Scan `172.40.100.0/24` for ports `80` and `8000`.
3. Save the same scan as list, grepable, and JSON output.
4. Compare Masscan output with Nmap service detection.
5. Lower `--rate` to `10` and compare scan duration.
6. Use `--exclude 172.40.100.20` and confirm no target results are printed.
7. Run `sh labs/masscan/make_scans.sh` and inspect the saved outputs.

## Troubleshooting

If Masscan reports permission or raw-socket errors, confirm the scanner has the
`NET_ADMIN` and `NET_RAW` capabilities:

```bash
docker compose -f labs/masscan/docker-compose.yml config | grep -A4 cap_add
```

If a scan finds no ports, confirm the target is running:

```bash
docker compose -f labs/masscan/docker-compose.yml ps
```

If Compose reports that a port is already allocated, change the host side of
the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18084:80` to `127.0.0.1:28084:80`.
