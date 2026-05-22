# Objdump Guide And Local Binary-Inspection Lab

This lab teaches GNU `objdump` for local binary inspection: file headers,
private headers, sections, symbols, dynamic symbols, relocations,
disassembly, source-mixed disassembly, read-only data dumps, stripped-binary
comparison, and output validation. It uses generated PacketLab fixtures and
does not inspect malware, third-party binaries, or private files.

`objdump` is useful for static analysis and build troubleshooting, but output
is still context-dependent. Symbols, strings, and disassembly are clues, not
proof of runtime behavior.

## Safety Rules

- Inspect only files you own or have explicit permission to analyze.
- Keep suspicious or unknown files read-only and record hashes first.
- Do not execute unknown binaries to make static-analysis output more interesting.
- Treat strings, paths, symbols, and metadata as potentially sensitive.
- Compare stripped and unstripped binaries so you understand what symbols reveal.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs GNU `objdump`, GCC, `strip`, `file`, `sha256sum`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated C source, object file, compiled ELF sample, stripped ELF sample, and raw blob. |
| `outputs` | Generated `objdump` reports, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/objdump/docker-compose.yml up --build -d
docker compose -f labs/objdump/docker-compose.yml ps
docker compose -f labs/objdump/docker-compose.yml exec scanner objdump --version
```

Clean up when finished:

```bash
docker compose -f labs/objdump/docker-compose.yml down
```

## Local Fixtures

The helper creates and builds harmless local samples:

| File | Purpose |
| --- | --- |
| `packetlab-objdump-sample.c` | Source for a small local training program. |
| `packetlab-objdump-sample.o` | Object file for relocation practice. |
| `packetlab-objdump-sample` | Unstripped ELF with symbols and debug data. |
| `packetlab-objdump-sample-stripped` | Stripped copy for symbol-table comparison. |
| `packetlab-objdump-data.bin` | Raw generated blob for data-dump practice. |

The strings are local-only training indicators.

## Basic Usage

Show version information:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner objdump --version
```

Generate the source and raw blob:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Build the object file and executable:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  gcc -g -O0 -Wall -Wextra -c -o fixtures/packetlab-objdump-sample.o fixtures/packetlab-objdump-sample.c
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  gcc -g -O0 -Wall -Wextra -o fixtures/packetlab-objdump-sample fixtures/packetlab-objdump-sample.o
```

Inspect file format and headers:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -f fixtures/packetlab-objdump-sample
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -p fixtures/packetlab-objdump-sample
```

List sections, symbols, dynamic symbols, and relocations:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -h fixtures/packetlab-objdump-sample
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -t fixtures/packetlab-objdump-sample
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -T fixtures/packetlab-objdump-sample
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -r fixtures/packetlab-objdump-sample.o
```

Disassemble and inspect read-only data:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -d fixtures/packetlab-objdump-sample
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -S fixtures/packetlab-objdump-sample
docker compose -f labs/objdump/docker-compose.yml exec scanner \
objdump -s -j .rodata fixtures/packetlab-objdump-sample
```

Dump a raw local blob by declaring its input format:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -s -b binary -m aarch64 fixtures/packetlab-objdump-data.bin
```

## Useful Options

| Option | Use |
| --- | --- |
| `-f` | Print file header and architecture flags. |
| `-p` | Print private object-format headers. |
| `-h` | List section headers. |
| `-t` | Print the symbol table. |
| `-T` | Print the dynamic symbol table. |
| `-r` | Print relocation entries. |
| `-d` | Disassemble executable sections. |
| `-D` | Disassemble all sections. |
| `-S` | Intermix source with disassembly when debug info exists. |
| `-s` | Dump full section contents. |
| `-j NAME` | Limit output to one section. |
| `-b FORMAT` | Declare an input format, such as `binary` for raw blobs. |
| `-m MACHINE` | Declare a machine type when reading raw data. |

## Generate Practice Outputs

Run a quick `objdump` workflow:

```bash
docker compose -f labs/objdump/docker-compose.yml up --build -d
sh labs/objdump/make_scans.sh
```

This writes help/version output, generated fixture metadata, file types,
hashes, file headers, private headers, section headers, symbol tables,
dynamic symbols, relocations, disassembly, source-mixed disassembly, read-only
data dumps, stripped comparison output, validation results, and a TSV summary
into `labs/objdump/outputs`.

## Practice Tasks

1. Compare `outputs/section-headers.txt` with `outputs/rodata-dump.txt`.
2. Find `packetlab_check_mode` in `outputs/symbol-table.txt`.
3. Compare `outputs/symbol-table.txt` with `outputs/stripped-symbol-table.txt`.
4. Review `outputs/relocations-object.txt` and identify external references.
5. Compare `outputs/disassembly.txt` with `outputs/source-disassembly.txt`.
6. Review `outputs/sample-run-local.txt` and `outputs/sample-run-remote.txt`.
7. Write a safe binary-inspection checklist for files you are authorized to inspect.

## Real Binary Note

For real investigations, keep originals read-only, record hashes, and treat
all `objdump` findings as static-analysis clues. Combine them with file type,
provenance, runtime evidence, and other tooling before drawing conclusions.

## Troubleshooting

If symbols are missing, make sure you are looking at the unstripped sample:

```bash
docker compose -f labs/objdump/docker-compose.yml exec scanner \
  objdump -t fixtures/packetlab-objdump-sample
```

If source lines are missing, rebuild with debug info:

```bash
sh labs/objdump/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/objdump/docker-compose.yml down
docker compose -f labs/objdump/docker-compose.yml up --build -d
```
