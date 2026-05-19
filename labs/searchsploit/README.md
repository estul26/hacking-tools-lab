# Searchsploit Guide And Local Exploit-DB Search Lab

This lab teaches Searchsploit with the local Exploit-DB package. You can
practice keyword search, title-only search, CVE lookup, JSON output, URL output,
path lookup, and Nmap XML-assisted searching without contacting a live target.

Searchsploit is a triage tool. It helps you find public Exploit-DB entries that
may relate to software names, versions, and CVEs. A search result is not proof
that a system is vulnerable; always confirm version, configuration, exposure,
patch state, and authorization before doing deeper testing.

## Safety Rules

- Search and review exploit references only for authorized assessment or training work.
- Treat results as leads, not proof of vulnerability.
- Do not run exploit code against systems without explicit written authorization.
- Prefer `--www`, `--json`, and `-p` for review workflows before copying files.
- Do not use `--mirror` unless you intentionally need a local copy of an exploit for authorized analysis.
- Keep generated outputs local and delete them when no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted files.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `searchsploit`, reads local fixtures, and stores output. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `fixtures` | Local Nmap XML fixture for Searchsploit's `--nmap` mode. |
| `outputs` | Generated search output, logs, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/searchsploit/docker-compose.yml up --build -d
docker compose -f labs/searchsploit/docker-compose.yml ps
docker compose -f labs/searchsploit/docker-compose.yml exec scanner searchsploit -h
```

Clean up when finished:

```bash
docker compose -f labs/searchsploit/docker-compose.yml down
```

## Basic Search

Search the local Exploit-DB copy for Apache 2.4 references:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  searchsploit apache 2.4
```

Use `--id` to show EDB-ID values:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  searchsploit --id apache 2.4
```

## JSON Output

Write machine-readable output:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  sh -c 'searchsploit --json apache 2.4 > outputs/apache-24.json'
```

Count exploit results:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  jq '.RESULTS_EXPLOIT | length' outputs/apache-24.json
```

## CVE Lookup

Search by CVE:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  searchsploit --cve 2021-41773
```

This searches the local Exploit-DB metadata for entries tagged with the CVE.

## Review Paths And URLs

Show the local path for an Exploit-DB ID:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  searchsploit -p 50383
```

Show Exploit-DB URLs instead of local paths:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  searchsploit --www --id apache 2.4
```

These are review workflows. They do not execute exploit code.

## Nmap XML Fixture

Searchsploit can read service versions from Nmap XML:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  searchsploit --nmap fixtures/nmap-apache.xml
```

The fixture is a local sample for `Apache httpd 2.4.7` on `127.0.0.1`; it is not
the result of scanning a live host.

## Useful Options

| Option | Use |
| --- | --- |
| `--id` | Show Exploit-DB IDs instead of local paths. |
| `--json` | Emit JSON output for parsing. |
| `--www` | Show Exploit-DB URLs instead of local file paths. |
| `--cve ID` | Search by CVE identifier. |
| `-t` | Search only exploit titles. |
| `-e` | Require an exact ordered title match. |
| `--exclude TERM` | Remove noisy result terms. |
| `-p EDB-ID` | Show the local path for one entry. |
| `--nmap FILE.xml` | Search based on Nmap XML service data. |
| `--disable-colour` | Disable terminal color in output. |

## Generate Practice Outputs

Run a quick Searchsploit workflow:

```bash
sh labs/searchsploit/make_scans.sh
```

This writes help/version output, JSON search results, URL output, path lookup
output, Nmap fixture output, validation results, and a TSV summary into
`labs/searchsploit/outputs`.

## Practice Tasks

1. Search for `apache 2.4` and compare default output with `--id`.
2. Search for `wordpress 5.0` using `-t` and explain title-only filtering.
3. Run `--cve 2021-41773` and identify matching EDB IDs.
4. Use `--json` and parse the number of exploit results with `jq`.
5. Use `-p 50383` and explain why path review is safer than executing code.
6. Run `--nmap fixtures/nmap-apache.xml` and inspect service-version matching.
7. Write a safe Searchsploit command for software you are authorized to assess.

## Troubleshooting

If a search returns too many results, add `-t`, `-e`, `--exclude`, or more
specific version terms.

If JSON parsing fails, confirm Searchsploit produced valid output:

```bash
docker compose -f labs/searchsploit/docker-compose.yml exec scanner \
  searchsploit --json apache 2.4 | jq .
```

If Compose reports the scanner is stale, restart the lab:

```bash
docker compose -f labs/searchsploit/docker-compose.yml down
docker compose -f labs/searchsploit/docker-compose.yml up --build -d
```
