# Traceroute Guide And Routed Local Lab

This lab teaches `traceroute` with a real local route path inside Docker. It is
designed for authorized local practice only.

`traceroute` discovers network hops by sending packets with small TTL values.
Each router that decrements the TTL to zero should return an ICMP time-exceeded
message. By increasing the TTL one hop at a time, `traceroute` builds a view of
the path to the target.

## Safety Rules

- Trace only systems you own or have permission to test.
- Keep repeated traces modest; they can look like scanning from the other side.
- Remember that firewalls and routers may drop probes or hide hop details.
- Use this local lab before testing real networks.

## Lab Topology

The Compose file creates three Docker networks and two router containers. The
HTTP target is published to localhost for a quick health check, but the actual
traceroute exercises run from the toolbox container through the routed path.

| Container | IP | Purpose |
| --- | --- | --- |
| `toolbox` | `172.38.10.20` | Includes `traceroute`, `ping`, `curl`, `ip`, and `tcpdump`. |
| `router1` | `172.38.10.10`, `172.38.20.10` | First local router hop. |
| `router2` | `172.38.20.20`, `172.38.30.10` | Second local router hop. |
| `target` | `172.38.30.20` | HTTP target behind the routers. |

Expected traceroute path:

| Hop | Address | Meaning |
| --- | --- | --- |
| 1 | `172.38.10.10` | `router1` on the toolbox network. |
| 2 | `172.38.20.20` | `router2` on the router transit network. |
| 3 | `172.38.30.20` | Final target. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18082` | `target:8080` | HTTP sanity check. |

The published HTTP port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on
your machine and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/traceroute/docker-compose.yml up --build -d
docker compose -f labs/traceroute/docker-compose.yml ps
```

Check the localhost HTTP target:

```bash
curl http://127.0.0.1:18082/api/status
```

Clean up when finished:

```bash
docker compose -f labs/traceroute/docker-compose.yml down
```

## Basic Traceroute

Run the default UDP-style trace from the toolbox:

```bash
docker compose -f labs/traceroute/docker-compose.yml exec toolbox \
  traceroute -n 172.38.30.20
```

The `-n` flag skips DNS lookups so the lab output stays focused on IP
addresses.

## Compare Probe Types

Use ICMP echo probes:

```bash
docker compose -f labs/traceroute/docker-compose.yml exec toolbox \
  traceroute -n -I 172.38.30.20
```

Use TCP SYN probes to the target HTTP port:

```bash
docker compose -f labs/traceroute/docker-compose.yml exec toolbox \
  traceroute -n -T -p 8080 172.38.30.20
```

These variants are useful because real networks often filter UDP, ICMP, and TCP
differently.

## Inspect The Route

View the toolbox route table:

```bash
docker compose -f labs/traceroute/docker-compose.yml exec toolbox ip route
```

Ping the final target:

```bash
docker compose -f labs/traceroute/docker-compose.yml exec toolbox \
  ping -c 3 172.38.30.20
```

Watch probes with `tcpdump`:

```bash
docker compose -f labs/traceroute/docker-compose.yml exec toolbox \
  tcpdump -ni eth0 'icmp or udp or tcp port 8080'
```

Run traceroute again from another terminal while `tcpdump` is watching.

## Generate Practice Traces

Run a quick trace sweep:

```bash
sh labs/traceroute/make_traces.sh
```

This writes route, ping, UDP traceroute, ICMP traceroute, TCP traceroute, and
HTTP status outputs into `labs/traceroute/outputs`.

## How To Read Traceroute

Useful fields to notice:

| Field | Meaning |
| --- | --- |
| Hop number | TTL value used for that probe. |
| IP address | Router or target that answered. |
| Round-trip time | Probe latency for that hop. |
| `*` | No response before timeout. |
| `!X`, `!N`, `!H` | Network, host, or administrative unreachable signals. |

## Practice Tasks

1. Run the default trace and confirm the three-hop path.
2. Compare UDP, ICMP, and TCP traces.
3. Use `ip route` to identify the static route through `router1`.
4. Stop `router2` and observe how traceroute changes.
5. Restart the lab and run `sh labs/traceroute/make_traces.sh`.
6. Use `tcpdump` while running a TCP traceroute to port `8080`.

## Troubleshooting

If Compose reports that port `18082` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18082:8080` to `127.0.0.1:28082:8080`.

If traceroute shows only `* * *`, confirm that all containers are running:

```bash
docker compose -f labs/traceroute/docker-compose.yml ps
```

If the target is reachable but hop output differs, rerun with `-I` or `-T`.
Different probe types trigger different firewall and kernel behavior.
