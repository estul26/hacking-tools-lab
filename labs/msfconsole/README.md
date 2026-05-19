# MSFConsole Guide And Local Auxiliary Scanner Lab

This lab teaches `msfconsole` with a real local HTTP target and safe auxiliary
scanner modules. You can practice resource scripts, module search, module
options, `run`, `spool`, and output review without touching any live system.

Metasploit is powerful and includes exploit and payload workflows. This lab
intentionally uses auxiliary HTTP scanner modules only. Keep experimentation
inside the Docker network unless you have explicit authorization for another
target.

## Safety Rules

- Use Metasploit only against systems you own or have explicit permission to assess.
- Keep `RHOSTS`, ports, payloads, credentials, and resource scripts inside scope.
- Prefer auxiliary scanner modules while learning basic console workflow.
- Do not run exploit modules or payload handlers against real systems without written authorization.
- Review resource scripts before running them.
- Keep generated output local and delete it when no longer needed.

## Lab Topology

The Compose file creates a Docker lab network and publishes the target to
localhost only.

| Container | IP | Purpose |
| --- | --- | --- |
| `scanner` | `172.59.81.10` | Runs `msfconsole`, `curl`, `jq`, and stores output. |
| `target` | `172.59.81.20` | Local HTTP app with headers, robots.txt, status, login, and basic auth. |

Host-reachable endpoint:

| Host endpoint | Container service | Purpose |
| --- | --- | --- |
| `127.0.0.1:18105` | `target:8080` | Local HTTP target. |

The port is bound to `127.0.0.1`, not `0.0.0.0`, so it stays on your machine
and is not exposed to your LAN.

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/msfconsole/docker-compose.yml up --build -d
docker compose -f labs/msfconsole/docker-compose.yml ps
docker compose -f labs/msfconsole/docker-compose.yml exec scanner msfconsole --version
```

Open the target:

```bash
open http://127.0.0.1:18105/
```

Clean up when finished:

```bash
docker compose -f labs/msfconsole/docker-compose.yml down
```

## Open MSFConsole

Start an interactive console in the scanner:

```bash
docker compose -f labs/msfconsole/docker-compose.yml exec scanner msfconsole
```

Inside the console, search for HTTP scanner modules:

```text
search type:auxiliary scanner/http/http_version
search type:auxiliary scanner/http/robots_txt
```

Exit with:

```text
exit -y
```

## Run HTTP Version Scanner

Use the auxiliary HTTP version scanner:

```text
use auxiliary/scanner/http/http_version
set RHOSTS 172.59.81.20
set RPORT 8080
set THREADS 1
run
```

The local target advertises an Apache-like server banner for repeatable
practice.

## Run Robots Scanner

Use the robots.txt scanner:

```text
use auxiliary/scanner/http/robots_txt
set RHOSTS 172.59.81.20
set RPORT 8080
run
```

The target returns local-only disallowed paths such as `/admin/` and
`/server-status`.

## Resource Scripts

This lab includes resource scripts in `resources`:

| File | Purpose |
| --- | --- |
| `resources/http_version.rc` | Runs `auxiliary/scanner/http/http_version` against the local target. |
| `resources/robots_txt.rc` | Runs `auxiliary/scanner/http/robots_txt` against the local target. |

Run one resource script non-interactively:

```bash
docker compose -f labs/msfconsole/docker-compose.yml exec scanner \
  msfconsole -q -r resources/http_version.rc
```

## Useful Console Commands

| Command | Use |
| --- | --- |
| `search QUERY` | Find modules. |
| `use MODULE` | Select a module. |
| `info` | Show module details. |
| `show options` | Show required and optional settings. |
| `set NAME VALUE` | Set an option. |
| `run` | Run the selected auxiliary module. |
| `spool FILE` | Save console output to a file. |
| `back` | Leave the current module. |
| `exit -y` | Exit without confirmation. |

## Generate Practice Outputs

Run a quick MSFConsole workflow:

```bash
sh labs/msfconsole/make_scans.sh
```

This writes version output, module search output, resource-script output,
spooled console output, validation results, and a TSV summary into
`labs/msfconsole/outputs`.

## Practice Tasks

1. Open `msfconsole` and search for HTTP auxiliary modules.
2. Run `show options` for `auxiliary/scanner/http/http_version`.
3. Run the HTTP version scanner against `172.59.81.20:8080`.
4. Run the robots scanner and identify the disallowed local paths.
5. Review both resource scripts before executing them.
6. Use `spool outputs/manual-session.txt` during an interactive session.
7. Write a safe resource script for a target you are authorized to assess.

## Troubleshooting

If the scanner cannot connect, confirm the target is healthy:

```bash
docker compose -f labs/msfconsole/docker-compose.yml exec scanner \
  curl -sS http://172.59.81.20:8080/health | jq .
```

If `msfconsole` starts slowly, wait for Ruby framework initialization to finish.

If Compose reports that port `18105` is already allocated, change the host side
of the mapping in `docker-compose.yml`, for example from
`127.0.0.1:18105:8080` to `127.0.0.1:28105:8080`.
