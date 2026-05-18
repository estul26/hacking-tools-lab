# Sqlmap Guide And Local Lab

This lab teaches `sqlmap` with a Docker web target published to `127.0.0.1`.
You can practice SQL injection detection, table listing, small data dumps,
POST request testing, cookie testing, output review, and manual verification
against a target you control.

Sqlmap automates SQL injection testing. It is powerful, noisy, and easy to aim
at the wrong place, so use it only inside an approved scope. The target in this
lab is intentionally vulnerable and backed by a tiny local SQLite database.

## Safety Rules

- Test only applications you own or have explicit permission to assess.
- Keep scans scoped to approved hosts, ports, paths, and parameters.
- Do not run sqlmap against production systems without a written scope.
- Use conservative options first, then increase depth only when approved.
- Treat automated results as leads to verify manually.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.47.170.10` | Runs `sqlmap`, `curl`, `jq`, and stores output. |
| `target` | `172.47.170.20` | SQLite-backed HTTP app with known injection points. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18093` | `target:8080` | Sqlmap practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/sqlmap/docker-compose.yml up --build -d
docker compose -f labs/sqlmap/docker-compose.yml ps
docker compose -f labs/sqlmap/docker-compose.yml exec scanner sqlmap --version
```

Open the target:

```bash
open http://127.0.0.1:18093
```

Clean up when finished:

```bash
docker compose -f labs/sqlmap/docker-compose.yml down
```

## Detect A GET Injection

The `/product` route intentionally places the `id` parameter into a SQLite
query without binding it.

```bash
docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  sqlmap -u "http://target:8080/product?id=1" \
  --batch --dbms=SQLite --level=1 --risk=1 --flush-session
```

Expected result: sqlmap reports that the `id` parameter is injectable.

## List Tables

Ask sqlmap to enumerate the small local database:

```bash
docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  sqlmap -u "http://target:8080/product?id=1" \
  --batch --dbms=SQLite --level=1 --risk=1 --tables --flush-session
```

Expected tables include `products`, `users`, `notes`, and `api_tokens`.

## Dump A Small Lab Table

Dump only the fake training `users` table:

```bash
docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  sqlmap -u "http://target:8080/product?id=1" \
  --batch --dbms=SQLite --level=1 --risk=1 -T users --dump --flush-session
```

This data is synthetic and exists only for local practice.

## Test A POST Body

Send a POST body and point sqlmap at a specific parameter:

```bash
docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  sqlmap -u "http://target:8080/login" \
  --data "username=admin&password=packetlab" -p username \
  --batch --dbms=SQLite --level=1 --risk=1 --flush-session
```

Expected result: sqlmap reports the `username` POST parameter as injectable.

## Test A Cookie

The `/profile` route reads `user_id` from a cookie. Use `-p user_id` so sqlmap
focuses on the intended local parameter:

```bash
docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  sqlmap -u "http://target:8080/profile" --cookie "user_id=1" \
  --param-filter=COOKIE -p user_id \
  --batch --dbms=SQLite --level=2 --risk=1 --flush-session
```

Expected result: sqlmap reports the `user_id` cookie parameter as injectable.

## Manual Verification

Compare true and false conditions with `curl`:

```bash
docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  curl -i "http://target:8080/product?id=1%20AND%201=1"

docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  curl -i "http://target:8080/product?id=1%20AND%201=2"
```

The first request returns the product table. The second returns no matching
rows. This is the manual shape sqlmap is automating.

## Useful Options

| Option | Use |
| --- | --- |
| `-u URL` | Target URL. |
| `-r FILE` | Read a raw HTTP request from a file. |
| `-p NAME` | Test a specific parameter. |
| `--cookie VALUE` | Send a Cookie header. |
| `--data VALUE` | Send a POST body directly. |
| `--param-filter=COOKIE` | Restrict tests to cookie parameters. |
| `--batch` | Use default answers for prompts. |
| `--dbms=SQLite` | Tell sqlmap the lab database type. |
| `--level 1` | Keep request depth conservative. |
| `--risk 1` | Keep payload risk conservative. |
| `--tables` | List database tables. |
| `-T users --dump` | Dump only the selected table. |
| `--flush-session` | Avoid reusing cached detection data. |
| `--output-dir DIR` | Save sqlmap session output under a chosen directory. |

## Generate Practice Scans

Run a quick sqlmap sweep:

```bash
sh labs/sqlmap/make_scans.sh
```

This writes detection logs, table output, a small `users` dump, a raw POST
request file, TSV summary, sqlmap session output, and an HTTP status check into
`labs/sqlmap/outputs`.

## Practice Tasks

1. Detect the injectable `id` GET parameter.
2. List the lab database tables.
3. Dump only the fake `users` table and identify why it would be sensitive in a
   real app.
4. Detect the `username` POST-body injection with `--data` and `-p username`.
5. Detect the `user_id` cookie injection.
6. Compare sqlmap output with manual `curl` true and false checks.
7. Explain how parameterized SQL queries would fix each target route.

## Troubleshooting

If sqlmap cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/sqlmap/docker-compose.yml exec scanner \
  curl -sS http://target:8080/api/status | jq .
```

If sqlmap reports cached results you do not expect, add `--flush-session` or
remove `labs/sqlmap/outputs/sqlmap-output`.

If Compose reports that port `18093` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18093:8080` to `127.0.0.1:28093:8080`.
