# Real Local Target Lab

This lab creates a host-reachable target on `127.0.0.1` for local Nmap,
Wireshark, curl, DNS, and text-protocol practice. It is still containerized, but
its services are published to localhost so your normal host tools can interact
with it.

The target is intentionally bound to `127.0.0.1` instead of `0.0.0.0`. That
keeps the lab local to your machine and prevents accidental LAN exposure.

## Safety Rules

- Use this target for local practice only.
- Do not change the port bindings to public interfaces unless you understand the risk.
- Capture only your own lab traffic.
- Stop the lab when you are done.

## Start The Target

Run from the repository root:

```bash
docker compose -f labs/local-target/docker-compose.yml up --build -d
docker compose -f labs/local-target/docker-compose.yml ps
```

Open the web target:

```bash
open http://127.0.0.1:8088
```

Stop it:

```bash
docker compose -f labs/local-target/docker-compose.yml down
```

## Local Services

| Service | Host endpoint | Container endpoint |
| --- | --- | --- |
| HTTP app | `127.0.0.1:8088` | `local-target:8080` |
| SSH-like banner | `127.0.0.1:2222` | `local-target:2222` |
| SMTP-like banner | `127.0.0.1:2525` | `local-target:2525` |
| Redis-like service | `127.0.0.1:16379` | `local-target:6379` |
| DNS-like UDP | `127.0.0.1:5300` | `local-target:5300/udp` |

## Try Host Tools

HTTP:

```bash
curl -i http://127.0.0.1:8088/
curl -s http://127.0.0.1:8088/api/status
curl -i -X POST -d "username=analyst&password=packetlab" \
  http://127.0.0.1:8088/login
```

Nmap from your host:

```bash
nmap -sV -p 8088,2222,2525,16379 127.0.0.1
```

DNS:

```bash
dig @127.0.0.1 -p 5300 target.local-target.lab A
```

Text protocols:

```bash
printf "EHLO host.local-target.lab\r\nQUIT\r\n" | nc -w 2 127.0.0.1 2525
printf '*1\r\n$4\r\nPING\r\n' | nc -w 2 127.0.0.1 16379
```

If your host does not have these tools, use the toolbox container:

```bash
docker compose -f labs/local-target/docker-compose.yml exec toolbox \
  nmap -sV -p 8080,2222,2525,6379 local-target

docker compose -f labs/local-target/docker-compose.yml exec toolbox \
  curl -i http://local-target:8080/api/status

docker compose -f labs/local-target/docker-compose.yml exec toolbox \
  dig @local-target -p 5300 target.local-target.lab A
```

## Generate Loopback Traffic For Wireshark

Start a capture in the Wireshark desktop app on the loopback interface. On macOS
that interface is usually `lo0`. Useful display filters:

| Filter | Meaning |
| --- | --- |
| `ip.addr == 127.0.0.1` | Local loopback traffic. |
| `tcp.port == 8088` | HTTP app traffic. |
| `tcp.port == 2222` | SSH-like banner traffic. |
| `tcp.port == 2525` | SMTP-like traffic. |
| `tcp.port == 16379` | Redis-like traffic. |
| `udp.port == 5300` | DNS-like traffic. |
| `http` | HTTP packets after Wireshark decodes port `8088` as HTTP. |

Then run:

```bash
sh labs/local-target/make_traffic.sh
```

For repeated container-generated traffic inside the Docker network:

```bash
docker compose -f labs/local-target/docker-compose.yml --profile traffic up --build -d
docker compose -f labs/local-target/docker-compose.yml logs -f traffic
```

## Suggested Practice

1. Scan `127.0.0.1` and identify the service banners.
2. Open the HTTP app and capture the request/response in Wireshark.
3. Log in with `analyst` / `packetlab` and inspect the `Set-Cookie` header.
4. Query `/api/users` and `/api/orders?owner=analyst`.
5. Capture DNS on UDP `5300` and decode it as DNS if Wireshark does not do it automatically.
6. Compare Nmap output from the host with Nmap output from the toolbox container.

## Troubleshooting

If Docker reports that a port is already allocated, change the host side of the
mapping in `docker-compose.yml`. For example, change `127.0.0.1:8088:8080` to
`127.0.0.1:18088:8080`.

If the web app does not answer, inspect logs:

```bash
docker compose -f labs/local-target/docker-compose.yml logs --tail=50 local-target
```
