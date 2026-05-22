# YARA Guide And Local Rule-Matching Lab

This lab teaches YARA rule writing and scanning with generated local fixtures.
You can practice string rules, hex-string rules, regex rules, metadata output,
tag and identifier filters, recursive scans, external variables, compiled
rules, and negative checks without scanning real private files.

YARA is a pattern-matching tool often used for malware triage, incident
response, and forensic review. Rule matches are leads, not proof of malicious
behavior. This lab uses harmless PacketLab fixtures so you can learn the
workflow safely.

## Safety Rules

- Scan only files and directories you own or have explicit permission to examine.
- Treat matches, filenames, hashes, and extracted strings as sensitive triage data.
- Do not execute samples because a YARA rule matched them.
- Keep rules scoped and test them against known benign files to reduce false positives.
- Record hashes before sharing or escalating samples.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted directories.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs YARA, `yarac`, fixture generation, `file`, `sha256sum`, and `jq`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Generated local sample files. |
| `rules` | Local YARA rules mounted read-only. |
| `outputs` | Generated matches, compiled rules, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/yara/docker-compose.yml up --build -d
docker compose -f labs/yara/docker-compose.yml ps
docker compose -f labs/yara/docker-compose.yml exec scanner yara --version
```

Clean up when finished:

```bash
docker compose -f labs/yara/docker-compose.yml down
```

## Local Fixtures

The helper creates local samples:

| File | Purpose |
| --- | --- |
| `packetlab-note.txt` | Text indicators, URL, and fake local token. |
| `packetlab-binary.bin` | ELF-like header and binary marker. |
| `subdir/nested-config.cfg` | Recursive scan target. |
| `benign-note.txt` | Negative-control sample. |

The token-looking value is fake and local-only.

## Basic Usage

Show version information:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner yara --version
```

Generate local fixtures:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner \
  python3 /usr/local/bin/generate_fixture.py fixtures outputs/fixture-manifest.json
```

Run local rules against one file:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner \
  yara rules/packetlab.yar fixtures/packetlab-note.txt
```

Print matching strings, tags, and metadata:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner \
  yara -s -m -g rules/packetlab.yar fixtures/packetlab-note.txt
```

Recursively scan fixtures:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner \
  yara -r rules/packetlab.yar fixtures
```

Test an external-variable rule:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner \
  yara -d lab_mode=local rules/external-mode.yar fixtures/packetlab-note.txt
```

Compile and scan with compiled rules:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner \
  sh -c 'yarac rules/packetlab.yar outputs/packetlab.yarc && yara -C outputs/packetlab.yarc fixtures/packetlab-note.txt'
```

## Useful Options

| Option | Use |
| --- | --- |
| `-s` | Print matching strings. |
| `-m` | Print rule metadata. |
| `-g` | Print rule tags. |
| `-r` | Recursively scan directories. |
| `-t TAG` | Print only rules with a specific tag. |
| `-i NAME` | Print only a specific rule identifier. |
| `-d NAME=VALUE` | Define an external variable. |
| `-c` | Print only the number of matches. |
| `-n` | Print only rules that did not match. |
| `-C` | Load compiled rules from `yarac`. |

## Generate Practice Outputs

Run a quick YARA workflow:

```bash
docker compose -f labs/yara/docker-compose.yml up --build -d
sh labs/yara/make_scans.sh
```

This writes help/version output, generated fixtures, file types, hashes,
single-file matches, detailed string/meta/tag output, recursive matches, tag
and identifier-filter output, external-variable tests, compiled-rule output,
negative-control output, validation results, and a TSV summary into
`labs/yara/outputs`.

## Practice Tasks

1. Compare `outputs/text-match.txt` with `outputs/text-match-details.txt`.
2. Review `rules/packetlab.yar` and identify string, hex, regex, and size conditions.
3. Run a recursive scan and compare it with `outputs/recursive-matches.txt`.
4. Compare `outputs/external-local.txt` with `outputs/external-remote.txt`.
5. Inspect `outputs/negated-benign.txt` and explain what `-n` means.
6. Compile rules with `yarac` and compare compiled-rule output.
7. Write a safe YARA testing checklist for files you are authorized to scan.

## Real Sample Note

For real investigations, keep samples read-only, record hashes, and test rules
against known benign files before using matches for escalation. A YARA hit is a
triage signal that needs context from file type, provenance, behavior, and
other evidence.

## Troubleshooting

If no rules match, regenerate the local fixtures:

```bash
sh labs/yara/make_scans.sh
```

If an external-variable rule errors, pass the expected variable:

```bash
docker compose -f labs/yara/docker-compose.yml exec scanner \
  yara -d lab_mode=local rules/external-mode.yar fixtures/packetlab-note.txt
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/yara/docker-compose.yml down
docker compose -f labs/yara/docker-compose.yml up --build -d
```
