# Enum4linux-ng Guide And Local Samba Enumeration Lab

This lab teaches `enum4linux-ng` against a deliberately small local Samba
server. You can practice SMB target enumeration, authenticated checks, share
discovery, JSON output, and failed-authentication review without touching a
real network.

`enum4linux-ng` automates a set of SMB/RPC enumeration checks. Those checks can
reveal sensitive host, domain, user, group, and share information. This lab
keeps the target on a private Docker network and uses toy users, toy shares,
and toy files.

## Safety Rules

- Run `enum4linux-ng` only against systems you own or have explicit permission to assess.
- Keep targets, usernames, passwords, output files, and scan depth inside scope.
- Do not enumerate production SMB hosts or domain controllers without written authorization.
- Treat discovered names, shares, users, and groups as sensitive information.
- Use authenticated checks only with credentials you are authorized to use.
- Keep this lab on the private Docker network unless your authorization covers another target.

## Lab Topology

The Compose file creates a private Docker bridge network. No SMB port is
published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.65.87.10` | Runs `enum4linux-ng`, `smbclient`, `jq`, and stores output. |
| `target` | `172.65.87.20` | Runs Samba with toy users, groups, and shares. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated text output, JSON output, validation, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml up --build -d
docker compose -f labs/enum4linux-ng/docker-compose.yml ps
docker compose -f labs/enum4linux-ng/docker-compose.yml exec scanner enum4linux-ng --help
```

Clean up when finished:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml down
```

## Local Credentials

The target intentionally accepts these local lab credentials:

```text
labuser:labpass!
auditor:auditpass!
```

Use only these toy credentials in this lab.

## Basic Usage

Run full local enumeration with the lab credential:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml exec scanner \
  enum4linux-ng -A 172.65.87.20 -u labuser -p 'labpass!'
```

Write JSON output:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml exec scanner \
  enum4linux-ng -A 172.65.87.20 -u labuser -p 'labpass!' -oJ outputs/authenticated
```

Run a share-focused check:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml exec scanner \
  enum4linux-ng -S 172.65.87.20 -u labuser -p 'labpass!'
```

Compare with `smbclient`:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml exec scanner \
  smbclient -L //172.65.87.20 -U 'labuser%labpass!' -m SMB3
```

## Useful Options

| Option | Use |
| --- | --- |
| `-A` | Run all common enumeration checks. |
| `-S` | Enumerate SMB shares. |
| `-u USER` | Provide a username. |
| `-p PASS` | Provide a password. |
| `-oJ PREFIX` | Write JSON output using the given prefix. |
| `-oY PREFIX` | Write YAML output using the given prefix. |
| `-v` | Increase output verbosity. |
| `--help` | Show available checks and options. |

## Generate Practice Outputs

Run a quick enum4linux-ng workflow:

```bash
sh labs/enum4linux-ng/make_scans.sh
```

This writes help/banner output, authenticated full enumeration, share-focused
enumeration, JSON output, failed-auth output, validation results, and a TSV
summary into `labs/enum4linux-ng/outputs`.

## Practice Tasks

1. Run `enum4linux-ng --help` and identify which flags map to share checks.
2. Run `-S` and identify `labshare` and `reports`.
3. Run `-A` and look for the target name `ENUM4LAB`.
4. Save JSON output with `-oJ` and inspect it with `jq`.
5. Try a bad password and compare failure output.
6. Compare enum4linux-ng share output with `smbclient -L`.
7. Write a safe enum4linux-ng command for a host you are authorized to assess.

## Troubleshooting

If enum4linux-ng cannot connect, confirm SMB is reachable from the scanner:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml exec scanner nc -z 172.65.87.20 445
```

If share output is missing, confirm the Samba target is healthy:

```bash
docker compose -f labs/enum4linux-ng/docker-compose.yml logs target
```

If JSON output changes in a future tool version, inspect
`outputs/authenticated.txt` and `outputs/authenticated.json`, then update the
validation markers to match the new output shape.
