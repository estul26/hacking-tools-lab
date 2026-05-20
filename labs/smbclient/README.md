# Smbclient Guide And Local Samba Lab

This lab teaches `smbclient` against a deliberately small local Samba target.
You can practice share listing, authenticated access, directory browsing, file
download, upload, delete, SMB protocol selection, and failed-login review
without touching a real file server.

SMB file shares often contain sensitive business and identity data. This lab
keeps the target on a private Docker network and uses toy files and toy
credentials.

## Safety Rules

- Use `smbclient` only on systems you own or have explicit permission to assess.
- Keep hosts, shares, credentials, file operations, and transfer volume inside scope.
- Do not browse, copy, upload, or delete files on production shares without written authorization.
- Treat share listings and downloaded files as sensitive unless your authorization says otherwise.
- Use read-only checks first; be cautious with `put`, `del`, `rename`, and recursive transfers.
- Keep this lab on the private Docker network unless your authorization covers another target.

## Lab Topology

The Compose file creates a private Docker bridge network. No SMB port is
published to the host or LAN.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.64.86.10` | Runs `smbclient`, `nc`, `jq`, and stores output. |
| `target` | `172.64.86.20` | Runs Samba with toy shares and toy files. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated command output, downloads, validation, and summaries. |
| `upload` | Local toy upload file mounted read-only into the scanner. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/smbclient/docker-compose.yml up --build -d
docker compose -f labs/smbclient/docker-compose.yml ps
docker compose -f labs/smbclient/docker-compose.yml exec scanner smbclient --version
```

Clean up when finished:

```bash
docker compose -f labs/smbclient/docker-compose.yml down
```

## Local Credentials

The target intentionally accepts one local lab credential:

```text
labuser:labpass!
```

Use only these toy credentials in this lab.

## Basic Usage

List shares:

```bash
docker compose -f labs/smbclient/docker-compose.yml exec scanner \
  smbclient -L //172.64.86.20 -U 'labuser%labpass!' -m SMB3
```

List files in `labshare`:

```bash
docker compose -f labs/smbclient/docker-compose.yml exec scanner \
  smbclient //172.64.86.20/labshare -U 'labuser%labpass!' -m SMB3 -c 'ls'
```

List files in a subdirectory:

```bash
docker compose -f labs/smbclient/docker-compose.yml exec scanner \
  smbclient //172.64.86.20/labshare -U 'labuser%labpass!' -m SMB3 -c 'cd docs; ls'
```

Download a toy file:

```bash
docker compose -f labs/smbclient/docker-compose.yml exec scanner \
  smbclient //172.64.86.20/labshare -U 'labuser%labpass!' -m SMB3 \
  -c 'get docs/notes.txt /work/outputs/notes-downloaded.txt'
```

Upload and delete a toy file in `dropbox`:

```bash
docker compose -f labs/smbclient/docker-compose.yml exec scanner \
  smbclient //172.64.86.20/dropbox -U 'labuser%labpass!' -m SMB3 \
  -c 'put /work/upload/lab-upload.txt lab-upload.txt; ls; del lab-upload.txt'
```

## Useful Options

| Option | Use |
| --- | --- |
| `-L //HOST` | List shares on a host. |
| `//HOST/SHARE` | Connect to a specific share. |
| `-U USER%PASS` | Provide a username and password. |
| `-m SMB3` | Set the maximum SMB protocol version. |
| `-c 'COMMANDS'` | Run commands non-interactively. |
| `ls` | List files in the current share directory. |
| `cd DIR` | Change directories in the share. |
| `get REMOTE LOCAL` | Download a file. |
| `put LOCAL REMOTE` | Upload a file. |
| `del FILE` | Delete a file. Use carefully. |

## Generate Practice Outputs

Run a quick smbclient workflow:

```bash
sh labs/smbclient/make_scans.sh
```

This writes help/version output, share listings, directory listings, download
logs, upload/delete output, failed-auth output, validation results, and a TSV
summary into `labs/smbclient/outputs`.

## Practice Tasks

1. List shares and identify `labshare` and `dropbox`.
2. Browse `labshare` and then `docs`.
3. Download `docs/notes.txt` and inspect the local copy.
4. Upload `upload/lab-upload.txt` to `dropbox`, then delete it.
5. Try a bad password and inspect the failure message.
6. Compare interactive `smbclient` use with `-c` scripted commands.
7. Write a safe `smbclient` command for a share you are authorized to access.

## Troubleshooting

If `smbclient` cannot connect, confirm SMB is reachable from the scanner:

```bash
docker compose -f labs/smbclient/docker-compose.yml exec scanner nc -z 172.64.86.20 445
```

If authentication fails, confirm the lab credential uses shell-safe quoting:

```bash
smbclient -L //172.64.86.20 -U 'labuser%labpass!' -m SMB3
```

If a file operation fails, rerun the helper to reset the expected workflow and
inspect `outputs/upload-delete.txt` or `outputs/download.log`.
