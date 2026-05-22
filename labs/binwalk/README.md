# Binwalk Guide And Local Firmware Lab

This lab teaches Binwalk signature scanning, filtered scans, entropy review,
safe extraction, hash recording, and extracted-file triage using a generated
firmware-like fixture. It does not download firmware or analyze any real
device image.

Binwalk is commonly used to inspect firmware and other binary blobs for
embedded filesystems, archives, compressed streams, bootloaders, certificates,
and other artifacts. Real firmware may contain secrets, keys, credentials,
proprietary code, or license-restricted content. This lab uses harmless local
fixtures so you can practice the workflow safely.

## Safety Rules

- Analyze only firmware or binaries you own or have explicit permission to examine.
- Treat extracted files, configuration values, keys, and certificates as sensitive.
- Keep extraction inside a controlled lab directory.
- Do not execute extracted binaries or scripts from unknown firmware.
- Record hashes before extraction or modification.
- Delete generated outputs when they are no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs Binwalk, fixture generation, `file`, `tar`, `gzip`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated firmware-like binary fixture. |
| `outputs` | Generated scans, extracted files, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/binwalk/docker-compose.yml up --build -d
docker compose -f labs/binwalk/docker-compose.yml ps
docker compose -f labs/binwalk/docker-compose.yml exec scanner binwalk -h
```

Clean up when finished:

```bash
docker compose -f labs/binwalk/docker-compose.yml down
```

## Local Fixture

The helper creates `fixtures/packetlab-firmware.bin`, a deterministic local
binary with known embedded artifacts:

| Offset | Artifact |
| --- | --- |
| `0x400` | Gzip-compressed tar archive with a tiny local rootfs. |
| `0x2000` | Tiny PNG icon used for signature scanning practice. |

The extracted rootfs contains:

| Path | Purpose |
| --- | --- |
| `etc/device.conf` | Local configuration fixture for review. |
| `www/index.html` | Local web UI fixture. |
| `bin/startup.sh` | Harmless shell script fixture for permission review. |

## Basic Usage

Show Binwalk options:

```bash
docker compose -f labs/binwalk/docker-compose.yml exec scanner binwalk -h
```

Generate the local firmware fixture:

```bash
docker compose -f labs/binwalk/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py \
  fixtures outputs/fixture-manifest.json outputs/expected-files.tsv
```

Scan for embedded signatures:

```bash
docker compose -f labs/binwalk/docker-compose.yml exec scanner \
  binwalk fixtures/packetlab-firmware.bin
```

Filter expected signatures:

```bash
docker compose -f labs/binwalk/docker-compose.yml exec scanner \
  binwalk -y 'gzip|PNG' fixtures/packetlab-firmware.bin
```

Extract inside a controlled output directory:

```bash
docker compose -f labs/binwalk/docker-compose.yml exec scanner \
  binwalk -e --run-as=root -C outputs/extracted fixtures/packetlab-firmware.bin
```

## Useful Options

| Option | Use |
| --- | --- |
| `-B`, `--signature` | Run the standard signature scan. |
| `-y PATTERN` | Include only signatures matching a pattern. |
| `-x PATTERN` | Exclude signatures matching a pattern. |
| `-e`, `--extract` | Extract known embedded file types. |
| `-C DIR` | Choose an extraction directory. |
| `-M`, `--matryoshka` | Recursively scan extracted files. |
| `-d NUM` | Limit recursive extraction depth. |
| `-E`, `--entropy` | Calculate entropy for packed/compressed-region review. |
| `--run-as USER` | Set extraction utility user when running as root in Docker. |

## Generate Practice Outputs

Run a quick Binwalk workflow:

```bash
docker compose -f labs/binwalk/docker-compose.yml up --build -d
sh labs/binwalk/make_scans.sh
```

This writes help/version output, a generated firmware fixture, hashes,
signature and filtered scans, entropy output, extraction logs, extracted-file
lists, rootfs review output, validation results, and a TSV summary into
`labs/binwalk/outputs`.

## Practice Tasks

1. Run `binwalk fixtures/packetlab-firmware.bin` and identify the offsets.
2. Compare `outputs/signature-scan.txt` with `outputs/include-filter.txt`.
3. Review `outputs/fixture-manifest.json` and confirm the expected offsets.
4. Inspect `outputs/extracted-files.txt` and identify the carved rootfs archive.
5. Review `outputs/rootfs-files.txt` and `outputs/device-conf.txt`.
6. Compare `outputs/firmware-sha256.txt` before and after regenerating the fixture.
7. Write a safe triage checklist for firmware you are authorized to analyze.

## Real Firmware Note

For real firmware, keep the original image read-only, record hashes, extract
into a dedicated directory, and review extracted scripts or binaries as data.
Do not run extracted components unless you are inside an appropriate malware or
firmware-analysis sandbox and have authorization to do so.

## Troubleshooting

If extraction produces only carved streams, inspect the carved file with
`file`, then list archives manually:

```bash
docker compose -f labs/binwalk/docker-compose.yml exec scanner \
  sh -c 'file outputs/extracted/_packetlab-firmware.bin.extracted/* && tar -tf outputs/extracted/_packetlab-firmware.bin.extracted/rootfs.tar'
```

If Binwalk refuses extraction while running as root, include `--run-as=root` in
this Docker-only lab.

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/binwalk/docker-compose.yml down
docker compose -f labs/binwalk/docker-compose.yml up --build -d
```
