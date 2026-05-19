# Responder Guide And Local Analyze-Mode Lab

This lab teaches Responder with an isolated Docker network and synthetic local
name-resolution traffic. You can practice interface selection, analyze mode,
log review, and LLMNR/NBT-NS/mDNS visibility without poisoning a real network
or collecting real credentials.

Responder can poison broadcast and multicast name-resolution traffic and run
rogue authentication services. This lab intentionally uses `-A` analyze mode,
which observes requests without answering them.

## Safety Rules

- Use Responder only on networks you own or have explicit permission to assess.
- Prefer `-A` analyze mode while learning.
- Do not run poisoning, WPAD, DHCP, DHCPv6, proxy-auth, or downgrade options on real networks without written authorization.
- Do not capture, store, or share real credentials or hashes.
- Keep experiments inside this Docker lab unless your authorization covers another network.
- Delete generated logs when they are no longer needed.

## Lab Topology

The Compose file creates a private Docker bridge network. No Responder service
is published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `responder` | `172.60.82.10` | Runs Responder in analyze mode and stores output. |
| `client` | `172.60.82.20` | Sends synthetic LLMNR, mDNS, and NBNS lab queries. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated help, version, analyze logs, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/responder/docker-compose.yml up --build -d
docker compose -f labs/responder/docker-compose.yml ps
docker compose -f labs/responder/docker-compose.yml exec responder responder --version
```

Clean up when finished:

```bash
docker compose -f labs/responder/docker-compose.yml down
```

## Analyze Mode

Run Responder passively on the lab interface:

```bash
docker compose -f labs/responder/docker-compose.yml exec responder \
  responder -I eth0 -A -v
```

The `-A` option is analyze mode. It watches for name-resolution traffic without
poisoning responses.

In another terminal, send synthetic lab queries:

```bash
docker compose -f labs/responder/docker-compose.yml exec client \
  python /opt/lab/query_client.py
```

The client uses toy names such as `wpad-lab`, `files-lab`, and `printer-lab`.

## Useful Options

| Option | Use |
| --- | --- |
| `-I eth0` | Select the interface to monitor. |
| `-A` | Analyze mode; observe requests without poisoning. |
| `-v` | Verbose output. |
| `-Q` | Quiet output. |
| `-w` | Start WPAD rogue proxy behavior. Do not use outside authorized labs. |
| `-d` | DHCPv4 poisoning. Do not use outside authorized labs. |
| `--dhcpv6` | DHCPv6 poisoning. This can disrupt networks. |
| `-P` | Force proxy authentication. Do not use outside authorized labs. |

## Generate Practice Outputs

Run a quick Responder workflow:

```bash
sh labs/responder/make_scans.sh
```

This writes help/version output, interface details, passive analyze logs,
client output, validation results, and a TSV summary into
`labs/responder/outputs`.

## Practice Tasks

1. Run `responder -h` and identify the analyze-mode option.
2. Start Responder with `-I eth0 -A -v`.
3. Run the synthetic query client and inspect the analyze log.
4. Explain why analyze mode is safer than poisoning mode.
5. Identify LLMNR, mDNS, or NBT-NS entries in `outputs/analyze.log`.
6. Confirm no real credentials are present in generated outputs.
7. Write a safe Responder command for a network you are authorized to assess.

## Troubleshooting

If no synthetic names appear, rerun the helper after confirming both containers
are up:

```bash
docker compose -f labs/responder/docker-compose.yml ps
sh labs/responder/make_scans.sh
```

If Responder cannot bind to the interface, confirm the `responder` service has
`NET_ADMIN` and `NET_RAW` capabilities in `docker-compose.yml`.

If you are on a real network, stop and return to the Docker lab unless you have
explicit authorization.
