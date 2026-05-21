# Evil-WinRM Guide And Local WinRM-Style Lab

This lab teaches `evil-winrm` command setup, WinRM endpoint checks, output
review, and safe failure handling against a local WinRM-style target. The
target is a deliberately small HTTP service that exposes `/wsman`, requires
authentication, records request metadata, and returns SOAP faults instead of
creating a Windows shell.

`evil-winrm` is a remote shell tool for authorized Windows Remote Management
access. A full interactive Evil-WinRM session requires a real Windows WinRM
service and valid credentials. This Docker lab keeps practice local and safe by
using a mock endpoint for reachability, authentication challenge review, request
logging, and command hygiene.

## Safety Rules

- Use Evil-WinRM only against Windows hosts you own or have explicit permission to administer or assess.
- Keep target IPs, ports, URLs, usernames, passwords, hashes, certificates, scripts, and executables inside scope.
- Do not upload tools, run commands, dump secrets, or change host state without written authorization.
- Treat credentials, hashes, tickets, and session logs as sensitive secrets.
- Prefer a test host or lab VM before touching production systems.
- Keep this lab on the private Docker network unless your authorization covers another target.

## Lab Topology

The Compose file creates a private Docker bridge network. No WinRM port is
published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.67.89.10` | Runs `evil-winrm`, `curl`, `jq`, `nc`, and stores output. |
| `target` | `172.67.89.20` | Runs a local WinRM-style `/wsman` HTTP endpoint on port `5985`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated help, endpoint checks, target event logs, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml up --build -d
docker compose -f labs/evil-winrm/docker-compose.yml ps
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner evil-winrm -h
```

Clean up when finished:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml down
```

## Local Credentials

The mock target accepts these credentials for direct `curl` checks:

```text
labadmin:LabPass2026!
```

Evil-WinRM normally uses NTLM/Negotiate, Kerberos, certificate, or hash-based Windows
authentication. The local mock target records the Evil-WinRM attempt but does
not complete a real Windows shell login.

## Basic Usage

Show Evil-WinRM options:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner evil-winrm -h
```

Check the local target health endpoint:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner \
  curl -sS http://172.67.89.20:5985/health | jq .
```

Confirm `/wsman` requires authentication:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner \
  curl -i http://172.67.89.20:5985/wsman
```

Send a local authenticated SOAP request and review the safe mock fault:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner \
  curl -i -u 'labadmin:LabPass2026!' \
  -H 'Content-Type: application/soap+xml;charset=UTF-8' \
  --data '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body/></s:Envelope>' \
  http://172.67.89.20:5985/wsman
```

Attempt Evil-WinRM against the local endpoint and review the recorded failure:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner \
  evil-winrm -i 172.67.89.20 -P 5985 -U /wsman -u labadmin -p 'LabPass2026!' -n
```

For a real authorized Windows target, the shape is similar:

```bash
evil-winrm -i 192.0.2.10 -u USER -p 'PASSWORD'
```

## Useful Options

| Option | Use |
| --- | --- |
| `-i IP` | Target host or FQDN. |
| `-u USER` | Username for password or hash authentication. |
| `-p PASS` | Password authentication. |
| `-H HASH` | NT hash authentication. |
| `-P PORT` | Target WinRM port, usually `5985` or `5986`. |
| `-S` | Use SSL, commonly with port `5986`. |
| `-U URL` | WinRM endpoint path, default `/wsman`. |
| `-r REALM` | Kerberos realm. |
| `-K TICKET` | Kerberos ccache or kirbi ticket. |
| `-s PATH` | Local PowerShell scripts directory. |
| `-e PATH` | Local executables directory. |
| `-l` | Log the WinRM session. |
| `-n` | Disable colors for cleaner output files. |

## Generate Practice Outputs

Run a quick Evil-WinRM workflow:

```bash
sh labs/evil-winrm/make_scans.sh
```

This writes help/version output, WinRM-style HTTP checks, a bounded Evil-WinRM
connection attempt, target request events, validation results, and a TSV
summary into `labs/evil-winrm/outputs`.

## Practice Tasks

1. Run `evil-winrm -h` and identify password, hash, Kerberos, and certificate options.
2. Confirm port `5985` is reachable only inside the Docker network.
3. Compare unauthenticated `/wsman` output with the authenticated SOAP fault.
4. Run the bounded Evil-WinRM attempt and inspect `outputs/evil-winrm-attempt.txt`.
5. Inspect `outputs/target-events.json` and identify the user-agent and auth type.
6. Explain why a real interactive shell requires a real Windows WinRM service.
7. Write a safe Evil-WinRM command for a Windows host you are authorized to access.

## Troubleshooting

If Evil-WinRM cannot connect, confirm the local WinRM-style port is reachable
from the scanner:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner nc -vz 172.67.89.20 5985
```

If target events are missing, confirm the target is healthy:

```bash
docker compose -f labs/evil-winrm/docker-compose.yml exec scanner \
  curl -sS http://172.67.89.20:5985/events | jq .
```

If you are testing a real authorized Windows host, verify firewall rules,
listener configuration, HTTP vs HTTPS, port `5985` vs `5986`, and whether your
credential type is password, NT hash, Kerberos ticket, or certificate.
