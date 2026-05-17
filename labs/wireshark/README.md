# Wireshark Guide And Local Lab

This lab teaches packet capture and packet analysis with Docker targets that
are also published to `127.0.0.1`, generated traffic, `tshark`, and a small
terminal packet viewer. It is designed for authorized practice only.

Wireshark is a graphical packet analyzer. `tshark` is the command-line analyzer
from the same project, and it is easier to run inside a lab container. The
official project site is https://www.wireshark.org/ and the display filter
reference is https://www.wireshark.org/docs/dfref/.

## Safety Rules

- Capture only networks, hosts, and applications you own or have permission to monitor.
- Do not capture credentials, private messages, or production traffic without a written scope.
- Use this lab network before capturing traffic from real systems.
- Store packet captures carefully because they may contain sensitive data.
- Treat decoded packets as evidence to verify, not as the whole story.

## Lab Topology

The Compose file creates a Docker lab network and publishes target services to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `client` | `172.31.20.10` | Generates HTTP, SMTP-like, Redis-like, and DNS traffic. |
| `target-services` | `172.31.20.20` | Runs the local services that answer the client. |
| `analyzer` | Shares `client` networking | Runs `tshark`, `tcpdump`, and `mini_wireshark.py`. |

Host-reachable endpoints:

| Host endpoint | Container service |
| --- | --- |
| `127.0.0.1:8090` | `target-services:8080` HTTP |
| `127.0.0.1:12526` | `target-services:2525` SMTP-like banner |
| `127.0.0.1:16381` | `target-services:6379` Redis-like service |
| `127.0.0.1:15300/udp` | `target-services:5300/udp` DNS-like service |

The analyzer shares the client's network namespace, so packet capture on `eth0`
sees the client's traffic without needing to sniff other containers from the
Docker bridge. For real host loopback practice, capture `127.0.0.1` traffic
from your Wireshark desktop app and use `make_traffic.sh`.

All published ports are bound to `127.0.0.1`, not `0.0.0.0`, so they stay on
your machine and are not exposed to your LAN.

## Start The Lab

Run these commands from the repository root:

```bash
docker compose -f labs/wireshark/docker-compose.yml up --build -d
docker compose -f labs/wireshark/docker-compose.yml ps
docker compose -f labs/wireshark/docker-compose.yml logs -f client
```

Open the host-reachable HTTP target:

```bash
open http://127.0.0.1:8090
```

Clean up when finished:

```bash
docker compose -f labs/wireshark/docker-compose.yml down
```

## Capture Packets

List capture interfaces:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer tshark -D
```

Capture 20 seconds of client-to-target traffic:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  tshark -i eth0 -f "host 172.31.20.20" -a duration:20 -w captures/lab.pcapng
```

The capture is saved on your host at `labs/wireshark/captures/lab.pcapng`.
You can open that file in the Wireshark desktop app if you have it installed.

## Capture Real Localhost Traffic

Start a capture in the Wireshark desktop app on the loopback interface. On
macOS that interface is usually `lo0`.

Then generate host traffic:

```bash
sh labs/wireshark/make_traffic.sh
```

Useful loopback display filters:

| Filter | Meaning |
| --- | --- |
| `ip.addr == 127.0.0.1` | Localhost traffic. |
| `tcp.port == 8090` | HTTP target traffic. |
| `tcp.port == 12526` | SMTP-like target traffic. |
| `tcp.port == 16381` | Redis-like target traffic. |
| `udp.port == 15300` | DNS-like target traffic. |

If Wireshark does not decode the HTTP or DNS traffic automatically, use
`Analyze > Decode As...` and map TCP `8090` as HTTP or UDP `15300` as DNS.

## Read Packets With Tshark

Show a normal packet list:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  tshark -r captures/lab.pcapng
```

Show only HTTP packets:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  tshark -r captures/lab.pcapng -Y "http"
```

Show only DNS queries and answers. The lab uses UDP port `5300`, so this command
asks Wireshark to decode that port as DNS:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  tshark -r captures/lab.pcapng -d udp.port==5300,dns -Y "dns"
```

Print selected fields:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  tshark -r captures/lab.pcapng -T fields \
  -e frame.number -e ip.src -e ip.dst -e _ws.col.Protocol -e _ws.col.Info
```

## Use The Mini Viewer

The analyzer image includes `mini_wireshark.py`, a small Python wrapper around
`tshark` for quick packet summaries.

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  python3 /opt/lab/mini_wireshark.py packets captures/lab.pcapng
```

Apply a Wireshark display filter:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  python3 /opt/lab/mini_wireshark.py packets captures/lab.pcapng -Y "tcp.port == 8080"
```

Show protocol statistics:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  python3 /opt/lab/mini_wireshark.py protocols captures/lab.pcapng
```

Show conversations:

```bash
docker compose -f labs/wireshark/docker-compose.yml exec analyzer \
  python3 /opt/lab/mini_wireshark.py conversations captures/lab.pcapng
```

## Core Wireshark Ideas

Packet analysis usually moves through four questions:

1. What conversations happened?
2. Which protocols were used?
3. Which packets are normal for that protocol?
4. Which packets deserve deeper inspection?

Important filter types:

| Type | Example | Use |
| --- | --- | --- |
| Capture filter | `host 172.31.20.20` | Limits what is saved while capturing. |
| Display filter | `http` | Hides or shows packets after capture. |
| Decode-as rule | `udp.port==5300,dns` | Tells Wireshark how to dissect unusual ports. |

Capture filters use Berkeley Packet Filter syntax and run before packets are
saved. Display filters use Wireshark syntax and run after packets are already
in the capture file.

## Useful Display Filters

| Filter | Meaning |
| --- | --- |
| `ip.addr == 172.31.20.20` | Packets to or from the target. |
| `tcp.port == 8080` | HTTP lab traffic. |
| `tcp.port == 8090` | Host loopback HTTP traffic. |
| `tcp.port == 2525` | SMTP-like lab traffic. |
| `tcp.port == 12526` | Host loopback SMTP-like traffic. |
| `tcp.port == 6379` | Redis-like lab traffic. |
| `tcp.port == 16381` | Host loopback Redis-like traffic. |
| `udp.port == 5300` | DNS lab traffic. |
| `udp.port == 15300` | Host loopback DNS-like traffic. |
| `http.request` | HTTP requests only. |
| `dns.qry.name contains "wireshark-lab"` | DNS queries for lab names. |
| `tcp.flags.syn == 1 && tcp.flags.ack == 0` | TCP connection attempts. |
| `tcp.analysis.retransmission` | TCP retransmissions detected by Wireshark. |

## Practice Tasks

1. Capture 20 seconds of traffic and find the first TCP handshake.
2. Filter for HTTP and identify the request URI.
3. Filter for Redis-like traffic and find the `PING` request and `PONG` response.
4. Decode UDP port `5300` as DNS and find the answer IP address.
5. Capture host loopback traffic on `lo0` and compare it with the analyzer capture.
6. Use conversation statistics to compare TCP and UDP packet counts.

## Troubleshooting

If `tshark` says it cannot capture on `eth0`, confirm the analyzer has the
`NET_ADMIN` and `NET_RAW` capabilities:

```bash
docker compose -f labs/wireshark/docker-compose.yml config | grep -A4 cap_add
```

If the capture is empty, make sure the client is still generating traffic:

```bash
docker compose -f labs/wireshark/docker-compose.yml logs --tail=20 client
```
