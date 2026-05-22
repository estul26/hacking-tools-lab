# Strings Guide And Local Binary-Triage Lab

This lab teaches GNU `strings` for local binary triage: printable-string
extraction, minimum-length filtering, offset recording, UTF-16LE review,
keyword searches, hash recording, and output validation. It uses a generated
binary-like fixture and does not analyze any real malware, firmware, or private
file.

`strings` is useful for quick triage, but it is not proof of behavior. Real
files may contain credentials, URLs, keys, personal data, malware indicators,
or decoy strings. Treat hits as leads, preserve hashes, and avoid executing
unknown binaries.

## Safety Rules

- Analyze only files you own or have explicit permission to examine.
- Treat extracted strings as sensitive because they may include secrets or personal data.
- Do not execute unknown binaries just because `strings` finds interesting text.
- Record hashes before analysis.
- Use minimum length, offsets, encodings, and context to reduce false positives.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs GNU `strings`, fixture generation, `file`, `sha256sum`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated binary-like sample. |
| `outputs` | Generated string reports, keyword hits, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/strings/docker-compose.yml up --build -d
docker compose -f labs/strings/docker-compose.yml ps
docker compose -f labs/strings/docker-compose.yml exec scanner strings --version
```

Clean up when finished:

```bash
docker compose -f labs/strings/docker-compose.yml down
```

## Local Fixture

The helper creates `fixtures/packetlab-sample.bin`, a deterministic local blob
with known markers:

| Offset | Marker |
| --- | --- |
| `0x80` | `PACKETLAB_STRINGS_FIXTURE v1.0` |
| `0x180` | `URL=http://127.0.0.1:8080/status` |
| `0x240` | `API_TOKEN=LOCAL-TRAINING-ONLY-NOT-A-REAL-SECRET` |
| `0x320` | `/opt/packetlab/bin/local-agent --mode offline` |
| `0x900` | UTF-16LE `UNICODE_PACKETLAB_MARKER` |

The token-looking value is deliberately fake and local-only.

## Basic Usage

Show version information:

```bash
docker compose -f labs/strings/docker-compose.yml exec scanner strings --version
```

Generate the local fixture:

```bash
docker compose -f labs/strings/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Extract printable strings:

```bash
docker compose -f labs/strings/docker-compose.yml exec scanner \
  strings -a fixtures/packetlab-sample.bin
```

Show hexadecimal offsets:

```bash
docker compose -f labs/strings/docker-compose.yml exec scanner \
  strings -a -t x fixtures/packetlab-sample.bin
```

Search UTF-16LE strings:

```bash
docker compose -f labs/strings/docker-compose.yml exec scanner \
  strings -a -e l fixtures/packetlab-sample.bin
```

## Useful Options

| Option | Use |
| --- | --- |
| `-a` | Scan the whole file, not only loaded/initialized sections. |
| `-n NUM` | Set the minimum string length. |
| `-t x` | Print hexadecimal offsets. |
| `-t d` | Print decimal offsets. |
| `-e l` | Decode 16-bit little-endian strings. |
| `-e b` | Decode 16-bit big-endian strings. |
| `--encoding=ENC` | Longer form of `-e`. |
| `--version` | Show GNU strings version information. |

## Generate Practice Outputs

Run a quick strings workflow:

```bash
docker compose -f labs/strings/docker-compose.yml up --build -d
sh labs/strings/make_scans.sh
```

This writes help/version output, generated fixture metadata, hashes, default
strings output, minimum-length output, hex/decimal offset output, UTF-16LE
output, keyword hits, validation results, and a TSV summary into
`labs/strings/outputs`.

## Practice Tasks

1. Compare `outputs/all-strings.txt` with `outputs/min-length-8.txt`.
2. Use `outputs/offsets-hex.txt` to find the `0x80` marker.
3. Review `outputs/url-hits.txt` and explain why localhost URLs are still useful clues.
4. Review `outputs/sensitive-keyword-hits.txt` without treating the fake token as real evidence.
5. Compare ASCII output with `outputs/utf16le-strings.txt`.
6. Check `outputs/sample-sha256.txt` before and after regenerating the fixture.
7. Write a safe triage checklist for a binary you are authorized to analyze.

## Real Binary Note

For real binaries, keep the original file read-only, record hashes, and treat
strings as leads that need context. Interesting strings can be unused, encoded,
planted, or misleading. Use offsets, disassembly, sandboxing, or file-format
analysis only when your authorization and lab controls allow it.

## Troubleshooting

If expected strings are missing, regenerate the fixture:

```bash
sh labs/strings/make_scans.sh
```

If output is too noisy, increase the minimum length:

```bash
docker compose -f labs/strings/docker-compose.yml exec scanner \
  strings -a -n 12 fixtures/packetlab-sample.bin
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/strings/docker-compose.yml down
docker compose -f labs/strings/docker-compose.yml up --build -d
```
