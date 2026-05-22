# Volatility3 Guide And Local Memory-Forensics Lab

This lab teaches Volatility3 command structure, plugin discovery, offline
execution, local evidence handling, banner scanning, and failure triage using a
generated toy memory-like fixture. It does not require downloading real memory
images and does not inspect your host memory.

Volatility3 is a memory forensics framework. Real memory images can contain
passwords, tokens, private messages, keys, browsing history, and other sensitive
data. This lab generates a tiny local raw fixture with harmless strings so you
can practice workflow basics before handling real evidence.

## Safety Rules

- Analyze only memory images you own or have explicit permission to examine.
- Treat memory images, extracted strings, timelines, and process listings as sensitive evidence.
- Do not upload real memory images or symbol-derived output to public services.
- Use `--offline` when you want deterministic local analysis.
- Preserve hashes and case notes before modifying, copying, or exporting evidence.
- Keep generated fixtures and outputs local, and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs Volatility3, fixture generation, `strings`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated toy raw memory-like image. |
| `outputs` | Generated Volatility3 output, string hits, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/volatility3/docker-compose.yml up --build -d
docker compose -f labs/volatility3/docker-compose.yml ps
docker compose -f labs/volatility3/docker-compose.yml exec scanner vol -h
```

Clean up when finished:

```bash
docker compose -f labs/volatility3/docker-compose.yml down
```

## Local Fixture

The helper creates `fixtures/toy-memory.raw`, a 2 MiB local raw file containing
known lab strings at fixed offsets:

| Label | Purpose |
| --- | --- |
| `linux_banner` | Lets `banners.Banners` find a Linux-style banner. |
| `process_hint` | Gives string triage a fake local process clue. |
| `localhost_url` | Provides a harmless localhost URL artifact. |
| `handling_note` | Reminds you not to upload real memory images. |
| `case_marker` | Provides a deterministic marker for validation. |

This is not a real OS memory capture. Most OS-specific plugins should fail
against it, which is useful for learning requirement and symbol errors safely.

## Basic Usage

Show global options and plugin names:

```bash
docker compose -f labs/volatility3/docker-compose.yml exec scanner vol -h
```

Show help for a specific plugin:

```bash
docker compose -f labs/volatility3/docker-compose.yml exec scanner \
  vol --offline linux.pslist.PsList --help
```

Generate the local fixture:

```bash
docker compose -f labs/volatility3/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py \
  fixtures/toy-memory.raw outputs/fixture-manifest.json outputs/fixture-strings.tsv
```

Scan for Linux banners:

```bash
docker compose -f labs/volatility3/docker-compose.yml exec scanner \
  vol -q --offline -f fixtures/toy-memory.raw banners.Banners
```

Record a hash before analysis:

```bash
docker compose -f labs/volatility3/docker-compose.yml exec scanner \
  sha256sum fixtures/toy-memory.raw
```

## Useful Options

| Option | Use |
| --- | --- |
| `-f FILE` | Analyze a local memory image. |
| `--offline` | Avoid online symbol lookup. |
| `-q` | Reduce progress noise in saved output. |
| `-r json` | Render plugin output as JSON when supported. |
| `-o DIR` | Set the directory for plugin-generated files. |
| `-s DIR` | Add a local symbol directory. |
| `-p DIR` | Add a local plugin directory. |
| `PLUGIN --help` | Show plugin-specific requirements and options. |

## Generate Practice Outputs

Run a quick Volatility3 workflow:

```bash
docker compose -f labs/volatility3/docker-compose.yml up --build -d
sh labs/volatility3/make_scans.sh
```

This writes help/version output, framework info, plugin help, a generated toy
fixture, a banner scan, local string triage, expected OS-plugin failure output,
hashes, validation results, and a TSV summary into `labs/volatility3/outputs`.

## Practice Tasks

1. Run `vol -h` and identify global options that affect evidence handling.
2. Review `outputs/fixture-manifest.json` and locate each inserted artifact.
3. Compare `outputs/banners.txt` with `outputs/string-hits.txt`.
4. Read `outputs/windows-info-expected-failure.txt` and identify the missing requirements.
5. Run `vol --offline linux.pslist.PsList --help` and list required plugin inputs.
6. Record the SHA-256 hash before and after rerunning the helper.
7. Write a safe triage checklist for a real memory image you are authorized to analyze.

## Real Evidence Note

For real cases, keep the original memory image read-only, record cryptographic
hashes, preserve chain-of-custody notes, keep symbols local when possible, and
store extracted artifacts in a controlled location. OS-specific plugins require
a real image and suitable symbols; this toy fixture is only for command-shape
practice and safe output review.

## Troubleshooting

If Volatility3 cannot satisfy plugin requirements, confirm you are using a real
memory image for OS-specific plugins and that symbols are available.

If the banner scan returns no rows, regenerate the local fixture:

```bash
sh labs/volatility3/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/volatility3/docker-compose.yml down
docker compose -f labs/volatility3/docker-compose.yml up --build -d
```
