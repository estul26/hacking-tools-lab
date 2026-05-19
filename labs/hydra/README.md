# Hydra Guide And Local Authentication Lab

This lab teaches THC Hydra against a deliberately small local authentication
target. You can practice HTTP Basic auth testing, HTTP form testing, tiny
wordlists, output review, and safe password-audit hygiene against assets you
control.

Hydra is a login testing tool for many network protocols. It can generate a lot
of traffic and can lock accounts or trigger defenses on real systems. This lab
keeps everything inside Docker, uses a tiny known credential set, and publishes
the target only to `127.0.0.1`.

## Safety Rules

- Test credentials only on systems and accounts you own or have explicit permission to assess.
- Keep targets, ports, usernames, wordlists, threads, and timing inside scope.
- Do not run Hydra against production identity systems without written authorization.
- Use small wordlists and conservative thread counts until you understand target impact.
- Treat found credentials as sensitive secrets, even in labs.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the HTTP target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.57.70.10` | Runs `hydra`, `curl`, `jq`, and stores output. |
| `target` | `172.57.70.20` | Local HTTP Basic and form-login target. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18103` | `target:8080` | Local authentication target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/hydra/docker-compose.yml up --build -d
docker compose -f labs/hydra/docker-compose.yml ps
docker compose -f labs/hydra/docker-compose.yml exec scanner hydra -h
```

Open the target:

```bash
open http://127.0.0.1:18103/
```

Clean up when finished:

```bash
docker compose -f labs/hydra/docker-compose.yml down
```

## Local Credentials

The target intentionally accepts one local lab credential:

```text
admin:packetlab
```

The wordlists are tiny and live in `wordlists/users.txt` and
`wordlists/passwords.txt`.

## HTTP Basic Auth

Confirm the Basic auth endpoint manually:

```bash
docker compose -f labs/hydra/docker-compose.yml exec scanner \
  curl -i -u admin:packetlab http://172.57.70.20:8080/basic
```

Run Hydra against the local Basic auth endpoint:

```bash
docker compose -f labs/hydra/docker-compose.yml exec scanner \
  hydra -L wordlists/users.txt -P wordlists/passwords.txt \
  -s 8080 -t 2 -w 5 -f -I 172.57.70.20 http-get /basic
```

Expected result: `admin` / `packetlab`.

## HTTP Form Login

Confirm the form behavior manually:

```bash
docker compose -f labs/hydra/docker-compose.yml exec scanner \
  curl -i -d "username=admin&password=packetlab" \
  http://172.57.70.20:8080/login
```

Run Hydra against the local form:

```bash
docker compose -f labs/hydra/docker-compose.yml exec scanner \
  hydra -L wordlists/users.txt -P wordlists/passwords.txt \
  -s 8080 -t 2 -w 5 -f -I 172.57.70.20 \
  http-post-form "/login:username=^USER^&password=^PASS^:F=Invalid login"
```

The failure marker is `Invalid login`, so Hydra treats responses without that
text as successful.

## Useful Options

| Option | Use |
| --- | --- |
| `-l USER` | Test one username. |
| `-L FILE` | Read usernames from a file. |
| `-p PASS` | Test one password. |
| `-P FILE` | Read passwords from a file. |
| `-s PORT` | Set the target port. |
| `-t 2` | Set a conservative task count. |
| `-w 5` | Set response wait timeout. |
| `-f` | Stop after the first valid credential for a host. |
| `-I` | Ignore restore files during repeatable lab runs. |
| `-o FILE` | Save Hydra findings. |
| `http-get /path` | Test HTTP Basic auth on a path. |
| `http-post-form "path:params:condition"` | Test an HTTP form. |

## Generate Practice Outputs

Run a quick Hydra workflow:

```bash
sh labs/hydra/make_scans.sh
```

This writes help/version output, manual curl checks, Hydra Basic and form-login
results, logs, and a TSV summary into `labs/hydra/outputs`.

## Practice Tasks

1. Compare unauthorized and authorized responses for `/basic`.
2. Explain why the form module needs a failure marker.
3. Run Basic auth and form-login tests with the tiny local wordlists.
4. Change `-t` from `2` to `1` and compare runtime and target logs.
5. Save output with `-o` and extract the found credential.
6. Add a decoy password to the wordlist and rerun the helper.
7. Write a safe Hydra command for a system you are authorized to assess.

## Troubleshooting

If Hydra finds no credentials, confirm the target is healthy:

```bash
docker compose -f labs/hydra/docker-compose.yml exec scanner \
  curl -sS http://172.57.70.20:8080/health | jq .
```

If form testing fails, confirm the failure marker still appears in bad login
responses:

```bash
docker compose -f labs/hydra/docker-compose.yml exec scanner \
  curl -sS -d "username=admin&password=wrong" \
  http://172.57.70.20:8080/login
```

If Compose reports that port `18103` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18103:8080` to `127.0.0.1:28103:8080`.
