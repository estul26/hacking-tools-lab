# Hashcat Guide And Local Hash Lab

This lab teaches Hashcat with local sample hashes, a tiny wordlist, and a CPU
OpenCL runtime. You can practice mode selection, wordlist attacks, potfile
handling, `--show` review, device checks, and safe password-audit hygiene
without touching any live system.

Hashcat is an offline password-auditing tool. It is powerful, fast, and can use
GPU or CPU OpenCL devices. This Docker lab installs a CPU OpenCL backend so the
practice workflow can run on a normal local machine without a passed-through
GPU.

## Safety Rules

- Audit only hashes you own or have explicit permission to test.
- Keep hash files, wordlists, potfiles, and cracked credentials inside scope.
- Treat cracked passwords as secrets, even in a lab.
- Do not upload real hashes or potfiles to public services.
- Use small local examples until you understand modes, devices, and runtime.
- Delete generated outputs when they are no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted files.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `hashcat`, reads local hashes and wordlists, and stores output. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `hashes` | Local sample hash files. |
| `wordlists` | Tiny local password lists. |
| `outputs` | Generated crack logs, potfiles, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/hashcat/docker-compose.yml up --build -d
docker compose -f labs/hashcat/docker-compose.yml ps
docker compose -f labs/hashcat/docker-compose.yml exec scanner hashcat --version
docker compose -f labs/hashcat/docker-compose.yml exec scanner hashcat -I
```

Clean up when finished:

```bash
docker compose -f labs/hashcat/docker-compose.yml down
```

## Sample Hashes

The lab includes weak demo hashes:

| File | Hashcat mode | Format | Expected passwords |
| --- | --- | --- | --- |
| `hashes/md5.txt` | `0` | Raw MD5 | `packetlab`, `letmein`, `spring2026` |
| `hashes/sha256.txt` | `1400` | Raw SHA-256 | `packetlab` |

The tiny wordlist lives at `wordlists/passwords.txt`.

## Crack Raw MD5

Run Hashcat against the local MD5 hash file:

```bash
docker compose -f labs/hashcat/docker-compose.yml exec scanner \
  hashcat -m 0 -a 0 hashes/md5.txt wordlists/passwords.txt
```

Show cracked results:

```bash
docker compose -f labs/hashcat/docker-compose.yml exec scanner \
  hashcat -m 0 --show hashes/md5.txt
```

## Crack Raw SHA-256

Run Hashcat against the local SHA-256 hash file:

```bash
docker compose -f labs/hashcat/docker-compose.yml exec scanner \
  hashcat -m 1400 -a 0 hashes/sha256.txt wordlists/passwords.txt
```

Show cracked results:

```bash
docker compose -f labs/hashcat/docker-compose.yml exec scanner \
  hashcat -m 1400 --show hashes/sha256.txt
```

## Useful Options

| Option | Use |
| --- | --- |
| `-m 0` | Raw MD5 mode. |
| `-m 1400` | Raw SHA-256 mode. |
| `-a 0` | Straight wordlist attack. |
| `--show` | Show cracked passwords for a hash file. |
| `--potfile-path FILE` | Use a specific potfile for repeatable labs. |
| `--outfile FILE` | Save cracked results. |
| `--outfile-format 2` | Save plaintext-only output. |
| `-I` | List available compute devices. |
| `--session NAME` | Name a cracking session. |
| `--restore` | Restore an interrupted session. |

## Generate Practice Outputs

Run a quick Hashcat workflow:

```bash
sh labs/hashcat/make_scans.sh
```

This writes version/help output, device information, copied sample hashes,
crack logs, potfiles, plaintext outputs, `--show` output, and a TSV summary
into `labs/hashcat/outputs`.

## Practice Tasks

1. Run `hashcat -I` and identify the CPU OpenCL backend.
2. Crack `hashes/md5.txt` with mode `0`.
3. Crack `hashes/sha256.txt` with mode `1400`.
4. Inspect potfiles and explain why they are sensitive.
5. Add a new password to the wordlist and rerun the helper.
6. Compare `--outfile` output with `--show` output.
7. Write a safe Hashcat command for hashes you are authorized to audit.

## Troubleshooting

If Hashcat cannot find a device, confirm the CPU OpenCL runtime is visible:

```bash
docker compose -f labs/hashcat/docker-compose.yml exec scanner hashcat -I
```

If results are missing, remove generated outputs and rerun:

```bash
rm -f labs/hashcat/outputs/*
sh labs/hashcat/make_scans.sh
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/hashcat/docker-compose.yml down
docker compose -f labs/hashcat/docker-compose.yml up --build -d
```
