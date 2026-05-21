# Aireplay-ng Guide And Local No-Radio Injection-Safety Lab

This lab teaches `aireplay-ng` option review, attack-mode identification,
command planning, local pcap source handling, and monitor-interface failure
review without using a wireless adapter or sending any radio traffic.

`aireplay-ng` is a live wireless packet injection and replay tool. Real use can
disrupt networks, disconnect clients, or generate unauthorized traffic. Docker
on macOS does not provide monitor-mode Wi-Fi hardware, so this lab intentionally
records the expected no-radio failures and keeps all fixtures local.

## Safety Rules

- Use Aireplay-ng only in a wireless lab you own or have explicit written permission to test.
- Do not deauthenticate, inject, replay, or forge frames on real networks outside scope.
- Treat BSSIDs, station MACs, captures, and replay plans as sensitive assessment data.
- Use monitor mode and injection tests only with approved adapters, channels, and power limits.
- Keep this lab offline unless your authorization covers a real wireless test network.
- Do not use packet injection to disrupt availability or bypass access controls.

## Lab Topology

This Compose lab uses one scanner container and local mounted outputs. It does
not require a Wi-Fi adapter and does not create radio traffic.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `aireplay-ng`, `airmon-ng`, Python fixture generation, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated pcap fixture, no-radio command output, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml up --build -d
docker compose -f labs/aireplay-ng/docker-compose.yml ps
docker compose -f labs/aireplay-ng/docker-compose.yml exec scanner aireplay-ng --help
```

Clean up when finished:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml down
```

## Local Fixture

The helper creates a tiny synthetic pcap with fake local frames:

| Item | Value |
| --- | --- |
| BSSID | `02:11:22:33:44:55` |
| Station | `02:66:77:88:99:AA` |
| Interface name | `wlan0mon` |

`wlan0mon` is intentionally absent inside Docker. The lab records that failure
so you can distinguish command-shape practice from live packet injection.

## Basic Usage

Show options and attack modes:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml exec scanner aireplay-ng --help
```

Generate the local source pcap:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_frames.py outputs/packetlab-replay-source.pcap
```

Run an injection test against the intentionally missing monitor interface:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml exec scanner \
  timeout 5s aireplay-ng --test wlan0mon
```

Plan a lab-only fake-auth command and observe the no-radio failure:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml exec scanner \
  timeout 5s aireplay-ng --fakeauth 0 \
  -a 02:11:22:33:44:55 -h 02:66:77:88:99:AA wlan0mon
```

Plan replay from a local pcap source and observe the no-radio failure:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml exec scanner \
  timeout 5s aireplay-ng --interactive \
  -r outputs/packetlab-replay-source.pcap wlan0mon
```

## Useful Options

| Option | Use |
| --- | --- |
| `--test` | Test injection capability and link quality on an authorized monitor interface. |
| `--fakeauth DELAY` | Send fake-authentication frames in a lab where you are authorized. |
| `--interactive` | Select packets interactively for replay. |
| `--deauth COUNT` | Send deauthentication frames; disruptive and authorization-sensitive. |
| `-a BSSID` | Set target access point MAC address. |
| `-h SMAC` | Set source station MAC address. |
| `-r FILE` | Read packets from a pcap file as a source. |
| `-i IFACE` | Capture packets from a second interface. |
| `--ignore-negative-one` | Ignore fixed-channel `-1` warnings in some driver setups. |
| `--deauth-rc RC` | Set deauthentication reason code. |

## Generate Practice Outputs

Run a quick Aireplay-ng workflow:

```bash
sh labs/aireplay-ng/make_scans.sh
```

This writes help/version output, a generated pcap source fixture, extracted
attack modes, planned lab-only commands, no-radio outputs for test/fakeauth/
replay-source attempts, validation results, and a TSV summary into
`labs/aireplay-ng/outputs`.

## Practice Tasks

1. Run `aireplay-ng --help` and identify filter, replay, source, and attack-mode options.
2. Inspect `outputs/attack-modes.tsv` and explain which modes are disruptive.
3. Generate `outputs/packetlab-replay-source.pcap` and confirm it is local.
4. Run `--test wlan0mon` and explain the no-radio failure.
5. Compare `fakeauth-no-radio.txt` and `replay-source-no-radio.txt`.
6. Inspect `outputs/command-plan.json`.
7. Write a safe Aireplay-ng command plan for a wireless lab you are authorized to operate.

## Live Wireless Note

Live `aireplay-ng` use requires a compatible Wi-Fi adapter, monitor mode,
driver support for injection, local regulatory compliance, and explicit
authorization. Docker on macOS does not provide direct access to host Wi-Fi
hardware, so this lab intentionally does not perform live injection.

## Troubleshooting

If `aireplay-ng` reports `No such device`, that is expected for `wlan0mon`
inside this Docker lab.

If generated outputs are missing, rerun the helper:

```bash
sh labs/aireplay-ng/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/aireplay-ng/docker-compose.yml down
docker compose -f labs/aireplay-ng/docker-compose.yml up --build -d
```
