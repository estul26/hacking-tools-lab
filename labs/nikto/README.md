# Nikto Guide And Local Lab

This lab teaches `nikto` with a Docker web target published to `127.0.0.1`.
You can practice web server checks, header review, default-file discovery,
robots review, HTTP method checks, report formats, and finding triage against a
target you control.

Nikto is a web server scanner that looks for known risky files, unsafe server
configuration, interesting headers, outdated-looking components, and common
administrative exposures. Its output is a starting point for manual validation,
not proof that a real system is exploitable.

## Safety Rules

- Scan only web apps you own or have explicit permission to test.
- Keep scans scoped to approved hosts and ports.
- Run Nikto first against a lab or staging target so you understand the volume.
- Do not run Nikto against production systems without a written scope.
- Treat findings as leads to verify manually, not proof of a vulnerability.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.46.160.10` | Runs `nikto`, `curl`, `jq`, and stores output. |
| `target` | `172.46.160.20` | HTTP target with safe, predictable Nikto findings. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18092` | `target:8080` | Nikto practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/nikto/docker-compose.yml up --build -d
docker compose -f labs/nikto/docker-compose.yml ps
docker compose -f labs/nikto/docker-compose.yml exec scanner nikto -Version
```

Open the target:

```bash
open http://127.0.0.1:18092
```

Clean up when finished:

```bash
docker compose -f labs/nikto/docker-compose.yml down
```

## Basic Scan

Run a normal local scan:

```bash
docker compose -f labs/nikto/docker-compose.yml exec scanner \
  nikto -h http://target:8080 -nointeractive -nocheck
```

Expected findings include missing security headers, an old-looking server
banner, a cookie without security flags, HTTP `TRACE`, robots entries,
directory indexing, `/server-status`, `/phpinfo.php`, and sample backup files.

## Focus The Scan

Nikto tuning lets you choose broad categories of checks. This lab uses
`123b` for interesting files, misconfiguration or default files, information
disclosure, and software identification:

```bash
docker compose -f labs/nikto/docker-compose.yml exec scanner \
  nikto -h http://target:8080 -nointeractive -nocheck -Tuning 123b
```

Use tuning when you need a smaller, more explainable scan for a scoped target.

## HTTP Method Checks

Ask the target which methods it advertises:

```bash
docker compose -f labs/nikto/docker-compose.yml exec scanner \
  curl -i -X OPTIONS http://target:8080/
```

Nikto should also notice that `TRACE` is active. This is intentionally enabled
only inside the lab target.

## Review Interesting URLs

Open or request individual findings so you can compare Nikto output with the
actual response:

```bash
docker compose -f labs/nikto/docker-compose.yml exec scanner \
  curl -i http://target:8080/robots.txt

docker compose -f labs/nikto/docker-compose.yml exec scanner \
  curl -i http://target:8080/server-status

docker compose -f labs/nikto/docker-compose.yml exec scanner \
  curl -i http://target:8080/.git/HEAD
```

Manual review is part of the workflow: Nikto tells you where to look, then you
decide whether the finding matters in the real application context.

## Save Output

Save a text report:

```bash
docker compose -f labs/nikto/docker-compose.yml exec scanner \
  nikto -h http://target:8080 -nointeractive -nocheck -Tuning 123b \
  -Format txt -output outputs/baseline
```

Save a CSV report:

```bash
docker compose -f labs/nikto/docker-compose.yml exec scanner \
  nikto -h http://target:8080 -nointeractive -nocheck -Tuning 123b \
  -Format csv -output outputs/baseline
```

## Useful Options

| Option | Use |
| --- | --- |
| `-h URL` | Target host or URL. |
| `-p PORT` | Target port when it is not in the URL. |
| `-ssl` | Force HTTPS checks. |
| `-nointeractive` | Avoid interactive prompts in scripts. |
| `-nocheck` | Skip outbound update checks during local practice. |
| `-Tuning 123b` | Limit scan categories. |
| `-Format txt` | Choose report format. |
| `-output FILE` | Save report output. |
| `-useragent VALUE` | Set a custom user agent. |
| `-id user:pass` | Send HTTP Basic Auth credentials. |
| `-maxtime 60s` | Cap scan duration. |
| `-Display V` | Show verbose output. |

## Generate Practice Scans

Run a quick Nikto sweep:

```bash
sh labs/nikto/make_scans.sh
```

This writes a text report, CSV report, TSV summary, Nikto version file, and an
HTTP status check into `labs/nikto/outputs`.

## Practice Tasks

1. Run the basic scan and group findings by headers, methods, and files.
2. Compare the text report with `outputs/summary.tsv`.
3. Use `curl -i` to manually verify `/robots.txt`, `/server-status`, and
   `/backup/`.
4. Run the same scan with and without `-Tuning 123b` and compare volume.
5. Try authenticated access to `/admin/` with `-id nikto:packetlab`.
6. Save the report as `txt` and `csv`.
7. Explain which findings would matter most on a real internet-facing app.

## Troubleshooting

If Nikto cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/nikto/docker-compose.yml exec scanner \
  curl -sS http://target:8080/api/status | jq .
```

If the scanner image fails to build, check that your network can reach
`github.com`; the Dockerfile pins the upstream Nikto source tag and commit for
repeatable builds.

If Compose reports that port `18092` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18092:8080` to `127.0.0.1:28092:8080`.
