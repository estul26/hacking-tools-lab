# Radare2 Guide And Local Reverse-Engineering Lab

This lab teaches Radare2 for local binary triage and reverse-engineering
practice: binary metadata, sections, symbols, imports, strings, function
listing, targeted disassembly, stripped-binary comparison, raw hex viewing,
and output validation. It uses generated PacketLab fixtures and does not
analyze malware, third-party binaries, or private files.

Radare2 is powerful enough to inspect many executable and binary formats. Use
it carefully: static analysis findings are leads, not proof of behavior, and
unknown files may contain sensitive data or hostile code.

## Safety Rules

- Analyze only files you own or have explicit permission to examine.
- Keep suspicious or unknown files read-only and record hashes before analysis.
- Do not execute unknown binaries just because you can inspect them.
- Treat strings, paths, symbols, and metadata as potentially sensitive.
- Use generated local fixtures for practice before moving to real evidence.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs Radare2, `rabin2`, `gcc`, `strip`, `file`, `sha256sum`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated C source, compiled ELF sample, stripped ELF sample, and raw blob. |
| `outputs` | Generated analysis reports, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/radare2/docker-compose.yml up --build -d
docker compose -f labs/radare2/docker-compose.yml ps
docker compose -f labs/radare2/docker-compose.yml exec scanner r2 -v
```

Clean up when finished:

```bash
docker compose -f labs/radare2/docker-compose.yml down
```

## Local Fixtures

The helper creates and builds harmless local samples:

| File | Purpose |
| --- | --- |
| `packetlab-r2-sample.c` | Source for a small local training program. |
| `packetlab-r2-sample` | Unstripped ELF with symbols and debug data. |
| `packetlab-r2-sample-stripped` | Stripped copy for comparison. |
| `packetlab-r2-raw.bin` | Raw generated blob for hex viewing and string search practice. |

The token-looking string in the sample is fake and local-only.

## Basic Usage

Show version information:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner r2 -v
```

Generate the source and raw blob:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Build the local executable:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  gcc -g -O0 -Wall -Wextra -o fixtures/packetlab-r2-sample fixtures/packetlab-r2-sample.c
```

Inspect binary metadata:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  rabin2 -I fixtures/packetlab-r2-sample
```

List sections, strings, symbols, and imports:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  rabin2 -S fixtures/packetlab-r2-sample
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  rabin2 -z fixtures/packetlab-r2-sample
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  rabin2 -s fixtures/packetlab-r2-sample
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  rabin2 -i fixtures/packetlab-r2-sample
```

Analyze functions and disassemble one known function:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  r2 -A -q -c 'afl' -c 'pdf @ sym.packetlab_check_mode' -c 'q' fixtures/packetlab-r2-sample
```

Practice hex viewing on a raw blob:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  r2 -q -c 'px 96' -c '/ PACKETLAB_RAW_R2_MARKER' -c 'q' fixtures/packetlab-r2-raw.bin
```

## Useful Commands

| Command | Use |
| --- | --- |
| `r2 -v` | Show Radare2 version information. |
| `rabin2 -I FILE` | Print binary metadata. |
| `rabin2 -S FILE` | List sections. |
| `rabin2 -z FILE` | List strings discovered in the binary. |
| `rabin2 -s FILE` | List symbols. |
| `rabin2 -i FILE` | List imports. |
| `r2 -A FILE` | Open and run analysis. |
| `afl` | List analyzed functions inside `r2`. |
| `pdf @ sym.name` | Print disassembly for a named function. |
| `px 64 @ entry0` | Hexdump 64 bytes at the entry point. |
| `/ text` | Search for text bytes in the current file. |
| `q` | Quit the Radare2 shell. |

## Generate Practice Outputs

Run a quick Radare2 workflow:

```bash
docker compose -f labs/radare2/docker-compose.yml up --build -d
sh labs/radare2/make_scans.sh
```

This writes help/version output, generated fixture metadata, file types,
hashes, binary information, sections, strings, symbols, imports, function
analysis, stripped-binary analysis, raw-blob output, validation results, and a
TSV summary into `labs/radare2/outputs`.

## Practice Tasks

1. Compare `outputs/symbols.txt` with `outputs/stripped-analysis.txt`.
2. Review `outputs/strings.txt` and identify local-only training indicators.
3. Use `outputs/sections.txt` to find the `.text` and `.rodata` sections.
4. Read `outputs/function-analysis.txt` and locate the branch for `local` mode.
5. Compare `outputs/sample-run-local.txt` with `outputs/sample-run-remote.txt`.
6. Review `outputs/raw-blob-analysis.txt` and find the raw PacketLab marker.
7. Write a safe binary-analysis checklist for files you are authorized to inspect.

## Real Binary Note

For real investigations, keep originals read-only, record hashes, and avoid
executing unknown binaries in your analysis container. Combine Radare2 findings
with file type, provenance, sandbox results, and other evidence before drawing
conclusions.

## Troubleshooting

If symbols are missing, regenerate and rebuild the fixture:

```bash
sh labs/radare2/make_scans.sh
```

If a named function does not resolve, list functions first:

```bash
docker compose -f labs/radare2/docker-compose.yml exec scanner \
  r2 -A -q -c 'afl' -c 'q' fixtures/packetlab-r2-sample
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/radare2/docker-compose.yml down
docker compose -f labs/radare2/docker-compose.yml up --build -d
```
