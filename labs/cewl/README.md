# CeWL Guide And Local Wordlist Lab

This lab teaches CeWL with a real local web target. You can practice crawling
pages you control, generating custom wordlists, extracting email addresses,
counting words, comparing crawl depth, and excluding paths from a spider run.

CeWL builds wordlists from website content. That makes it useful for authorized
password-audit preparation, security-awareness labs, and reconnaissance
practice, but it can also collect sensitive terms. This lab keeps everything
inside Docker and binds the target only to localhost.

## Safety Rules

- Crawl only sites and applications you own or have explicit permission to assess.
- Treat generated wordlists as sensitive because they can reveal internal names and project terms.
- Keep email extraction, depth, offsite crawling, and custom headers inside scope.
- Do not use generated words for login attempts unless your authorization explicitly covers that testing.
- Avoid `--offsite` unless you intentionally want to leave the starting domain.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.58.80.10` | Runs `cewl`, `curl`, `jq`, `python3`, and stores output. |
| `target` | `172.58.80.20` | Local web app with word-rich pages and demo email addresses. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18104` | `target:8080` | Local CeWL crawl target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/cewl/docker-compose.yml up --build -d
docker compose -f labs/cewl/docker-compose.yml ps
docker compose -f labs/cewl/docker-compose.yml exec scanner cewl --help
```

Open the target:

```bash
open http://127.0.0.1:18104/
```

Clean up when finished:

```bash
docker compose -f labs/cewl/docker-compose.yml down
```

## Basic Wordlist

Generate a lowercase wordlist from the local target:

```bash
docker compose -f labs/cewl/docker-compose.yml exec scanner \
  cewl --depth 2 --min_word_length 5 --with-numbers --lowercase \
  --write outputs/words.txt http://172.58.80.20:8080
```

Review the results:

```bash
docker compose -f labs/cewl/docker-compose.yml exec scanner \
  sh -c 'sort -u outputs/words.txt | sed -n "1,40p"'
```

## Extract Emails

CeWL can collect email addresses separately from the wordlist:

```bash
docker compose -f labs/cewl/docker-compose.yml exec scanner \
  cewl --depth 2 --min_word_length 5 --with-numbers --lowercase \
  --email --email_file outputs/emails.txt \
  --write outputs/words-with-email-run.txt http://172.58.80.20:8080
```

The local target includes demo-only addresses such as
`training@packetlab.example` and `ops-team@packetlab.example`.

## Exclude Paths

The lab includes `scope/exclude-paths.txt`, which excludes `/private` and
`/debug` during the helper workflow:

```bash
docker compose -f labs/cewl/docker-compose.yml exec scanner \
  cewl --depth 2 --min_word_length 5 --with-numbers --lowercase \
  --exclude scope/exclude-paths.txt --write outputs/scoped.txt \
  http://172.58.80.20:8080
```

Compare a scoped run with an unrestricted run and look for words that only
appear on `/private`.

## Count Words

Add `--count` to see repeated terms:

```bash
docker compose -f labs/cewl/docker-compose.yml exec scanner \
  cewl --depth 2 --min_word_length 5 --with-numbers --lowercase --count \
  --write outputs/counts.txt http://172.58.80.20:8080
```

Terms such as `packetbridge`, `blueharbor`, `sensorboard`, and `trailmap2026`
should appear in the generated output.

## Useful Options

| Option | Use |
| --- | --- |
| `--depth 2` | Spider linked pages up to a chosen depth. |
| `--min_word_length 5` | Ignore shorter words. |
| `--max_word_length 20` | Ignore longer words. |
| `--lowercase` | Normalize output to lowercase. |
| `--with-numbers` | Keep terms that include numbers. |
| `--count` | Include word occurrence counts. |
| `--email` | Include email extraction. |
| `--email_file FILE` | Save extracted email addresses separately. |
| `--exclude FILE` | Skip paths listed in a file. |
| `--allowed REGEX` | Follow only paths matching a regex. |
| `--write FILE` | Save the generated wordlist. |
| `--ua AGENT` | Set a custom user agent. |
| `--header NAME:VALUE` | Add a request header. |
| `--auth_type basic` | Use HTTP authentication when authorized. |
| `--offsite` | Permit crawling to leave the starting site. |

## Generate Practice Outputs

Run a quick CeWL workflow:

```bash
sh labs/cewl/make_scans.sh
```

This writes help output, generated wordlists, counted words, extracted email
addresses, depth comparison output, validation results, logs, and a TSV summary
into `labs/cewl/outputs`.

## Practice Tasks

1. Generate `outputs/words.txt` and identify local project terms.
2. Compare `outputs/words.txt` with `outputs/depth-one.txt`.
3. Extract email addresses and explain why they should be handled carefully.
4. Run CeWL with and without `--exclude scope/exclude-paths.txt`.
5. Use `--count` and identify the most repeated local terms.
6. Change `--min_word_length` and compare the number of generated words.
7. Write a safe CeWL command for a site you are authorized to assess.

## Troubleshooting

If the scanner cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/cewl/docker-compose.yml exec scanner \
  curl -sS http://172.58.80.20:8080/health | jq .
```

If the wordlist is smaller than expected, check crawl depth, minimum word
length, exclude rules, and whether the target pages are linked from the start
URL.

If Compose reports that port `18104` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18104:8080` to `127.0.0.1:28104:8080`.
