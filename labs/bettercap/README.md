# Bettercap Guide And Local Network Discovery Lab

This lab teaches Bettercap in a controlled Docker network with toy targets. You
can practice non-interactive Bettercap commands, module help review, local host
discovery, bounded SYN scanning, interface review, and output validation
without touching your real LAN.

Bettercap is a powerful network assessment framework. Some modules can perform
man-in-the-middle positioning, spoofing, proxying, sniffing, and credential
capture. This lab intentionally uses discovery and bounded scan commands only.
Authorization-sensitive modules such as `arp.spoof`, `dns.spoof`,
`http.proxy`, and `net.sniff` are not enabled by the helper.

## Safety Rules

- Use Bettercap only on networks and systems you own or have explicit permission to assess.
- Keep interfaces, subnets, targets, modules, and scan ranges inside scope.
- Do not enable spoofing, proxying, sniffing, or credential capture on real networks without written authorization.
- Treat discovery output, host metadata, and captured traffic as sensitive data.
- Prefer this private Docker lab before experimenting with Bettercap on any real interface.
- Stop modules and containers when finished.

## Lab Topology

The Compose file creates a private Docker bridge network. No target ports are
published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.68.90.10` | Runs Bettercap, `curl`, `jq`, `nc`, and stores output. |
| `target-web` | `172.68.90.20` | Runs toy HTTP services on TCP `80` and `8080`. |
| `target-services` | `172.68.90.30` | Runs toy banner services on TCP `2222` and `2525`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated Bettercap output, baselines, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/bettercap/docker-compose.yml up --build -d
docker compose -f labs/bettercap/docker-compose.yml ps
docker compose -f labs/bettercap/docker-compose.yml exec scanner bettercap -version
```

Clean up when finished:

```bash
docker compose -f labs/bettercap/docker-compose.yml down
```

## Basic Usage

Show Bettercap CLI flags:

```bash
docker compose -f labs/bettercap/docker-compose.yml exec scanner bettercap -h
```

Review safe discovery module help:

```bash
docker compose -f labs/bettercap/docker-compose.yml exec scanner \
  bettercap -no-colors -eval "help net.recon; help net.probe; help syn.scan; quit"
```

Run a short local discovery session:

```bash
docker compose -f labs/bettercap/docker-compose.yml exec scanner \
  bettercap -no-colors -eval \
  "set net.probe.throttle 50; net.probe on; sleep 4; net.show; quit"
```

Run a bounded SYN scan against a toy target:

```bash
docker compose -f labs/bettercap/docker-compose.yml exec scanner \
  bettercap -no-colors -eval \
  "syn.scan 172.68.90.20 70 90; sleep 1; quit"
```

Compare with simple baseline checks:

```bash
docker compose -f labs/bettercap/docker-compose.yml exec scanner nc -z 172.68.90.20 80
docker compose -f labs/bettercap/docker-compose.yml exec scanner nc -z 172.68.90.30 2222
```

## Useful Commands

| Command | Use |
| --- | --- |
| `-eval "COMMANDS"` | Run Bettercap commands non-interactively. |
| `-no-colors` | Save cleaner output files. |
| `help MODULE` | Show module-specific help. |
| `net.probe on` | Probe the local subnet for hosts. |
| `net.recon on` | Read ARP cache and track endpoints. |
| `net.show` | Display discovered endpoints. |
| `syn.scan IP START END` | Run a bounded SYN scan. |
| `syn.scan.progress` | Show SYN scan progress. |
| `quit` | Exit the Bettercap session. |

## Sensitive Modules

These modules can affect other systems and should stay off unless you have
explicit written authorization and a controlled lab:

| Module | Risk |
| --- | --- |
| `arp.spoof` | Can position the scanner between hosts. |
| `dns.spoof` | Can redirect name resolution. |
| `http.proxy` / `https.proxy` | Can intercept or modify traffic. |
| `net.sniff` | Can capture sensitive network traffic. |
| `wifi` | Requires authorized wireless hardware and scope. |

## Generate Practice Outputs

Run a quick Bettercap workflow:

```bash
sh labs/bettercap/make_scans.sh
```

This writes help/version output, interface and route info, target health
checks, safe module help, Bettercap discovery/SYN-scan output, baseline port
TSV/JSON, validation results, and a TSV summary into
`labs/bettercap/outputs`.

## Practice Tasks

1. Run `bettercap -h` and identify non-interactive flags.
2. Review `outputs/safe-modules.txt`.
3. Compare `outputs/bettercap-discovery.txt` with `outputs/port-baseline.tsv`.
4. Change the SYN scan range to exclude `80` and compare output.
5. Inspect `outputs/interfaces.txt` and identify the scanner interface.
6. Explain why spoofing and sniffing modules are not enabled by this helper.
7. Write a safe Bettercap command for a network you are authorized to assess.

## Troubleshooting

If Bettercap sees no targets, confirm the toy services are reachable:

```bash
docker compose -f labs/bettercap/docker-compose.yml exec scanner nc -z 172.68.90.20 80
docker compose -f labs/bettercap/docker-compose.yml exec scanner nc -z 172.68.90.30 2222
```

If Bettercap reports permission errors, confirm the scanner has `NET_ADMIN`
and `NET_RAW`:

```bash
docker compose -f labs/bettercap/docker-compose.yml config | grep -A4 cap_add
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/bettercap/docker-compose.yml down
docker compose -f labs/bettercap/docker-compose.yml up --build -d
```
