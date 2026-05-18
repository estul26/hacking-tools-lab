# Katana Guide And Local Crawling Workflow Lab

This lab teaches ProjectDiscovery `katana` with a real local crawl target. You
can practice standard crawling, JavaScript endpoint extraction, form discovery,
known-file crawling, JSONL output handling, scope filtering, and local
validation against assets you control.

`katana` is a web crawler and spidering framework. This lab keeps the target
inside Docker so crawling stays authorized, repeatable, and safe. The target
serves HTML links, forms, JavaScript routes, `robots.txt`, and `sitemap.xml` so
you can see how different crawler features affect discovery.

## Safety Rules

- Crawl only sites and applications you own or have explicit permission to assess.
- Keep URLs, depth, rate limits, forms, headers, cookies, and headless settings inside scope.
- Do not submit forms that could mutate production data unless your authorization covers it.
- Treat discovered paths as leads; validate exposure and sensitivity separately.
- Start with conservative depth and concurrency until you understand target load.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the validation
target to localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.56.60.10` | Runs `katana`, `curl`, `jq`, `python3`, and stores output. |
| `target` | `172.56.60.20` | Local web app with links, forms, JS routes, robots, and sitemap. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18102` | `target:8080` | Local crawl target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/katana/docker-compose.yml up --build -d
docker compose -f labs/katana/docker-compose.yml ps
docker compose -f labs/katana/docker-compose.yml exec scanner katana -version
docker compose -f labs/katana/docker-compose.yml exec scanner katana -h
```

Open the crawl target:

```bash
open http://127.0.0.1:18102/
```

Clean up when finished:

```bash
docker compose -f labs/katana/docker-compose.yml down
```

## Basic Crawl

Run a standard crawl against the local target:

```bash
docker compose -f labs/katana/docker-compose.yml exec scanner \
  katana -u http://172.56.60.20:8080 -silent -no-color -depth 2
```

The target includes normal links such as `/about`, `/products`, `/login`, and
`/search?q=packet`.

## Crawl More Sources

Enable JavaScript parsing, known files, forms, and JSONL output:

```bash
docker compose -f labs/katana/docker-compose.yml exec scanner \
  katana -u http://172.56.60.20:8080 -silent -no-color -depth 3 \
  -js-crawl -known-files all -form-extraction \
  -jsonl -o outputs/crawl.jsonl
```

The local JavaScript file references API and debug endpoints, while
`robots.txt` and `sitemap.xml` add more crawl leads.

## Parse Output

Extract crawled endpoints from JSONL output:

```bash
docker compose -f labs/katana/docker-compose.yml exec scanner \
  jq -r '.request.endpoint // .url? // empty' outputs/crawl.jsonl | sort -u
```

Filter paths to the allowed local scope:

```bash
docker compose -f labs/katana/docker-compose.yml exec scanner \
  sh -c 'jq -r ".request.endpoint // .url? // empty" outputs/crawl.jsonl | python3 -c "import sys; from urllib.parse import urlparse; [print(urlparse(line.strip()).path or \"/\") for line in sys.stdin if line.strip()]" | sort -u | comm -12 scope/allow-paths.txt -'
```

## Validate Locally

Manually validate one discovered endpoint:

```bash
docker compose -f labs/katana/docker-compose.yml exec scanner \
  curl -i "http://172.56.60.20:8080/api/v1/users?id=1"
```

The expected response is JSON from the local API validation surface.

## Useful Options

| Option | Use |
| --- | --- |
| `-u URL` | Crawl one URL. |
| `-list FILE` | Read targets from a file. |
| `-depth 3` | Limit crawl depth. |
| `-js-crawl` | Parse JavaScript files for endpoints. |
| `-known-files all` | Crawl known files such as robots and sitemap files. |
| `-form-extraction` | Extract form targets and parameters. |
| `-jsonl` | Write JSONL output. |
| `-o FILE` | Save output to a file. |
| `-output-template TEMPLATE` | Control output formatting. |
| `-rate-limit 5` | Limit requests per second. |
| `-concurrency 5` | Control concurrent crawling. |
| `-crawl-scope REGEX` | Restrict crawl scope with a regex. |
| `-headless` | Use browser-based crawling when needed. |
| `-version` | Show version information. |

## Generate Practice Outputs

Run a quick Katana workflow:

```bash
sh labs/katana/make_scans.sh
```

This writes version/help output, crawl JSONL, raw endpoints, unique paths,
parameterized URLs, filtered in-scope paths, local validation results, logs, and
a TSV summary into `labs/katana/outputs`.

## Practice Tasks

1. Run the basic crawl and compare it to the feature-rich crawl.
2. Explain which endpoints came from HTML, JavaScript, forms, robots, or sitemap.
3. Extract unique paths from `outputs/crawl.jsonl`.
4. Compare `outputs/paths.txt`, `outputs/parameterized-urls.txt`, and `outputs/validation.tsv`.
5. Adjust `-depth` and describe how crawl depth changes discovery.
6. Add `-rate-limit` and explain why crawl pacing matters.
7. Write a safe Katana command for an application you are authorized to assess.

## Troubleshooting

If validation cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/katana/docker-compose.yml exec scanner \
  curl -sS http://172.56.60.20:8080/health | jq .
```

If crawling finds fewer paths than expected, check crawl depth, known-file
settings, JavaScript crawling, form extraction, and the crawl log in
`outputs/crawl.log`.

If Compose reports that port `18102` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18102:8080` to `127.0.0.1:28102:8080`.
