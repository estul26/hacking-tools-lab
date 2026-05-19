# Crunch Guide And Local Wordlist Lab

This lab teaches Crunch with local, deliberately tiny wordlist-generation
examples. You can practice character sets, pattern masks, start/end ranges,
permutations, output files, and wordlist size checks without targeting any live
system.

Crunch generates candidate wordlists from rules you define. It is useful for
authorized password-audit labs and for learning how quickly wordlist sizes grow,
but the output can become huge if ranges are too broad. This lab keeps examples
small and writes generated files into an ignored `outputs` directory.

## Safety Rules

- Generate wordlists only for authorized training or assessment work.
- Keep ranges small until you understand the output size.
- Check line counts and estimated size before creating large files.
- Store generated wordlists carefully because they may contain sensitive patterns.
- Do not use generated candidates for login attempts unless your authorization explicitly covers that testing.
- Delete generated outputs when they are no longer needed.

## Lab Topology

This Compose lab uses one scanner container and local mounted output storage.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `crunch` and writes generated wordlists to `outputs`. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated wordlists, logs, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/crunch/docker-compose.yml up --build -d
docker compose -f labs/crunch/docker-compose.yml ps
docker compose -f labs/crunch/docker-compose.yml exec scanner crunch
```

Clean up when finished:

```bash
docker compose -f labs/crunch/docker-compose.yml down
```

## Basic Character Set

Generate every two-character word using `a` and `b`:

```bash
docker compose -f labs/crunch/docker-compose.yml exec scanner \
  crunch 2 2 ab -o outputs/basic-ab.txt
```

Expected output:

```text
aa
ab
ba
bb
```

## Pattern Masks

Use a mask to keep a fixed prefix and vary one digit:

```bash
docker compose -f labs/crunch/docker-compose.yml exec scanner \
  crunch 4 4 -t lab% -o outputs/pattern-lab-digit.txt
```

The `%` placeholder represents numbers, so this creates `lab0` through `lab9`.

Common Crunch mask placeholders:

| Placeholder | Meaning |
| --- | --- |
| `@` | Lowercase letters. |
| `,` | Uppercase letters. |
| `%` | Numbers. |
| `^` | Symbols. |

## Custom Character Sets

Generate three-character words from a custom character set:

```bash
docker compose -f labs/crunch/docker-compose.yml exec scanner \
  crunch 3 3 xyz -o outputs/custom-charset.txt
```

This creates combinations such as `xxx`, `xxy`, `xyz`, and `zzz`.

## Start And End Ranges

Use `-s` and `-e` to constrain a run:

```bash
docker compose -f labs/crunch/docker-compose.yml exec scanner \
  crunch 3 3 abc -s aba -e abb -o outputs/start-end-range.txt
```

This is useful when splitting a larger job into smaller pieces.

## Permutations

Use `-p` to permute whole words:

```bash
docker compose -f labs/crunch/docker-compose.yml exec scanner \
  crunch 1 1 -p red blue green > outputs/permutations.txt
```

Crunch ignores min/max length during `-p` mode and generates permutations of
the supplied words.

## Useful Options

| Option | Use |
| --- | --- |
| `crunch 2 4 abc` | Generate lengths 2 through 4 using `a`, `b`, and `c`. |
| `-o FILE` | Write generated candidates to a file. |
| `-t PATTERN` | Use a fixed pattern with placeholders. |
| `-s WORD` | Start generation at a specific candidate. |
| `-e WORD` | End generation at a specific candidate. |
| `-p WORDS...` | Generate permutations of whole words. |
| `-d N@` | Limit duplicate lowercase characters. |
| `-b SIZE` | Split output files by size. |
| `-c LINES` | Split output files by line count. |
| `-z gzip` | Compress output chunks with gzip. |

## Generate Practice Outputs

Run a quick Crunch workflow:

```bash
sh labs/crunch/make_scans.sh
```

This writes help/version output, generated wordlists, Crunch logs, validation
results, and a TSV summary into `labs/crunch/outputs`.

## Practice Tasks

1. Generate `outputs/basic-ab.txt` and explain why it has four lines.
2. Change the character set from `ab` to `abc` and compare the line count.
3. Generate a masked list with `-t lab%` and identify the variable position.
4. Use `-s` and `-e` to split a small range.
5. Run the permutation example and compare it with character-set generation.
6. Estimate how many lines `crunch 1 5 abcdef` would create before running it.
7. Write a safe Crunch command for a password-audit lab you are authorized to run.

## Troubleshooting

If output is much larger than expected, stop the command and reduce the min/max
length, character set, or mask breadth.

If Compose reports that the scanner is not running, restart the lab:

```bash
docker compose -f labs/crunch/docker-compose.yml down
docker compose -f labs/crunch/docker-compose.yml up --build -d
```

If generated files are missing, check the matching `.log` file in
`labs/crunch/outputs` for Crunch's size estimate and command output.
