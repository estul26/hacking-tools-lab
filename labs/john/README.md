# John The Ripper Guide And Local Hash Lab

This lab teaches John the Ripper with local sample hashes and tiny wordlists.
You can practice format selection, wordlist cracking, pot-file handling,
`--show` review, and safe password-audit hygiene without touching any live
system.

John is an offline password-auditing tool. It can be useful for validating
password policy and incident response, but cracked passwords are sensitive. This
lab uses intentionally weak local demo hashes so the workflow completes quickly
inside Docker.

## Safety Rules

- Audit only hashes you own or have explicit permission to test.
- Keep hash files, wordlists, pot files, and cracked credentials inside scope.
- Treat cracked passwords as secrets, even in a lab.
- Do not upload real hashes or pot files to public services.
- Use small local examples until you understand formats and runtime.
- Delete generated outputs when they are no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted files.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `john`, reads local hashes and wordlists, and stores output. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `hashes` | Local sample hash files. |
| `wordlists` | Tiny local password lists. |
| `outputs` | Generated crack logs, pot files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/john/docker-compose.yml up --build -d
docker compose -f labs/john/docker-compose.yml ps
docker compose -f labs/john/docker-compose.yml exec scanner john
```

Clean up when finished:

```bash
docker compose -f labs/john/docker-compose.yml down
```

## Sample Hashes

The lab includes weak demo hashes:

| File | Format | Expected passwords |
| --- | --- | --- |
| `hashes/md5crypt.txt` | `md5crypt` | `packetlab`, `letmein`, `spring2026` |

The tiny wordlist lives at `wordlists/passwords.txt`.

## Crack md5crypt

Run John against the local md5crypt hash file:

```bash
docker compose -f labs/john/docker-compose.yml exec scanner \
  john --wordlist=wordlists/passwords.txt --format=md5crypt hashes/md5crypt.txt
```

Show cracked results:

```bash
docker compose -f labs/john/docker-compose.yml exec scanner \
  john --show --format=md5crypt hashes/md5crypt.txt
```

## Useful Options

| Option | Use |
| --- | --- |
| `--wordlist=FILE` | Use a specific password list. |
| `--format=FORMAT` | Tell John which hash format to use. |
| `john` | Show the classic John help and compiled formats. |
| `--show` | Show cracked passwords for a hash file. |
| `--session=NAME` | Name a cracking session. |
| `--restore=NAME` | Restore an interrupted session. |
| `--status=NAME` | Check session status. |

## Generate Practice Outputs

Run a quick John workflow:

```bash
sh labs/john/make_scans.sh
```

This writes help/version output, supported formats from the help text, copied
sample hashes, crack logs, John pot data, `--show` output, and a TSV summary
into `labs/john/outputs`.

## Practice Tasks

1. Review supported formats and find `md5crypt`.
2. Crack `hashes/md5crypt.txt` with the local wordlist.
3. Run `--show` before and after cracking.
4. Inspect the pot files and explain why they are sensitive.
5. Add a new password to the wordlist and rerun the helper.
6. Start a named session with `--session=lab-md5`.
7. Write a safe John command for hashes you are authorized to audit.

## Troubleshooting

If John says a format is unknown, check the formats compiled into this package:

```bash
docker compose -f labs/john/docker-compose.yml exec scanner \
  john 2>&1 | grep -A1 -- '--format=NAME'
```

If results are missing, remove generated outputs and rerun:

```bash
rm -f labs/john/outputs/*
sh labs/john/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/john/docker-compose.yml down
docker compose -f labs/john/docker-compose.yml up --build -d
```
