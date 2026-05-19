# HashID Guide And Local Hash Identification Lab

This lab teaches HashID with local sample hashes. You can practice identifying
candidate hash types, viewing Hashcat modes, viewing John the Ripper formats,
running extended detection, and understanding why hash identification often
produces several possible answers.

HashID does not crack passwords. It inspects hash strings and reports likely
formats based on length, prefix, alphabet, and structure. A raw 32-character hex
hash can match many algorithms, so treat HashID output as triage rather than a
final answer.

## Safety Rules

- Analyze only hashes you own or have explicit permission to assess.
- Treat hash samples and identification output as sensitive.
- Do not upload real hashes to public services.
- Confirm candidates with context such as source system, prefix, salt format, and cracking-tool mode.
- Use local sample hashes until you understand ambiguous output.
- Delete generated outputs when they are no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted files.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `hashid`, reads local sample hashes, and stores output. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `hashes` | Local sample hashes and expected candidate metadata. |
| `outputs` | Generated HashID reports, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/hashid/docker-compose.yml up --build -d
docker compose -f labs/hashid/docker-compose.yml ps
docker compose -f labs/hashid/docker-compose.yml exec scanner hashid --version
docker compose -f labs/hashid/docker-compose.yml exec scanner hashid --help
```

Clean up when finished:

```bash
docker compose -f labs/hashid/docker-compose.yml down
```

## Sample Hashes

The lab includes local demo hashes:

| Label | Example | Expected candidate |
| --- | --- | --- |
| `raw-md5` | `7bdd907b655554a1d025bb4f3a45dac0` | `MD5` |
| `raw-sha256` | `a7573b4627847cb95647f0c93327d549fae425b5c9ed0293502c04d9c3e49c43` | `SHA-256` |
| `md5crypt` | `$1$aa$cXF0EJ/VMCwoNlY4/xPlT.` | `MD5 Crypt` |
| `bcrypt` | `$2y$10$usesomesillystringfore7hnbRJHxXVLeakoG8K30oukPsA.ztMG` | `bcrypt` |

## Identify One Hash

Run HashID against a single raw MD5 sample:

```bash
docker compose -f labs/hashid/docker-compose.yml exec scanner \
  hashid -m -j 7bdd907b655554a1d025bb4f3a45dac0
```

The `-m` flag includes Hashcat modes, and `-j` includes John the Ripper formats.

## Identify A File

Run HashID against all local samples:

```bash
docker compose -f labs/hashid/docker-compose.yml exec scanner \
  hashid -m -j hashes/samples.txt
```

Raw hashes can produce many candidates. Prefix-based hashes such as `$1$...`
and `$2y$...` are usually more specific because the prefix carries format
information.

## Extended Detection

Use extended mode to include more salted password candidates:

```bash
docker compose -f labs/hashid/docker-compose.yml exec scanner \
  hashid --extended -m -j hashes/samples.txt
```

Extended mode is useful for broad triage, but it also increases noise.

## Useful Options

| Option | Use |
| --- | --- |
| `-m` | Show matching Hashcat mode numbers. |
| `-j` | Show matching John the Ripper format names. |
| `--extended` | Include additional possible algorithms, including salted formats. |
| `--outfile FILE` | Write output to a file. |
| `--version` | Show the installed HashID version. |
| `--help` | Show command help. |

## Generate Practice Outputs

Run a quick HashID workflow:

```bash
sh labs/hashid/make_scans.sh
```

This writes help/version output, standard identification output, extended
identification output, one report per sample hash, validation results, and a TSV
summary into `labs/hashid/outputs`.

## Practice Tasks

1. Identify the raw MD5 sample and list at least three possible candidates.
2. Identify the SHA-256 sample and find Hashcat mode `1400`.
3. Identify the MD5 Crypt sample and find John format `md5crypt`.
4. Identify the bcrypt sample and find Hashcat mode `3200`.
5. Compare normal output with `--extended` output.
6. Explain why raw hex hashes are more ambiguous than prefixed hashes.
7. Write a safe HashID command for hashes you are authorized to assess.

## Troubleshooting

If output is empty, confirm the sample file is mounted:

```bash
docker compose -f labs/hashid/docker-compose.yml exec scanner \
  sed -n '1,20p' hashes/samples.txt
```

If a candidate is missing, rerun with `--extended` and check whether the hash
string includes the expected prefix, salt, and length.

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/hashid/docker-compose.yml down
docker compose -f labs/hashid/docker-compose.yml up --build -d
```
