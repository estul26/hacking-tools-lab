# Foremost Guide And Local File-Carving Lab

This lab teaches Foremost file carving with a generated local disk-image
fixture. You can practice selected-type carving, audit-only mode, quick mode,
recovered-file type checks, ZIP listing, hash recording, and validation without
touching real disks or personal data.

Foremost is a forensic file-carving tool. Real disk images and memory dumps can
contain credentials, personal files, deleted data, keys, and regulated
evidence. This lab uses harmless generated artifacts so you can learn the
workflow safely.

## Safety Rules

- Analyze only images and files you own or have explicit permission to examine.
- Treat carved files, paths, hashes, and audit reports as sensitive evidence.
- Carve into a dedicated output directory and keep originals read-only.
- Verify recovered file types before opening any carved content.
- Do not execute recovered files from unknown images.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs Foremost, fixture generation, `file`, `sha256sum`, `unzip`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated disk-image fixture. |
| `outputs` | Carved files, audit reports, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/foremost/docker-compose.yml up --build -d
docker compose -f labs/foremost/docker-compose.yml ps
docker compose -f labs/foremost/docker-compose.yml exec scanner foremost -h
```

Clean up when finished:

```bash
docker compose -f labs/foremost/docker-compose.yml down
```

## Local Fixture

The helper creates `fixtures/packetlab-disk.img`, a deterministic local image
with embedded artifacts at 512-byte-aligned offsets:

| Offset | Artifact |
| --- | --- |
| `0x1000` | Tiny PNG image. |
| `0x4000` | Tiny GIF image. |
| `0x8000` | ZIP archive with harmless local notes. |

Foremost names recovered files using block-style offsets, so the PNG at
`0x1000` appears as `00000008.png` because `0x1000 / 512 = 8`.

## Basic Usage

Show Foremost options:

```bash
docker compose -f labs/foremost/docker-compose.yml exec scanner foremost -h
```

Generate the local image:

```bash
docker compose -f labs/foremost/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Carve selected file types:

```bash
docker compose -f labs/foremost/docker-compose.yml exec scanner \
  foremost -i fixtures/packetlab-disk.img -o outputs/carved -t png,gif,zip
```

Write only an audit report:

```bash
docker compose -f labs/foremost/docker-compose.yml exec scanner \
  foremost -w -i fixtures/packetlab-disk.img -o outputs/audit-only -t png,gif,zip
```

Verify carved file types:

```bash
docker compose -f labs/foremost/docker-compose.yml exec scanner \
  file outputs/carved/*/*
```

## Useful Options

| Option | Use |
| --- | --- |
| `-i FILE` | Set the input image or file. |
| `-o DIR` | Set the output directory. |
| `-t TYPES` | Carve selected types such as `png,gif,zip`. |
| `-w` | Write only an audit file without recovered files. |
| `-q` | Quick mode for 512-byte boundary searches. |
| `-v` | Verbose mode. |
| `-c FILE` | Use a custom Foremost configuration file. |
| `-a` | Write all headers with less error checking. |

## Generate Practice Outputs

Run a quick Foremost workflow:

```bash
docker compose -f labs/foremost/docker-compose.yml up --build -d
sh labs/foremost/make_scans.sh
```

This writes help/version output, a generated image fixture, hashes, Foremost
carving logs, audit-only output, carved file lists, recovered file types, ZIP
contents, validation results, and a TSV summary into `labs/foremost/outputs`.

## Practice Tasks

1. Compare `outputs/fixture-manifest.json` with `outputs/carved-files.txt`.
2. Review `outputs/carved-file-types.txt` before opening recovered files.
3. Inspect `outputs/carved/audit.txt` and identify carved offsets.
4. Compare normal carving with `outputs/audit-only-files.txt`.
5. Review `outputs/zip-list.txt` without extracting or executing content.
6. Record the image hash from `outputs/image-sha256.txt`.
7. Write a safe carving checklist for an image you are authorized to analyze.

## Real Evidence Note

For real forensic images, keep originals read-only, record hashes, work from
copies where policy allows, and preserve audit logs. Carved files may be
partial, corrupted, private, or legally sensitive; handle them as evidence.

## Troubleshooting

If Foremost refuses to run because an output directory already exists, remove
or rename that output directory first. The helper clears only its generated
local output paths.

If expected files are missing, regenerate the local image and rerun the helper:

```bash
sh labs/foremost/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/foremost/docker-compose.yml down
docker compose -f labs/foremost/docker-compose.yml up --build -d
```
