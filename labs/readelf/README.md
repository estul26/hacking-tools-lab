# Readelf Guide And Local ELF-Inspection Lab

This lab teaches GNU `readelf` for local ELF inspection: ELF headers, program
headers, section headers, symbols, dynamic symbols, relocations, dynamic
section entries, notes, version information, read-only data strings, hex
dumps, debug line data, stripped-binary comparison, and output validation. It
uses generated PacketLab fixtures and does not inspect malware, third-party
binaries, or private files.

`readelf` focuses on ELF structure rather than disassembly. It is excellent
for understanding how a binary is laid out, but its output is still static
analysis context, not proof of runtime behavior.

## Safety Rules

- Inspect only files you own or have explicit permission to analyze.
- Keep suspicious or unknown files read-only and record hashes first.
- Do not execute unknown binaries to create more interesting metadata.
- Treat strings, symbol names, paths, notes, and hashes as potentially sensitive.
- Compare stripped and unstripped binaries so you understand what symbols reveal.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs GNU `readelf`, GCC, `strip`, `file`, `sha256sum`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated C source, object file, compiled ELF sample, and stripped ELF sample. |
| `outputs` | Generated `readelf` reports, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/readelf/docker-compose.yml up --build -d
docker compose -f labs/readelf/docker-compose.yml ps
docker compose -f labs/readelf/docker-compose.yml exec scanner readelf --version
```

Clean up when finished:

```bash
docker compose -f labs/readelf/docker-compose.yml down
```

## Local Fixtures

The helper creates and builds harmless local samples:

| File | Purpose |
| --- | --- |
| `packetlab-readelf-sample.c` | Source for a small local training program. |
| `packetlab-readelf-sample.o` | Object file for relocation practice. |
| `packetlab-readelf-sample` | Unstripped ELF with symbols and debug data. |
| `packetlab-readelf-sample-stripped` | Stripped copy for symbol-table comparison. |

The strings are local-only training indicators.

## Basic Usage

Show version information:

```bash
docker compose -f labs/readelf/docker-compose.yml exec scanner readelf --version
```

Generate the source:

```bash
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Build the object file and executable:

```bash
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  gcc -g -O0 -Wall -Wextra -c -o fixtures/packetlab-readelf-sample.o fixtures/packetlab-readelf-sample.c
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  gcc -g -O0 -Wall -Wextra -o fixtures/packetlab-readelf-sample fixtures/packetlab-readelf-sample.o
```

Inspect ELF headers and sections:

```bash
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -h fixtures/packetlab-readelf-sample
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -l fixtures/packetlab-readelf-sample
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -S fixtures/packetlab-readelf-sample
```

List symbols, dynamic symbols, and relocations:

```bash
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -s fixtures/packetlab-readelf-sample
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf --dyn-syms fixtures/packetlab-readelf-sample
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -r fixtures/packetlab-readelf-sample.o
```

Inspect dynamic metadata, notes, and read-only data:

```bash
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -d fixtures/packetlab-readelf-sample
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -n fixtures/packetlab-readelf-sample
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -p .rodata fixtures/packetlab-readelf-sample
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -x .rodata fixtures/packetlab-readelf-sample
```

## Useful Options

| Option | Use |
| --- | --- |
| `-h` | Print the ELF header. |
| `-l` | Print program headers. |
| `-S` | Print section headers. |
| `-s` | Print the symbol table. |
| `--dyn-syms` | Print the dynamic symbol table. |
| `-r` | Print relocations. |
| `-d` | Print the dynamic section. |
| `-n` | Print ELF notes. |
| `-V` | Print version information. |
| `-p SECTION` | Print strings from a section. |
| `-x SECTION` | Hex dump a section. |
| `--debug-dump=decodedline` | Print decoded debug line information. |

## Generate Practice Outputs

Run a quick `readelf` workflow:

```bash
docker compose -f labs/readelf/docker-compose.yml up --build -d
sh labs/readelf/make_scans.sh
```

This writes help/version output, generated fixture metadata, file types,
hashes, ELF headers, program headers, section headers, symbols, dynamic
symbols, relocations, dynamic section entries, notes, version information,
`.rodata` strings, `.rodata` hex output, debug line output, stripped
comparison output, validation results, and a TSV summary into
`labs/readelf/outputs`.

## Practice Tasks

1. Compare `outputs/elf-header.txt` with `outputs/program-headers.txt`.
2. Find `.text` and `.rodata` in `outputs/section-headers.txt`.
3. Find `packetlab_check_mode` in `outputs/symbols.txt`.
4. Compare `outputs/symbols.txt` with `outputs/stripped-symbols.txt`.
5. Review `outputs/relocations-object.txt` and identify external references.
6. Compare `outputs/rodata-strings.txt` with `outputs/rodata-hex.txt`.
7. Write a safe ELF-inspection checklist for files you are authorized to inspect.

## Real Binary Note

For real investigations, keep originals read-only, record hashes, and treat
all `readelf` findings as static-analysis context. Combine them with file
type, provenance, runtime evidence, and other tooling before drawing
conclusions.

## Troubleshooting

If symbols are missing, make sure you are looking at the unstripped sample:

```bash
docker compose -f labs/readelf/docker-compose.yml exec scanner \
  readelf -s fixtures/packetlab-readelf-sample
```

If debug line information is missing, rebuild with debug info:

```bash
sh labs/readelf/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/readelf/docker-compose.yml down
docker compose -f labs/readelf/docker-compose.yml up --build -d
```
