# Nmap Guide And Local Lab

This lab teaches Nmap with a private Docker network and intentionally exposed
local targets. It is designed for authorized practice only.

Nmap, short for Network Mapper, is an open source tool for network exploration,
asset discovery, port scanning, service detection, and security auditing. The
official reference describes it as a network exploration and security scanner:
https://nmap.org/book/man.html. The official documentation index is here:
https://nmap.org/docs.html.

## Safety Rules

- Scan only systems you own or have clear permission to test.
- Use this lab network for practice before scanning real infrastructure.
- Do not run aggressive scans against public targets unless you are authorized.
- Keep notes of the target, command, time, and result when doing real work.
- Treat Nmap output as evidence to verify, not as guaranteed truth.

## Lab Topology

The Compose file creates one internal network with no published host ports:

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.30.10.10` | Runs Nmap and stores scan output in `scans/`. |
| `target-web` | `172.30.10.20` | HTTP training service on TCP `80`. |
| `target-services` | `172.30.10.30` | TCP `2222`, `2525`, `6379`, `8000` and UDP `5353`. |

Because the Docker network is marked `internal: true`, the running lab is
isolated from external networks. Image builds still need internet access the
first time Docker pulls base images or installs packages.

## Start The Lab

Run these commands from the repository root:

```bash
docker compose -f labs/nmap/docker-compose.yml up --build -d
docker compose -f labs/nmap/docker-compose.yml ps
docker compose -f labs/nmap/docker-compose.yml exec scanner nmap --version
```

Clean up when finished:

```bash
docker compose -f labs/nmap/docker-compose.yml down
```

## How Nmap Thinks

Most useful scans answer four questions:

1. Which hosts are up?
2. Which ports are reachable?
3. What services and versions are behind those ports?
4. What should be verified manually next?

Important port states:

| State | Meaning |
| --- | --- |
| `open` | A service is listening and answered Nmap. |
| `closed` | The host answered, but no service is listening on that port. |
| `filtered` | A firewall or network filter blocked the probe or response. |
| `open|filtered` | Nmap cannot distinguish an open port from a filtered one. Common with UDP. |
| `unfiltered` | The port is reachable, but Nmap cannot tell if it is open or closed. |

Common scan phases include target parsing, host discovery, reverse DNS lookup,
port scanning, service/version detection, NSE script execution, OS detection,
traceroute, and output generation. Nmap only performs the phases requested by
your command.

## Target Selection

Nmap accepts hostnames, IP addresses, ranges, and CIDR blocks:

```bash
nmap target-web
nmap 172.30.10.20
nmap 172.30.10.20-30
nmap 172.30.10.0/24
```

Use `-iL targets.txt` for a target file and `--exclude` or `--excludefile` to
remove hosts from scope.

## Host Discovery

Host discovery finds live hosts without doing a full port scan:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -sn 172.30.10.0/24
```

Use this first on larger authorized networks. If a host blocks ping-style
discovery but you know it is in scope, `-Pn` skips host discovery and treats the
target as online:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -Pn target-web
```

## Basic TCP Scans

Scan the most common TCP ports on one target:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap target-web
```

Scan specific ports:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -p 80 target-web

docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -p 2222,2525,6379,8000 target-services
```

Scan all TCP ports:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -p- target-services
```

Useful port selectors:

| Option | Use |
| --- | --- |
| `-p 22,80,443` | Scan exact ports. |
| `-p 1-1024` | Scan a range. |
| `-p-` | Scan all TCP ports. |
| `-F` | Fast scan, fewer ports. |
| `--top-ports 100` | Scan the most common 100 ports. |

## Service And Version Detection

`-sV` connects to open ports and probes the service:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -sV -p 2222,2525,6379,8000 target-services
```

This helps distinguish real services from misleading port numbers. For example,
port `2222` in this lab sends an SSH-like banner, and port `2525` sends an
SMTP-like banner.

## Default Scripts

The Nmap Scripting Engine, or NSE, runs Lua scripts for discovery, safe checks,
and deeper protocol inspection. `-sC` runs the default script set:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -sC -sV -p 80 target-web
```

Find scripts in the scanner container:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  ls /usr/share/nmap/scripts | head
```

Get help for a script:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap --script-help http-title
```

Common safe script categories:

| Category | Use |
| --- | --- |
| `default` | Normal default checks used by `-sC`. |
| `discovery` | Extra host and service discovery. |
| `safe` | Scripts intended to avoid disruption. |
| `version` | Help identify services and versions. |

Avoid intrusive or exploit categories unless you have explicit permission and a
test plan.

## UDP Scan

UDP scanning is slower and often less certain because many UDP services do not
reply to empty probes. This lab includes a UDP service on port `5353`:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -sU -p 5353 target-services
```

If you see `open|filtered`, it means Nmap did not get enough evidence to choose
between an open UDP service and packet filtering.

## OS Detection And Aggressive Mode

OS detection uses TCP/IP fingerprinting and usually needs privileged raw packet
access:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -O target-web
```

Aggressive mode combines OS detection, version detection, default scripts, and
traceroute:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -A target-web
```

Use `-A` deliberately. It is convenient for small authorized targets, but it is
too broad for many production scans.

## Timing And Performance

Nmap timing templates range from `-T0` to `-T5`:

| Template | Meaning |
| --- | --- |
| `-T0`, `-T1` | Very slow. Sometimes used to reduce noise. |
| `-T2` | Polite, slower scanning. |
| `-T3` | Default behavior. |
| `-T4` | Faster on reliable networks. |
| `-T5` | Very aggressive and more likely to miss results. |

For this local lab, `-T4` is acceptable:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -T4 -sV -p 2222,2525,6379,8000 target-services
```

Practical performance workflow:

1. Use `-sn` to find live hosts.
2. Use `-F` or `--top-ports` for a quick first pass.
3. Use `-p-` only where needed.
4. Add `-sV` and scripts after you know which ports matter.
5. Run UDP separately from TCP.

## Output Formats

Save repeatable evidence with output options:

```bash
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -oA scans/target-web -p 80 target-web
```

This writes:

| File | Format |
| --- | --- |
| `scans/target-web.nmap` | Normal human-readable output. |
| `scans/target-web.gnmap` | Grepable output. |
| `scans/target-web.xml` | XML for tools and parsing. |

Other useful output options:

| Option | Use |
| --- | --- |
| `-oN file.nmap` | Normal output. |
| `-oX file.xml` | XML output. |
| `-oG file.gnmap` | Grepable output. |
| `-oA basename` | All three major formats. |
| `-v` | More detail while scanning. |
| `--reason` | Show why Nmap chose each state. |

## Example Workflow

Use this sequence when approaching an authorized environment:

```bash
# 1. Discover live lab hosts.
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -sn 172.30.10.0/24

# 2. Quick TCP scan.
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -F 172.30.10.20-30

# 3. Scan all TCP ports on the interesting host.
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -p- target-services

# 4. Probe versions only on discovered ports.
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -sV -p 2222,2525,6379,8000 target-services

# 5. Save evidence.
docker compose -f labs/nmap/docker-compose.yml exec scanner \
  nmap -sV -oA scans/target-services -p 2222,2525,6379,8000 target-services
```

## Exercises

1. Find all live hosts on `172.30.10.0/24`.
2. Identify the open TCP ports on `target-web`.
3. Identify the open TCP ports on `target-services`.
4. Run `-sV` and write down which service each open port appears to run.
5. Run `-sC -sV` against `target-web` and compare the output to the basic scan.
6. Run a UDP scan against `target-services` on port `5353`.
7. Save XML output for `target-services` and inspect it with `less`.
8. Repeat a scan with `--reason` and explain why Nmap marked each port open.

## Command Cheat Sheet

| Goal | Command |
| --- | --- |
| Check Nmap version | `nmap --version` |
| Ping scan | `nmap -sn 172.30.10.0/24` |
| Basic scan | `nmap target-web` |
| Skip host discovery | `nmap -Pn target-web` |
| Specific TCP ports | `nmap -p 80,443 target-web` |
| All TCP ports | `nmap -p- target-services` |
| Version detection | `nmap -sV -p 80 target-web` |
| Default scripts | `nmap -sC -sV -p 80 target-web` |
| UDP scan | `nmap -sU -p 5353 target-services` |
| Save all outputs | `nmap -oA scans/name target-web` |
| Show reasons | `nmap --reason target-web` |
| Faster local scan | `nmap -T4 target-web` |

## Troubleshooting

If Compose cannot pull images or install packages, connect to the internet and
rerun the build command.

If `target-web` or `target-services` does not resolve, check container status:

```bash
docker compose -f labs/nmap/docker-compose.yml ps
```

If a scan says a host is down but you know it is in scope, retry with `-Pn`.

If UDP output is uncertain, remember that `open|filtered` is normal for UDP
when the service or network does not reply clearly.
