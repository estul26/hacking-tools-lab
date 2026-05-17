# RustScan Guide And Local Lab

This lab teaches `rustscan` with a single Docker target on a private local
network. It is designed for authorized local practice only.

RustScan is a fast port scanner that finds open ports and can hand those ports
to Nmap for deeper service detection. This lab keeps the scan small, local, and
predictable so you can learn the workflow safely.

## Safety Rules

- Scan only systems and networks you own or have clear permission to test.
- Keep batch sizes modest until you understand the target and network limits.
- Use explicit port lists or small ranges before scanning wider scopes.
- Verify RustScan findings with Nmap or a protocol client.
- Keep scan outputs with your authorization notes when doing real work.

## Lab Topology

The Compose file creates a Docker lab network and publishes target services to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.41.110.10` | Runs `rustscan`, `nmap`, `curl`, and stores scan output. |
| `target-services` | `172.41.110.20` | Runs predictable TCP services for RustScan practice. |

Host-reachable endpoints:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18086` | `target-services:80` | HTTP target. |
| `127.0.0.1:12224` | `target-services:2222` | SSH-like banner. |
| `127.0.0.1:12529` | `target-services:2525` | SMTP-like banner. |
| `127.0.0.1:16384` | `target-services:6379` | Redis-like service. |
| `127.0.0.1:18087` | `target-services:8000` | MySQL-like banner. |

All published ports are bound to `127.0.0.1`, not `0.0.0.0`, so they stay on
your machine and are not exposed to your LAN.

The scanner uses the official RustScan container image. On Apple Silicon Docker
may run it through `linux/amd64` emulation.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/rustscan/docker-compose.yml up --build -d
docker compose -f labs/rustscan/docker-compose.yml ps
docker compose -f labs/rustscan/docker-compose.yml exec scanner rustscan --version
```

Check the localhost HTTP target:

```bash
curl http://127.0.0.1:18086/api/status
```

Clean up when finished:

```bash
docker compose -f labs/rustscan/docker-compose.yml down
```

## Basic Scan

Scan the local target with a modest batch size:

```bash
docker compose -f labs/rustscan/docker-compose.yml exec scanner \
  rustscan -a 172.41.110.20 -p 80,2222,2525,6379,8000 \
  --batch-size 64 --timeout 1000 --tries 1 --accessible --scripts none
```

The expected open TCP ports are `80`, `2222`, `2525`, `6379`, and `8000`.

## Greppable Output

Greppable mode prints just the host and open ports:

```bash
docker compose -f labs/rustscan/docker-compose.yml exec scanner \
  rustscan -a 172.41.110.20 -p 80,2222,2525,6379,8000 \
  --batch-size 64 --timeout 1000 --tries 1 --accessible --greppable
```

This is useful when you want to pipe the discovered ports into another command.

## Run Nmap After RustScan

RustScan can pass discovered ports to Nmap. Arguments after `--` are sent to
Nmap:

```bash
docker compose -f labs/rustscan/docker-compose.yml exec scanner \
  rustscan -a 172.41.110.20 -p 80,2222,2525,6379,8000 \
  --batch-size 64 --timeout 1000 --tries 1 --accessible -- -sV -Pn
```

You can also run Nmap directly for comparison:

```bash
docker compose -f labs/rustscan/docker-compose.yml exec scanner \
  nmap -sV -Pn -p 80,2222,2525,6379,8000 172.41.110.20
```

## Useful Options

| Option | Use |
| --- | --- |
| `-a HOST` | Target host, CIDR, or file. |
| `-p 80,443` | Scan exact ports. |
| `-r 1-1000` | Scan a port range. |
| `--batch-size 64` | Limit concurrent port checks. |
| `--timeout 1000` | Set per-port timeout in milliseconds. |
| `--tries 1` | Try each port once. |
| `--accessible` | Disable visual output that is noisy in saved logs. |
| `--scripts none` | Skip the automatic Nmap step. |
| `--greppable` | Print compact host-to-port output. |
| `--top` | Scan RustScan's top ports list. |
| `-- COMMAND` | Pass arguments to Nmap. |

## Generate Practice Scans

Run a quick scan sweep:

```bash
sh labs/rustscan/make_scans.sh
```

This writes basic RustScan output, greppable output, parsed port lists, JSON,
RustScan-plus-Nmap output, direct Nmap output, and HTTP status output into
`labs/rustscan/scans`.

## Practice Tasks

1. Scan only `172.41.110.20` and confirm the five open TCP ports.
2. Compare normal output with `--greppable`.
3. Run RustScan with `--scripts none`, then with `-- -sV -Pn`.
4. Lower `--batch-size` to `10` and compare scan behavior.
5. Scan only ports `80` and `8000`.
6. Compare RustScan-plus-Nmap output with direct Nmap output.
7. Run `sh labs/rustscan/make_scans.sh` and inspect the saved outputs.

## Troubleshooting

If RustScan reports file limit warnings, lower `--batch-size` or pass a smaller
port list.

If a scan finds no ports, confirm the target is running:

```bash
docker compose -f labs/rustscan/docker-compose.yml ps
```

If Compose reports that a port is already allocated, change the host side of
the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18086:80` to `127.0.0.1:28086:80`.
