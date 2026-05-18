# Nuclei Guide And Local Lab

This lab teaches `nuclei` with a Docker web target published to `127.0.0.1`.
You can practice template-based scanning, matchers, extractors, severity
filtering, JSONL output, and finding triage against a target you control.

Nuclei is a fast template-driven scanner. Templates describe what request to
send, what response signals to match, and what data to extract. This lab uses
small local templates instead of the public nuclei-templates feed so every
finding is deterministic and stays inside Docker.

## Safety Rules

- Scan only systems you own or have explicit permission to test.
- Keep scans scoped to approved hosts, ports, paths, and templates.
- Review templates before running them against any real target.
- Use rate limits and concurrency limits until you understand target load.
- Treat findings as leads to verify manually, not proof of a vulnerability.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.49.190.10` | Runs `nuclei`, `curl`, `jq`, and stores output. |
| `target` | `172.49.190.20` | HTTP target with safe, predictable template matches. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18095` | `target:8080` | Nuclei practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/nuclei/docker-compose.yml up --build -d
docker compose -f labs/nuclei/docker-compose.yml ps
docker compose -f labs/nuclei/docker-compose.yml exec scanner nuclei -version
```

Open the target:

```bash
open http://127.0.0.1:18095
```

Clean up when finished:

```bash
docker compose -f labs/nuclei/docker-compose.yml down
```

## Run Local Templates

Scan the local target with every template in this lab:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  nuclei -u http://target:8080 -t templates -duc -silent
```

Expected matches include the debug endpoint, backup configuration JSON, `.env`
file, admin Basic Auth challenge, missing browser security headers, and an
`X-Powered-By` disclosure.

## Run One Template

Focus on a single template:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  nuclei -u http://target:8080 -t templates/local-backup-config.yaml -duc -silent
```

Then manually verify the matched URL:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  curl -sS http://target:8080/backup/config.json | jq .
```

## Save JSONL Output

Save machine-readable output:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  nuclei -u http://target:8080 -t templates -jsonl \
  -or -ot -o outputs/findings.jsonl -duc -silent
```

Summarize it:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  jq -r '[."template-id", .info.severity, ."matched-at"] | @tsv' \
  outputs/findings.jsonl
```

## Severity And Tags

Filter by severity:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  nuclei -u http://target:8080 -t templates -severity medium -duc -silent
```

Filter by tag:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  nuclei -u http://target:8080 -t templates -tags exposure -duc -silent
```

## Useful Options

| Option | Use |
| --- | --- |
| `-u URL` | Target URL. |
| `-t PATH` | Template file or directory. |
| `-silent` | Print only findings. |
| `-jsonl` | Write one JSON object per finding. |
| `-or` | Omit raw request and response data from machine-readable output. |
| `-ot` | Omit encoded template data from machine-readable output. |
| `-o FILE` | Save output to a file. |
| `-severity medium,high` | Filter templates by severity. |
| `-tags exposure` | Filter templates by tag. |
| `-rl 10` | Limit requests per second. |
| `-c 5` | Limit template concurrency. |
| `-stats` | Print scan statistics. |
| `-validate` | Validate template syntax before scanning. |
| `-duc` | Disable update checks during local practice. |

## Generate Practice Scans

Run a quick nuclei sweep:

```bash
sh labs/nuclei/make_scans.sh
```

This writes JSONL findings, a focused JSONL finding, a TSV summary, nuclei
version output, and an HTTP status check into `labs/nuclei/outputs`.

## Practice Tasks

1. Run all local templates and group findings by severity.
2. Inspect `templates/local-backup-config.yaml` and identify the matcher and extractor.
3. Verify `/debug`, `/backup/config.json`, and `/.env` manually with `curl`.
4. Run only `medium` severity templates and compare the output volume.
5. Run only templates tagged `headers`.
6. Save JSONL output and build your own `jq` summary.
7. Explain why reviewing templates matters before scanning a real target.

## Troubleshooting

If nuclei cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  curl -sS http://target:8080/api/status | jq .
```

If a template does not run, validate the local templates:

```bash
docker compose -f labs/nuclei/docker-compose.yml exec scanner \
  nuclei -validate -t templates -duc
```

If Compose reports that port `18095` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18095:8080` to `127.0.0.1:28095:8080`.
