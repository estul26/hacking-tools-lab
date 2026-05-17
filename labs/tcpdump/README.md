# Tcpdump Guide And Local Lab

This lab teaches `tcpdump` with Docker targets that are published to
`127.0.0.1` and a packet analyzer container that can capture traffic without
needing host `sudo`. It is designed for authorized local practice only.

`tcpdump` captures packets from a network interface. Capture filters use
Berkeley Packet Filter syntax, so they run while packets are being captured and
keep the saved file small.

## Safety Rules

- Capture only networks, hosts, and applications you own or have permission to monitor.
- Do not capture credentials, private messages, or production traffic without a written scope.
- Keep capture files private because packet payloads can contain sensitive data.
- Use this local lab before capturing traffic from real systems.

## Lab Topology

The Compose file creates a Docker lab network and publishes target services to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `client` | `172.39.90.10` | Generates HTTP, SMTP-like, Redis-like, and DNS traffic. |
| `target-services` | `172.39.90.20` | Runs the local services that answer the client. |
| `analyzer` | Shares `client` networking | Runs `tcpdump` against the client network namespace. |

Host-reachable endpoints:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18083` | `target-services:8080` | HTTP target. |
| `127.0.0.1:12527` | `target-services:2525` | SMTP-like banner. |
| `127.0.0.1:16382` | `target-services:6379` | Redis-like service. |
| `127.0.0.1:15301/udp` | `target-services:5300/udp` | DNS-like service. |

All published ports are bound to `127.0.0.1`, not `0.0.0.0`, so they stay on
your machine and are not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/tcpdump/docker-compose.yml up --build -d
docker compose -f labs/tcpdump/docker-compose.yml ps
```

Check the localhost HTTP target:

```bash
curl http://127.0.0.1:18083/api/status
```

Clean up when finished:

```bash
docker compose -f labs/tcpdump/docker-compose.yml down
```

## Capture Live Traffic

Start a capture in one terminal:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec analyzer \
  tcpdump -i eth0 -nn 'host 172.39.90.20'
```

Generate one round of client traffic in another terminal:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec client \
  env ONCE=1 python /opt/lab/traffic_client.py
```

Stop the capture with `Ctrl-C`.

## Write And Read A Pcap

Write packets to a file:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec analyzer \
  tcpdump -i eth0 -nn -s 0 -w captures/lab.pcap 'host 172.39.90.20'
```

Read the saved file:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec analyzer \
  tcpdump -nn -r captures/lab.pcap
```

The capture is saved on your host at `labs/tcpdump/captures/lab.pcap`.

## Useful Capture Filters

| Filter | Meaning |
| --- | --- |
| `host 172.39.90.20` | Traffic to or from the target. |
| `src host 172.39.90.10` | Traffic sent by the client. |
| `dst host 172.39.90.20` | Traffic going to the target. |
| `tcp port 8080` | HTTP lab traffic. |
| `tcp port 2525` | SMTP-like lab traffic. |
| `tcp port 6379` | Redis-like lab traffic. |
| `udp port 5300` | DNS-like lab traffic. |
| `tcp[tcpflags] & tcp-syn != 0` | TCP SYN packets. |
| `not port 8080` | Exclude HTTP traffic. |

## Useful Output Flags

| Flag | Use |
| --- | --- |
| `-i eth0` | Capture on the lab interface. |
| `-nn` | Do not resolve hostnames or service names. |
| `-c 20` | Stop after 20 packets. |
| `-s 0` | Capture full packets instead of truncating payloads. |
| `-w FILE` | Write raw packets to a pcap file. |
| `-r FILE` | Read packets from a pcap file. |
| `-A` | Print packet payloads as ASCII. |
| `-X` / `-XX` | Print packet payloads as hex and ASCII. |
| `-tttt` | Print human-readable timestamps. |

## Inspect Payloads

Show HTTP payload text:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec analyzer \
  tcpdump -A -nn -r captures/lab.pcap 'tcp port 8080'
```

Show DNS packets in hex and ASCII:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec analyzer \
  tcpdump -XX -nn -r captures/lab.pcap 'udp port 5300'
```

Show TCP connection attempts:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec analyzer \
  tcpdump -nn -r captures/lab.pcap 'tcp[tcpflags] & tcp-syn != 0'
```

## Generate Practice Captures

Run a quick capture sweep:

```bash
sh labs/tcpdump/make_captures.sh
```

This writes `lab.pcap`, packet summaries, HTTP ASCII output, DNS hex output,
and TCP SYN summaries into `labs/tcpdump/captures`.

## Capture Real Localhost Traffic

The target is also reachable from your host. On macOS, host loopback captures
usually use interface `lo0` and may require `sudo`:

```bash
sudo tcpdump -i lo0 -nn 'host 127.0.0.1 and port 18083'
curl http://127.0.0.1:18083/api/status
```

Use the Docker analyzer commands above when you want the lab to avoid host
capture permissions.

## Practice Tasks

1. Capture one client traffic run and identify the TCP three-way handshake.
2. Save a pcap and read it back with `tcpdump -r`.
3. Filter only HTTP traffic on TCP port `8080`.
4. Use `-A` to find the HTTP `User-Agent`.
5. Use `-XX` to inspect the DNS-like UDP query.
6. Compare `host`, `src host`, and `dst host` filters.
7. Run `sh labs/tcpdump/make_captures.sh` and inspect the saved outputs.

## Troubleshooting

If `tcpdump` says it cannot capture on `eth0`, confirm the analyzer has the
`NET_ADMIN` and `NET_RAW` capabilities:

```bash
docker compose -f labs/tcpdump/docker-compose.yml config | grep -A4 cap_add
```

If the capture is empty, generate traffic while tcpdump is running:

```bash
docker compose -f labs/tcpdump/docker-compose.yml exec client \
  env ONCE=1 python /opt/lab/traffic_client.py
```

If Compose reports that a port is already allocated, change the host side of
the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18083:8080` to `127.0.0.1:28083:8080`.
