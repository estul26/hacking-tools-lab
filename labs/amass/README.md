# Amass Guide And Local DNS Workflow Lab

This lab teaches OWASP Amass with a real local DNS authority, deterministic
local discovery data, and an HTTP validation target. You can practice source
listing, scope control, output filtering, and local validation against assets
you control.

Amass maps external attack surfaces with passive and active techniques. Passive
data sources need real public domains and often API keys; local Docker-only
names will not exist in those datasets. Amass v4 also builds an untrusted
resolver pool before `enum` runs, so a Docker-only private resolver is not a
reliable full enumeration path. This lab uses real Amass for source and version
practice, then validates a local Amass-shaped discovery fixture against
`packetlab.local`.

## Safety Rules

- Enumerate only domains, networks, and organizations you own or have explicit permission to test.
- Keep passive sources, brute-force wordlists, resolvers, ports, and timing inside scope.
- Do not run active brute forcing against production domains without written authorization.
- Treat discovered names as leads; validate ownership and exposure separately.
- Use conservative DNS query rates until you understand resolver and target load.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the HTTP validation
target to localhost only. The DNS service is present for local target realism
and validation exercises inside Docker.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.52.220.10` | Runs `amass`, `curl`, `jq`, and stores output. |
| `target` | `172.52.220.20` | Local DNS resolver and HTTP validation target. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18098` | `target:8080` | Local validation target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/amass/docker-compose.yml up --build -d
docker compose -f labs/amass/docker-compose.yml ps
docker compose -f labs/amass/docker-compose.yml exec scanner amass -version
```

Open the validation target:

```bash
open http://127.0.0.1:18098/health
```

Clean up when finished:

```bash
docker compose -f labs/amass/docker-compose.yml down
```

## List Data Sources

Amass can list the data sources compiled into the tool:

```bash
docker compose -f labs/amass/docker-compose.yml exec scanner \
  amass enum -list -nocolor
```

Some sources require API keys or real internet-visible domains. Source listing
can take a moment because Amass initializes its data-source registry.

## Local Discovery Workflow

The helper script writes a deterministic local enumeration fixture to
`outputs/enum.txt`, filters it to scope, and validates each allowed hostname
against the local HTTP target:

```bash
sh labs/amass/make_scans.sh
```

Expected discoveries include `admin`, `api`, `dev`, `mail`, `status`, `vpn`,
and `www` under `packetlab.local`. The words `cdn` and `portal` are
intentionally in the wordlist but not in the fixture, so you can practice
distinguishing guesses from confirmed names.

The generated `outputs/local-enum-note.txt` records why this lab uses a fixture
instead of claiming that Amass completed a private-resolver brute force.

## Validate Discoveries

Validate one discovered hostname against the local HTTP target:

```bash
docker compose -f labs/amass/docker-compose.yml exec scanner \
  curl -i -H "Host: api.packetlab.local" http://172.52.220.20:8080/
```

The expected response is JSON from the local API validation surface.

## Filter Output

Filter local enumeration output to the allowed scope:

```bash
docker compose -f labs/amass/docker-compose.yml exec scanner \
  sh -c 'grep -E "^[A-Za-z0-9_.-]+\\.packetlab\\.local$" outputs/enum.txt | sort -u | comm -12 scope/allow-subdomains.txt -'
```

## Useful Options

| Option | Use |
| --- | --- |
| `enum` | Perform enumeration and network mapping. |
| `intel` | Discover targets for future enumeration. |
| `-d DOMAIN` | Domain to enumerate. |
| `-df FILE` | Read domains from a file. |
| `-active` | Enable active checks such as DNS/certificate grabs. |
| `-brute` | Run DNS brute forcing. |
| `-w FILE` | Wordlist for brute forcing. |
| `-r IP` | Resolver to use for real enumeration workflows. |
| `-tr IP` | Trusted resolver for real enumeration workflows. |
| `-dns-qps 20` | Limit DNS query rate. |
| `-timeout 1` | Limit runtime in minutes. |
| `-norecursive` | Disable recursive brute forcing. |
| `-include SOURCE` | Include selected data sources. |
| `-exclude SOURCE` | Exclude selected data sources. |
| `-o FILE` | Save text output. |
| `-log FILE` | Save log output. |
| `-list` | List available data sources. |

## Generate Practice Outputs

Run a quick Amass workflow:

```bash
sh labs/amass/make_scans.sh
```

This writes version output, source listing, local enumeration output, filtered
subdomain lists, local validation results, and a TSV summary into
`labs/amass/outputs`.

## Practice Tasks

1. List Amass data sources and identify which ones would need external data or keys.
2. Compare `fixtures/enum.txt` to `wordlists/names.txt` and explain which guesses resolved.
3. Explain why `cdn.packetlab.local` and `portal.packetlab.local` are not in the confirmed output.
4. Validate `api.packetlab.local` and `admin.packetlab.local` with `curl`.
5. Compare `outputs/enum.txt`, `outputs/subdomains.txt`, and `outputs/in-scope.txt`.
6. Adjust `-dns-qps` and describe why rate control matters.
7. Write a safe Amass command for a domain you are authorized to assess.

## Troubleshooting

If the local fixture workflow finds no names, confirm the target containers are
running and check the target logs:

```bash
docker compose -f labs/amass/docker-compose.yml logs target
```

If validation cannot connect, confirm the HTTP target is healthy:

```bash
docker compose -f labs/amass/docker-compose.yml exec scanner \
  curl -sS http://172.52.220.20:8080/health | jq .
```

If Compose reports that port `18098` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18098:8080` to `127.0.0.1:28098:8080`.
