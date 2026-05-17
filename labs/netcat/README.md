# Netcat Guide And Local Lab

This lab teaches Netcat with Docker targets that are published to `127.0.0.1`,
so you can practice from your host and from a toolbox container. It is designed
for authorized local practice only.

Netcat is a small tool for opening TCP and UDP connections, listening on ports,
sending raw text to services, transferring simple data streams, and debugging
network behavior.

## Safety Rules

- Connect only to systems you own or have permission to test.
- Keep listeners bound to localhost unless you intentionally need wider access.
- Do not pipe secrets or private files into arbitrary network connections.
- Treat Netcat as a debugging tool, not as authentication or encryption.

## Lab Topology

The Compose file creates a Docker lab network and publishes each target service
to localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `target` | `172.33.40.20` | Runs TCP, UDP, and raw HTTP services for Netcat practice. |
| `toolbox` | `172.33.40.10` | Includes `nc`, `curl`, `dig`, `ping`, `ip`, and `tcpdump`. |

Host-reachable endpoints:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:19001` | `target:9001` | TCP echo service. |
| `127.0.0.1:19002` | `target:9002` | TCP banner service. |
| `127.0.0.1:19003` | `target:9003` | TCP note sink. |
| `127.0.0.1:19080` | `target:9080` | Raw HTTP service. |
| `127.0.0.1:19004/udp` | `target:9004/udp` | UDP echo service. |

All published ports are bound to `127.0.0.1`, not `0.0.0.0`, so they stay on
your machine and are not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/netcat/docker-compose.yml up --build -d
docker compose -f labs/netcat/docker-compose.yml ps
```

Clean up when finished:

```bash
docker compose -f labs/netcat/docker-compose.yml down
```

## Basic TCP Connections

Connect to the echo service:

```bash
nc 127.0.0.1 19001
```

Type a few lines, then type `quit` to close.

Pipe text into the echo service:

```bash
printf 'hello netcat\nquit\n' | nc -w 2 127.0.0.1 19001
```

Grab a service banner:

```bash
nc -v 127.0.0.1 19002
```

Send a note:

```bash
printf 'first note from host\nsecond line\n' | nc -w 2 127.0.0.1 19003
```

Inspect target logs:

```bash
docker compose -f labs/netcat/docker-compose.yml logs --tail=40 target
```

## Raw HTTP With Netcat

Netcat is useful for seeing what an HTTP request really looks like:

```bash
printf 'GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n' \
  | nc -w 2 127.0.0.1 19080
```

Try the JSON endpoint:

```bash
printf 'GET /api/status HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n' \
  | nc -w 2 127.0.0.1 19080
```

## UDP With Netcat

Send a UDP datagram:

```bash
printf 'hello udp\n' | nc -u -w 2 127.0.0.1 19004
```

UDP has no connection handshake, so timeouts and missing responses are normal
debugging signals.

## Listen Locally

Start a listener in one terminal:

```bash
nc -l 127.0.0.1 19100
```

Send data to it from another terminal:

```bash
printf 'message to local listener\n' | nc -w 2 127.0.0.1 19100
```

Inside the toolbox container, listen on the Docker lab network:

```bash
docker compose -f labs/netcat/docker-compose.yml exec toolbox \
  nc -l -p 9100
```

Then send data from your host through the target network by using the toolbox in
a second terminal:

```bash
docker compose -f labs/netcat/docker-compose.yml exec toolbox \
  sh -lc "printf 'container message\n' | nc -w 2 127.0.0.1 9100"
```

## Use The Toolbox

If your host does not have Netcat, use the toolbox:

```bash
docker compose -f labs/netcat/docker-compose.yml exec toolbox \
  nc target 9001

docker compose -f labs/netcat/docker-compose.yml exec toolbox \
  sh -lc "printf 'GET /health HTTP/1.1\r\nHost: target\r\nConnection: close\r\n\r\n' | nc -w 2 target 9080"

docker compose -f labs/netcat/docker-compose.yml exec toolbox \
  sh -lc "printf 'hello udp\n' | nc -u -w 2 target 9004"
```

## Generate Practice Traffic

Run a quick host-side traffic sweep:

```bash
sh labs/netcat/make_traffic.sh
```

This touches TCP echo, banner, notes, raw HTTP, and UDP echo.

## Practice Tasks

1. Connect to the echo service and close the session with `quit`.
2. Grab the banner from `127.0.0.1:19002`.
3. Send a raw HTTP request to `/api/status`.
4. Send one UDP datagram and compare the behavior to TCP.
5. Start a localhost listener and send it a message from another terminal.
6. Run `tcpdump` in the toolbox while sending host traffic to observe packets.

## Troubleshooting

If Compose reports that a port is already allocated, change the host side of
the mapping in `docker-compose.yml`. For example, change
`127.0.0.1:19001:9001` to `127.0.0.1:29001:9001`.

If `nc` does not close after input, add `-w 2` to set a short idle timeout.

If UDP appears silent, try again with `-u -w 2` and remember there is no TCP-like
connection setup for UDP.
