# Airodump-ng Guide And Local Wireless-Metadata Replay Lab

This lab teaches `airodump-ng` with a local offline 802.11 beacon fixture. You
can practice help review, capture output formats, BSSID filtering, CSV/netxml
inspection, and monitor-mode failure handling without using a wireless adapter
or touching any real Wi-Fi network.

`airodump-ng` is a live wireless packet collector. Real use requires a
compatible Wi-Fi adapter in monitor mode and explicit authorization for the
network being observed. This Docker lab uses `airodump-ng -r` to replay a
synthetic pcap file and write real airodump-style output files.

## Safety Rules

- Capture only wireless networks you own or have explicit permission to assess.
- Do not capture, deauthenticate, inject, crack, or share real wireless traffic outside scope.
- Treat BSSIDs, ESSIDs, client MACs, captures, and recovered keys as sensitive data.
- Use monitor mode only in an authorized lab with clear channel and power limits.
- Keep this lab offline unless your authorization covers a real capture or test network.
- Do not use discovered network metadata to access or target systems without permission.

## Lab Topology

This Compose lab uses one scanner container and local mounted outputs. It does
not require a Wi-Fi adapter and does not create radio traffic.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `airodump-ng`, `airmon-ng`, Python fixture generation, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated pcap fixture, CSV/netxml output, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/airodump-ng/docker-compose.yml up --build -d
docker compose -f labs/airodump-ng/docker-compose.yml ps
docker compose -f labs/airodump-ng/docker-compose.yml exec scanner airodump-ng --help
```

Clean up when finished:

```bash
docker compose -f labs/airodump-ng/docker-compose.yml down
```

## Local Fixture

The helper generates a synthetic beacon pcap with two toy access points:

| BSSID | Channel | Privacy | ESSID |
| --- | --- | --- | --- |
| `02:11:22:33:44:55` | `6` | `WEP` | `PacketLab-WEP` |
| `02:AA:BB:CC:DD:EE` | `11` | `WPA2` | `PacketLab-WPA2` |

These are fake local frames for metadata practice only.

## Basic Usage

Generate the local pcap fixture:

```bash
docker compose -f labs/airodump-ng/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_capture.py outputs/packetlab-beacons.pcap
```

Replay the fixture and write CSV plus Kismet netxml output:

```bash
docker compose -f labs/airodump-ng/docker-compose.yml exec scanner \
  timeout 2s airodump-ng -r outputs/packetlab-beacons.pcap \
  --write outputs/airodump --output-format csv,netxml
```

Filter to one BSSID:

```bash
docker compose -f labs/airodump-ng/docker-compose.yml exec scanner \
  timeout 2s airodump-ng -r outputs/packetlab-beacons.pcap \
  --bssid 02:11:22:33:44:55 \
  --write outputs/filtered --output-format csv
```

Confirm Docker has no monitor-mode Wi-Fi interface:

```bash
docker compose -f labs/airodump-ng/docker-compose.yml exec scanner \
  timeout 3s airodump-ng --write outputs/no-radio --output-format csv wlan0mon
```

## Useful Options

| Option | Use |
| --- | --- |
| `-r FILE` | Read packets from an existing capture file. |
| `--write PREFIX` | Write captured/replayed output files with a prefix. |
| `--output-format csv,netxml` | Select output formats. |
| `--bssid BSSID` | Filter to one access point. |
| `--essid ESSID` | Filter to one network name. |
| `--channel N` | Capture or filter by channel during live use. |
| `--band abg` | Select wireless bands during live use. |
| `--manufacturer` | Display OUI manufacturer names when available. |
| `--wps` | Display WPS information when present. |
| `--write-interval N` | Set output file write interval. |

## Generate Practice Outputs

Run a quick Airodump-ng workflow:

```bash
sh labs/airodump-ng/make_scans.sh
```

This writes help/version output, a generated 802.11 pcap fixture, CSV/netxml
replay output, BSSID-filtered output, monitor-interface failure output,
validation results, parsed access-point TSV/JSON, and a TSV summary into
`labs/airodump-ng/outputs`.

## Practice Tasks

1. Run `airodump-ng --help` and identify replay, write, and filter options.
2. Generate the local pcap fixture and replay it with `-r`.
3. Inspect `outputs/airodump-01.csv` and identify channel, privacy, cipher, and ESSID.
4. Filter to `02:11:22:33:44:55` and compare `filtered-01.csv`.
5. Inspect `outputs/airodump-01.kismet.netxml`.
6. Read `outputs/no-monitor-interface.txt` and explain why Docker has no live Wi-Fi target.
7. Write a safe Airodump-ng command for a wireless lab you are authorized to observe.

## Live Wireless Note

Live `airodump-ng` capture usually needs a compatible Wi-Fi adapter, monitor
mode, local regulatory compliance, and explicit authorization. Docker on macOS
does not provide direct access to host Wi-Fi hardware, so this lab intentionally
uses offline replay instead of live capture or packet injection.

## Troubleshooting

If CSV output is missing, regenerate the fixture and rerun the helper:

```bash
sh labs/airodump-ng/make_scans.sh
```

If `airodump-ng` reports `No such device`, that is expected for `wlan0mon`
inside this Docker lab. Use the offline `-r outputs/packetlab-beacons.pcap`
workflow unless you are on a dedicated wireless lab machine with an authorized
monitor-mode adapter.

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/airodump-ng/docker-compose.yml down
docker compose -f labs/airodump-ng/docker-compose.yml up --build -d
```
