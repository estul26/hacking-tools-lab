# ExifTool Guide And Local Metadata Lab

This lab teaches ExifTool metadata inspection, grouped tag output, JSON/CSV
export, evidence hashing, and metadata stripping using generated local files.
It does not inspect your personal photos or download any external media.

ExifTool can reveal and modify metadata in images, documents, archives, and
many other file types. Real files may expose names, software versions,
timestamps, device details, GPS coordinates, and case-sensitive notes. This lab
uses harmless generated fixtures so you can practice safely before handling
real evidence.

## Safety Rules

- Analyze only files you own or have explicit permission to examine.
- Treat metadata output as sensitive because it can reveal identity, location, and workflow details.
- Work on copies when modifying or stripping metadata.
- Record hashes before and after metadata changes.
- Do not upload real files to public metadata services.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs ExifTool, fixture generation, `file`, `sha256sum`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated local image and companion note. |
| `outputs` | Generated metadata reports, sanitized copy, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/exiftool/docker-compose.yml up --build -d
docker compose -f labs/exiftool/docker-compose.yml ps
docker compose -f labs/exiftool/docker-compose.yml exec scanner exiftool -ver
```

Clean up when finished:

```bash
docker compose -f labs/exiftool/docker-compose.yml down
```

## Local Fixtures

The helper creates a tiny PNG and annotates it with lab metadata:

| Field | Example |
| --- | --- |
| `Artist` | `PacketLab Analyst` |
| `ImageDescription` | `Local ExifTool metadata fixture` |
| `DateTimeOriginal` | `2026:01:01 12:00:00` |
| `GPSLatitude` / `GPSLongitude` | Harmless lab coordinates. |
| `Software` | `ExifTool Lab Generator` |

The coordinates are training data, not a real target location.

## Basic Usage

Show the ExifTool version:

```bash
docker compose -f labs/exiftool/docker-compose.yml exec scanner exiftool -ver
```

Show common metadata:

```bash
docker compose -f labs/exiftool/docker-compose.yml exec scanner \
  exiftool fixtures/lab-photo.png
```

Show grouped short tag names:

```bash
docker compose -f labs/exiftool/docker-compose.yml exec scanner \
  exiftool -G1 -a -s fixtures/lab-photo.png
```

Write JSON output:

```bash
docker compose -f labs/exiftool/docker-compose.yml exec scanner \
  sh -c 'exiftool -j fixtures/lab-photo.png > outputs/metadata.json'
```

Strip metadata from a copy:

```bash
docker compose -f labs/exiftool/docker-compose.yml exec scanner \
  sh -c 'cp fixtures/lab-photo.png outputs/clean.png && exiftool -all= -overwrite_original outputs/clean.png'
```

## Useful Options

| Option | Use |
| --- | --- |
| `-G1` | Show the metadata group for each tag. |
| `-a` | Show duplicate tags instead of hiding them. |
| `-s` | Use short tag names for scripting. |
| `-j` | Export metadata as JSON. |
| `-csv` | Export selected tags as CSV. |
| `-TAG=VALUE` | Write or update a specific tag. |
| `-all=` | Remove metadata from a file or copy. |
| `-overwrite_original` | Avoid creating `_original` backup files when intentionally modifying a copy. |

## Generate Practice Outputs

Run a quick ExifTool workflow:

```bash
docker compose -f labs/exiftool/docker-compose.yml up --build -d
sh labs/exiftool/make_scans.sh
```

This writes version/help output, generated fixture metadata, grouped tag output,
JSON/CSV/TSV exports, hashes, a sanitized image copy, validation results, and a
TSV summary into `labs/exiftool/outputs`.

## Practice Tasks

1. Run `exiftool fixtures/lab-photo.jpg` and identify identity, timestamp, and location fields.
2. Compare `outputs/all-tags.txt` with `outputs/grouped-tags.txt`.
3. Use `jq` to read `Artist` and GPS values from `outputs/metadata.json`.
4. Compare `outputs/photo-sha256.txt` with `outputs/sanitized-sha256.txt`.
5. Confirm `outputs/sanitized-tags.txt` no longer contains the lab artist or GPS fields.
6. Add a new harmless `Comment` tag to a copy and inspect the result.
7. Write a safe metadata review checklist for files you are authorized to analyze.

## Real Evidence Note

For real files, keep originals read-only, record hashes, work on copies, and
document every metadata modification. Stripping metadata can change a file and
may remove evidence, so only do it when the task explicitly calls for a clean
copy.

## Troubleshooting

If ExifTool reports that a file has no writable tags, confirm you are using the
generated PNG fixture and not the plain-text note.

If metadata is missing, rerun the helper:

```bash
sh labs/exiftool/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/exiftool/docker-compose.yml down
docker compose -f labs/exiftool/docker-compose.yml up --build -d
```
