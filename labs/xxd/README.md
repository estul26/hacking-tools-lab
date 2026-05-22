# Xxd Guide And Local Hex-Dump Lab

This lab teaches `xxd` for local byte-level triage: canonical hex dumps,
single-byte grouping, row-width changes, offset windows, plain hex output,
C include arrays, reverse reconstruction, and controlled patching of a copy.
It uses a generated local fixture and does not inspect private files.

`xxd` is useful when you need to see exact bytes, offsets, and ASCII sidebars.
It can also rebuild or patch files from hex dumps, so use it carefully and work
on copies when modifying data.

## Safety Rules

- Analyze only files you own or have explicit permission to inspect.
- Work on copies when reversing or patching hex dumps.
- Record hashes before and after byte-level changes.
- Treat embedded strings, URLs, tokens, and offsets as sensitive triage notes.
- Do not execute unknown files after editing bytes.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `xxd`, fixture generation, `file`, `sha256sum`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated binary-like sample. |
| `outputs` | Generated hex dumps, reconstructed copy, patched copy, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/xxd/docker-compose.yml up --build -d
docker compose -f labs/xxd/docker-compose.yml ps
docker compose -f labs/xxd/docker-compose.yml exec scanner xxd -v
```

Clean up when finished:

```bash
docker compose -f labs/xxd/docker-compose.yml down
```

## Local Fixture

The helper creates `fixtures/packetlab-sample.bin`, a deterministic 512-byte
local blob with known markers:

| Offset | Marker |
| --- | --- |
| `0x00` | `PKTLAB-XXD` header. |
| `0x20` | `ORIGINAL`, used for copy-only patch practice. |
| `0x40` | `PacketLab xxd local fixture`. |
| `0x80` | `URL=http://127.0.0.1:8080/xxd`. |
| `0xC0` | `API_TOKEN=LOCAL-TRAINING-ONLY`. |

The token-looking value is fake and local-only.

## Basic Usage

Show version information:

```bash
docker compose -f labs/xxd/docker-compose.yml exec scanner xxd -v
```

Generate the local fixture:

```bash
docker compose -f labs/xxd/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Create a default hex dump:

```bash
docker compose -f labs/xxd/docker-compose.yml exec scanner \
  xxd fixtures/packetlab-sample.bin
```

Inspect a bounded offset window:

```bash
docker compose -f labs/xxd/docker-compose.yml exec scanner \
  xxd -s 0x40 -l 96 fixtures/packetlab-sample.bin
```

Round-trip a dump back to bytes:

```bash
docker compose -f labs/xxd/docker-compose.yml exec scanner \
  sh -c 'xxd fixtures/packetlab-sample.bin > outputs/sample.hex && xxd -r outputs/sample.hex outputs/roundtrip.bin'
```

Patch a copy using a tiny hex patch:

```bash
docker compose -f labs/xxd/docker-compose.yml exec scanner \
  sh -c 'cp fixtures/packetlab-sample.bin outputs/patched.bin && printf "00000020: 5041 5443 4845 4431\n" > outputs/patch.hex && xxd -r outputs/patch.hex outputs/patched.bin'
```

## Useful Options

| Option | Use |
| --- | --- |
| `-g NUM` | Group bytes by `NUM` bytes. |
| `-c NUM` | Set bytes per output row. |
| `-l NUM` | Limit bytes read. |
| `-s OFFSET` | Seek to an offset before dumping. |
| `-p` | Emit plain continuous hex. |
| `-i` | Emit a C include-style byte array. |
| `-r` | Reverse a hex dump back into bytes. |
| `-v` | Show version information. |

## Generate Practice Outputs

Run a quick `xxd` workflow:

```bash
docker compose -f labs/xxd/docker-compose.yml up --build -d
sh labs/xxd/make_scans.sh
```

This writes help/version output, generated fixture metadata, default and
byte-grouped hex dumps, offset-window output, plain hex, C include output,
round-trip reconstruction, a copy-only patch, hashes, validation results, and a
TSV summary into `labs/xxd/outputs`.

## Practice Tasks

1. Compare `outputs/hexdump-default.txt` with `outputs/hexdump-byte-groups.txt`.
2. Use `outputs/hexdump-offset-0x40.txt` to locate the local fixture marker.
3. Compare `outputs/plain-hex.txt` length with the fixture size.
4. Inspect `outputs/include-array.h` and identify the generated array length.
5. Confirm `outputs/roundtrip.tsv` reports a matching reconstruction.
6. Review `outputs/patch.hex` and `outputs/patched-window.txt`.
7. Write a safe byte-edit checklist for files you are authorized to inspect.

## Real File Note

For real files, keep originals read-only, record hashes, and patch only copies.
Byte-level edits can corrupt formats or change evidence, so document offsets,
before/after bytes, and hashes when a task explicitly calls for modification.

## Troubleshooting

If expected offsets are missing, regenerate the fixture:

```bash
sh labs/xxd/make_scans.sh
```

If a reverse round trip differs, confirm the input file is an unmodified `xxd`
dump and not a plain hex file. Plain hex can be reversed too, but it needs the
matching options and careful offset handling.

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/xxd/docker-compose.yml down
docker compose -f labs/xxd/docker-compose.yml up --build -d
```
