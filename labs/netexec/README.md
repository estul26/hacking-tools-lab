# NetExec Guide And Local SSH/SMB Lab

This lab teaches NetExec (`nxc`) against deliberately small local SSH and SMB
services. You can practice protocol selection, target formatting,
credential-check output review, and SMB share enumeration without touching a
real network.

NetExec is a network assessment tool for many protocols. It can authenticate to
services and automate post-authentication checks. This lab keeps everything on
an isolated Docker bridge network and uses one toy credential pair.

## Safety Rules

- Use NetExec only on systems you own or have explicit permission to assess.
- Keep targets, protocols, usernames, passwords, modules, and thread counts inside scope.
- Do not run credential sprays, command execution, hash collection, or module actions against real networks without written authorization.
- Treat credentials found during authorized work as sensitive secrets.
- Keep this lab on the private Docker network unless your authorization covers another target.

## Lab Topology

The Compose file creates a private Docker bridge network. No target ports are
published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.61.83.10` | Runs NetExec, `nc`, `curl`, `jq`, and stores output. |
| `target` | `172.61.83.20` | Runs local SSH and SMB services with toy credentials. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated help, protocol checks, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/netexec/docker-compose.yml up --build -d
docker compose -f labs/netexec/docker-compose.yml ps
docker compose -f labs/netexec/docker-compose.yml exec scanner nxc --version
```

Clean up when finished:

```bash
docker compose -f labs/netexec/docker-compose.yml down
```

## Local Credentials

The target intentionally accepts one local lab credential:

```text
labuser:labpass!
```

Use only these toy credentials in this lab.

## Basic Usage

Show available protocols:

```bash
docker compose -f labs/netexec/docker-compose.yml exec scanner nxc --help
```

Show protocol-specific options:

```bash
docker compose -f labs/netexec/docker-compose.yml exec scanner nxc ssh --help
docker compose -f labs/netexec/docker-compose.yml exec scanner nxc smb --help
```

Check SSH authentication against the local target:

```bash
docker compose -f labs/netexec/docker-compose.yml exec scanner \
  nxc ssh 172.61.83.20 -u labuser -p 'labpass!'
```

Check SMB authentication and list local lab shares:

```bash
docker compose -f labs/netexec/docker-compose.yml exec scanner \
  nxc smb 172.61.83.20 -u labuser -p 'labpass!' --shares
```

Try a bad password to compare failure output:

```bash
docker compose -f labs/netexec/docker-compose.yml exec scanner \
  nxc smb 172.61.83.20 -u labuser -p wrong-password
```

## Useful Options

| Option | Use |
| --- | --- |
| `ssh` | Select the SSH protocol module. |
| `smb` | Select the SMB protocol module. |
| `TARGET` | Use an IP, hostname, range, CIDR, or target file. |
| `-u USER` | Provide one username. |
| `-p PASS` | Provide one password. |
| `--shares` | Enumerate SMB shares after successful authentication. |
| `--continue-on-success` | Continue checking after a success; keep scoped and cautious. |
| `--dns-server IP` | Use a specific DNS server for name resolution. |

## Generate Practice Outputs

Run a quick NetExec workflow:

```bash
sh labs/netexec/make_scans.sh
```

This writes help/version output, SSH and SMB success/failure checks, SMB share
enumeration, validation results, and a TSV summary into `labs/netexec/outputs`.

## Practice Tasks

1. Run `nxc --help` and identify the protocol list.
2. Compare `nxc ssh --help` and `nxc smb --help`.
3. Check SSH with the toy credential and then with a bad password.
4. Check SMB with the toy credential and list shares.
5. Explain the difference between authentication success and share access.
6. Inspect `outputs/validation.tsv` after running the helper.
7. Write a safe NetExec command for an asset you are authorized to assess.

## Troubleshooting

If NetExec cannot connect, confirm both target ports are reachable from the
scanner:

```bash
docker compose -f labs/netexec/docker-compose.yml exec scanner nc -z 172.61.83.20 22
docker compose -f labs/netexec/docker-compose.yml exec scanner nc -z 172.61.83.20 445
```

If SMB share enumeration fails, confirm the target is still running:

```bash
docker compose -f labs/netexec/docker-compose.yml ps
```

If authentication output changes in a future NetExec version, inspect the raw
files in `outputs` and update the validation markers to match the new wording.
