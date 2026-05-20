# Kerbrute Guide And Local Kerberos Lab

This lab teaches `kerbrute` against a deliberately small local Kerberos realm.
You can practice user enumeration, a scoped password spray, single-user
password testing, and Kerberos success/failure review without touching a real
directory or domain controller.

`kerbrute` sends Kerberos authentication requests and uses KDC responses to
identify valid principals and credentials. That can lock accounts, reveal
identity data, or generate noisy authentication logs on real infrastructure.
This lab keeps everything on a private Docker network and uses toy principals.

## Safety Rules

- Use Kerbrute only against Kerberos realms you own or have explicit permission to assess.
- Keep realms, domain controllers, usernames, passwords, and thread counts inside scope.
- Do not run password sprays against production users without written authorization and lockout guidance.
- Treat valid usernames and credentials as sensitive information.
- Use low thread counts and safe timing when practicing outside this lab.
- Keep this lab on the private Docker network unless your authorization covers another target.

## Lab Topology

The Compose file creates a private Docker bridge network. No Kerberos port is
published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.66.88.10` | Runs `kerbrute`, `kinit`, `nc`, and stores output. |
| `target` | `172.66.88.20` | Runs a MIT Kerberos KDC for `PACKETLAB.LOCAL`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `wordlists` | Toy username and password lists. |
| `outputs` | Generated Kerbrute output, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/kerbrute/docker-compose.yml up --build -d
docker compose -f labs/kerbrute/docker-compose.yml ps
docker compose -f labs/kerbrute/docker-compose.yml exec scanner kerbrute version
```

Clean up when finished:

```bash
docker compose -f labs/kerbrute/docker-compose.yml down
```

## Local Realm

The target intentionally creates this local realm:

```text
PACKETLAB.LOCAL
```

Toy principals:

| Principal | Password |
| --- | --- |
| `alice` | `Winter2026!` |
| `bob` | `Builder2026!` |
| `svc-backup` | `Backup2026!` |

Use only these toy principals and passwords in this lab.

## Basic Usage

Enumerate valid usernames from the toy list:

```bash
docker compose -f labs/kerbrute/docker-compose.yml exec scanner \
  kerbrute userenum --dc 172.66.88.20 --domain PACKETLAB.LOCAL --threads 2 wordlists/users.txt
```

Run a tiny scoped password spray with one lab password:

```bash
docker compose -f labs/kerbrute/docker-compose.yml exec scanner \
  kerbrute passwordspray --dc 172.66.88.20 --domain PACKETLAB.LOCAL --threads 2 \
  wordlists/users.txt 'Winter2026!'
```

Test a single user against the toy password list:

```bash
docker compose -f labs/kerbrute/docker-compose.yml exec scanner \
  kerbrute bruteuser --dc 172.66.88.20 --domain PACKETLAB.LOCAL --threads 2 \
  wordlists/passwords.txt alice
```

Compare with a direct Kerberos client check:

```bash
docker compose -f labs/kerbrute/docker-compose.yml exec scanner \
  sh -lc "printf '%s\n' 'Winter2026!' | kinit alice@PACKETLAB.LOCAL && kdestroy"
```

## Useful Options

| Option | Use |
| --- | --- |
| `userenum` | Enumerate valid Kerberos principals from a username list. |
| `passwordspray` | Try one password across a username list. |
| `bruteuser` | Try a password list against one username. |
| `--dc IP` | Set the KDC/domain controller address. |
| `--domain REALM` | Set the Kerberos realm/domain. |
| `--threads N` | Limit concurrency; keep it low for labs and authorized work. |
| `--safe` | Stop when lockout-like behavior is detected. |

## Generate Practice Outputs

Run a quick Kerbrute workflow:

```bash
sh labs/kerbrute/make_scans.sh
```

This writes help/version output, user enumeration, scoped password spray,
single-user bruteuser output, direct `kinit` success/failure checks, validation
results, and a TSV summary into `labs/kerbrute/outputs`.

## Practice Tasks

1. Run `kerbrute --help` and identify the three commands used in this lab.
2. Run `userenum` and identify which names are valid principals.
3. Run `passwordspray` with `Winter2026!` and explain why only one user should match.
4. Run `bruteuser` against `alice` and identify the matching password.
5. Compare Kerbrute output with `kinit` success and failure behavior.
6. Inspect `outputs/validation.tsv` after running the helper.
7. Write a safe Kerbrute command for a realm you are authorized to assess.

## Troubleshooting

If Kerbrute cannot reach the KDC, confirm port 88 is reachable from the
scanner:

```bash
docker compose -f labs/kerbrute/docker-compose.yml exec scanner nc -vz 172.66.88.20 88
```

If Kerberos authentication fails unexpectedly, check the target logs:

```bash
docker compose -f labs/kerbrute/docker-compose.yml logs target
```

If Kerbrute output changes in a future version, inspect the raw files in
`outputs` and update the validation markers to match the new wording.
