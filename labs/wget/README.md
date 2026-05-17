# Wget Guide And Local Lab

This lab teaches `wget` with a Docker target published to `127.0.0.1`, so you
can practice downloads from your host and from a toolbox container. It is
designed for authorized local practice only.

`wget` is a command-line downloader. It is especially useful for saving files,
following redirects, resuming interrupted downloads, timestamping files, using
HTTP authentication, and recursively mirroring simple sites.

## Safety Rules

- Download only from systems you own or have permission to test.
- Be careful with credentials in shell history.
- Treat downloaded files as untrusted until you know where they came from.
- Use recursive mirroring only against in-scope targets and with conservative limits.
- Keep this lab bound to localhost unless you intentionally need wider access.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `target` | `172.35.60.20` | HTTP target with files, redirects, auth, ranges, and mirror pages. |
| `toolbox` | `172.35.60.10` | Includes GNU Wget. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18081` | `target:8080` | Wget practice HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/wget/docker-compose.yml up --build -d
docker compose -f labs/wget/docker-compose.yml ps
```

Open the target in a browser:

```bash
open http://127.0.0.1:18081
```

Clean up when finished:

```bash
docker compose -f labs/wget/docker-compose.yml down
```

## Basic Downloads

Download to the current directory:

```bash
wget http://127.0.0.1:18081/files/report.txt
```

Choose an output name:

```bash
wget -O labs/wget/downloads/report.txt \
  http://127.0.0.1:18081/files/report.txt
```

Download into a directory:

```bash
wget -P labs/wget/downloads \
  http://127.0.0.1:18081/files/data.csv
```

Quiet mode is useful in scripts:

```bash
wget -q -O labs/wget/downloads/status.json \
  http://127.0.0.1:18081/api/status
```

## Redirects And Status Codes

Wget follows redirects by default:

```bash
wget -O labs/wget/downloads/redirect-report.txt \
  http://127.0.0.1:18081/redirect/report
```

See server response details:

```bash
wget --server-response -O /tmp/wget-status.txt \
  http://127.0.0.1:18081/status/404
```

## Authentication

The lab has a Basic auth endpoint. The credentials are `wget` / `packetlab`.

```bash
wget --user=wget --password=packetlab \
  -O labs/wget/downloads/auth.txt \
  http://127.0.0.1:18081/auth/basic
```

## Resume Downloads

Start a partial file:

```bash
wget -O labs/wget/downloads/big.bin \
  http://127.0.0.1:18081/files/big.bin
```

Resume with `-c` if a download was interrupted:

```bash
wget -c -O labs/wget/downloads/big.bin \
  http://127.0.0.1:18081/files/big.bin
```

The target supports byte ranges so `-c` can request the missing part.

## Timestamping

`-N` asks Wget to use `Last-Modified` data and skip downloading if the local
copy is already current:

```bash
wget -N -P labs/wget/downloads/timestamped \
  http://127.0.0.1:18081/files/report.txt
```

Run it twice and compare the second output.

## Recursive Mirroring

Mirror a tiny local site:

```bash
wget --recursive --level=1 --no-host-directories \
  --directory-prefix=labs/wget/downloads/mirror \
  http://127.0.0.1:18081/mirror/
```

By default, Wget respects `robots.txt` during recursive downloads. The lab links
to `/private/secret.txt`, and `robots.txt` disallows `/private`.

Ignore robots rules only in a controlled lab when you mean to test behavior:

```bash
wget --recursive --level=1 --execute robots=off --no-host-directories \
  --directory-prefix=labs/wget/downloads/mirror-no-robots \
  http://127.0.0.1:18081/mirror/
```

## Use The Toolbox

If your host does not have `wget`, use the toolbox:

```bash
docker compose -f labs/wget/docker-compose.yml exec toolbox \
  wget -q -O - http://target:8080/api/status

docker compose -f labs/wget/docker-compose.yml exec toolbox \
  wget -O /work/downloads/report.txt http://target:8080/files/report.txt

docker compose -f labs/wget/docker-compose.yml exec toolbox \
  wget --recursive --level=1 --no-host-directories \
  --directory-prefix=/work/downloads/mirror http://target:8080/mirror/
```

The toolbox writes into `labs/wget/downloads` through a bind mount.

## Generate Practice Downloads

Run a quick download sweep:

```bash
sh labs/wget/make_downloads.sh
```

If host `wget` is not installed, the script automatically uses the toolbox
container.

This touches status output, normal downloads, redirects, Basic auth, a large
file, timestamping, and recursive mirroring.

## Practice Tasks

1. Download `report.txt` with its original name.
2. Download `data.csv` into `labs/wget/downloads`.
3. Save `/api/status` to a custom filename.
4. Fetch the authenticated endpoint.
5. Download `big.bin`, remove the last part, then resume with `-c`.
6. Run timestamping twice and observe the second request.
7. Mirror `/mirror/` with `--level=1`.
8. Compare recursive mirroring with and without `robots=off`.

## Troubleshooting

If Compose reports that port `18081` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18081:8080` to `127.0.0.1:28081:8080`.

If your host does not have `wget`, use the toolbox commands or run
`sh labs/wget/make_downloads.sh`.
