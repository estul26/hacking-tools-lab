# File Guide And Local Type-Identification Lab

This lab teaches the Unix `file` command for local file triage: content-based
type detection, MIME output, encoding hints, compressed-content inspection,
custom magic rules, hash recording, and validation. It uses generated local
fixtures and does not inspect private files from your machine.

`file` is useful for quick triage because it looks at content signatures rather
than trusting names or extensions. Real files can be mislabeled, packed,
polyglot, encrypted, damaged, or intentionally deceptive, so treat results as
strong clues rather than final proof.

## Safety Rules

- Analyze only files you own or have explicit permission to examine.
- Do not execute unknown files based on `file` output.
- Treat filenames, hashes, metadata, and type reports as sensitive.
- Record hashes before deeper analysis or extraction.
- Be skeptical of extensions and review content signatures instead.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `file`, fixture generation, `sha256sum`, `gzip`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated sample files with known content types. |
| `outputs` | Generated type reports, custom magic file, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/file/docker-compose.yml up --build -d
docker compose -f labs/file/docker-compose.yml ps
docker compose -f labs/file/docker-compose.yml exec scanner file --version
```

Clean up when finished:

```bash
docker compose -f labs/file/docker-compose.yml down
```

## Local Fixtures

The helper creates local fixtures with known expected types:

| File | Purpose |
| --- | --- |
| `note.txt` | Plain ASCII text baseline. |
| `script.sh` | Shell script identified from content. |
| `config.json` | JSON fixture for MIME output. |
| `image.png` | Tiny valid PNG. |
| `renamed-as-jpg.jpg` | PNG content with a misleading `.jpg` extension. |
| `packetlab.bin` | Custom magic-rule fixture. |
| `random.bin` | Opaque binary data. |
| `note.txt.gz` | Compressed text fixture for `-z`. |

## Basic Usage

Show the installed version:

```bash
docker compose -f labs/file/docker-compose.yml exec scanner file --version
```

Generate the local fixtures:

```bash
docker compose -f labs/file/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Identify files by content:

```bash
docker compose -f labs/file/docker-compose.yml exec scanner file fixtures/*
```

Show MIME types:

```bash
docker compose -f labs/file/docker-compose.yml exec scanner file --mime-type fixtures/*
```

Inspect compressed content:

```bash
docker compose -f labs/file/docker-compose.yml exec scanner file -z fixtures/note.txt.gz
```

Use the local custom magic rule:

```bash
docker compose -f labs/file/docker-compose.yml exec scanner \
  file -m outputs/packetlab.magic fixtures/packetlab.bin
```

## Useful Options

| Option | Use |
| --- | --- |
| `-b` | Brief output without file names. |
| `--mime-type` | Print MIME types for scripting. |
| `--mime-encoding` | Print encoding hints. |
| `-z` | Try to inspect compressed content. |
| `-k` | Keep going after the first match. |
| `-m FILE` | Use a custom magic file. |
| `-L` | Follow symlinks. |
| `--version` | Show version and magic database paths. |

## Generate Practice Outputs

Run a quick `file` workflow:

```bash
docker compose -f labs/file/docker-compose.yml up --build -d
sh labs/file/make_scans.sh
```

This writes help/version output, generated fixture metadata, hashes, default
types, brief output, MIME types, MIME encodings, compressed-content output,
custom magic output, validation results, and a TSV summary into
`labs/file/outputs`.

## Practice Tasks

1. Compare `outputs/default-types.txt` with `outputs/mime-types.txt`.
2. Explain why `renamed-as-jpg.jpg` is still detected as PNG.
3. Review `outputs/compressed-types.txt` and identify the inner content.
4. Inspect `outputs/packetlab.magic` and `outputs/custom-magic.txt`.
5. Compare `outputs/fixture-manifest.json` with actual `file` output.
6. Record hashes from `outputs/fixture-sha256.txt` before deeper analysis.
7. Write a safe triage checklist for files you are authorized to inspect.

## Real File Note

For real files, keep originals read-only, record hashes, and avoid execution.
Use `file` alongside metadata tools, archive listing, signature scans, and
manual review when authorization and lab controls allow it.

## Troubleshooting

If expected files are missing, regenerate the fixtures:

```bash
sh labs/file/make_scans.sh
```

If a compressed file only shows the outer type, try `-z`:

```bash
docker compose -f labs/file/docker-compose.yml exec scanner file -z fixtures/note.txt.gz
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/file/docker-compose.yml down
docker compose -f labs/file/docker-compose.yml up --build -d
```
