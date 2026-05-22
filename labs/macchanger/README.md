# Macchanger Guide And Local Interface Lab

This lab teaches `macchanger` option review, MAC address inspection, setting a
specific lab MAC, randomization, and cleanup using only a disposable interface
inside a Docker container. It does not modify the host network card or your
real LAN identity.

`macchanger` can change a network interface MAC address. On real networks that
can affect access controls, logs, NAC policies, DHCP leases, and accountability.
This lab keeps practice inside a container network namespace and changes only a
temporary veth interface named `lab0`.

## Safety Rules

- Use Macchanger only on interfaces and networks you own or have explicit permission to test.
- Do not use MAC changes to bypass access controls, evade monitoring, or impersonate another device.
- Keep practice on disposable lab interfaces before touching real adapters.
- Record original MAC addresses before making changes in an authorized environment.
- Restore interfaces and remove temporary lab devices when finished.
- Treat MAC addresses, interface names, and network-access notes as sensitive assessment data.

## Lab Topology

The Compose file starts one Kali container with `NET_ADMIN`. The helper creates
a temporary veth pair inside that container, changes `lab0`, validates the
result, and deletes the veth pair.

| Container | Purpose |
| --- | --- |
| `scanner` | Runs `macchanger`, `ip`, `jq`, and stores output. |

Temporary lab interfaces:

| Interface | Purpose |
| --- | --- |
| `lab0` | Disposable interface used for Macchanger practice. |
| `labpeer` | Peer side of the local veth pair. |

Mounted lab directories:

| Directory | Purpose |
| --- | --- |
| `outputs` | Generated command output, observed MACs, validation files, and summaries. |

## Start The Lab

Run from the repository root:

```bash
docker compose -f labs/macchanger/docker-compose.yml up --build -d
docker compose -f labs/macchanger/docker-compose.yml ps
docker compose -f labs/macchanger/docker-compose.yml exec scanner macchanger --version
```

Clean up when finished:

```bash
docker compose -f labs/macchanger/docker-compose.yml down
```

## Basic Usage

Show Macchanger options:

```bash
docker compose -f labs/macchanger/docker-compose.yml exec scanner macchanger --help
```

Create a disposable lab interface:

```bash
docker compose -f labs/macchanger/docker-compose.yml exec scanner \
  ip link add lab0 type veth peer name labpeer
```

Show the current MAC:

```bash
docker compose -f labs/macchanger/docker-compose.yml exec scanner macchanger -s lab0
```

Set a predictable lab MAC:

```bash
docker compose -f labs/macchanger/docker-compose.yml exec scanner \
  sh -c 'ip link set lab0 down && macchanger -m 02:42:ac:10:00:55 lab0'
```

Randomize the disposable lab MAC:

```bash
docker compose -f labs/macchanger/docker-compose.yml exec scanner \
  sh -c 'ip link set lab0 down && macchanger -r lab0'
```

Remove the temporary interface:

```bash
docker compose -f labs/macchanger/docker-compose.yml exec scanner ip link del lab0
```

## Useful Options

| Option | Use |
| --- | --- |
| `-s`, `--show` | Show the current and permanent MAC address. |
| `-m MAC`, `--mac MAC` | Set a specific MAC address. |
| `-r`, `--random` | Set a fully random MAC address. |
| `-e`, `--ending` | Keep the vendor bytes and randomize the device bytes. |
| `-a`, `--another` | Set a random vendor MAC of the same kind. |
| `-p`, `--permanent` | Reset to the permanent hardware MAC when the driver supports it. |
| `-l`, `--list` | List known vendors. |
| `-b`, `--bia` | Pretend to be a burned-in address. |

## Generate Practice Outputs

Run a quick Macchanger workflow:

```bash
docker compose -f labs/macchanger/docker-compose.yml up --build -d
sh labs/macchanger/make_scans.sh
```

This writes help/version output, interface snapshots, original/specific/random
MAC observations, a safe command plan, validation results, and a TSV summary
into `labs/macchanger/outputs`.

The helper validates that `eth0` is unchanged and that the temporary `lab0`
interface is removed after the run.

## Practice Tasks

1. Run `macchanger --help` and identify show, specific, random, and reset options.
2. Inspect `outputs/observed-macs.tsv` and compare original, specific, and random MACs.
3. Confirm `outputs/validation.tsv` shows `eth0_unchanged` as `yes`.
4. Review `outputs/safe-command-plan.tsv`.
5. Rerun the helper and compare the new random MAC.
6. Explain why a disposable veth interface is safer than changing `eth0`.
7. Write a rollback plan for an authorized real-interface test.

## Real Interface Note

Changing a real interface may interrupt connectivity or violate network policy.
For authorized physical adapters, record the current value first, bring the
interface down, apply the change, bring the interface up, test connectivity,
and restore the original MAC when the exercise ends.

## Troubleshooting

If creating `lab0` fails, confirm the scanner container has `NET_ADMIN`:

```bash
docker compose -f labs/macchanger/docker-compose.yml config | grep -A4 cap_add
```

If Macchanger says an interface is busy, bring the disposable interface down:

```bash
docker compose -f labs/macchanger/docker-compose.yml exec scanner ip link set lab0 down
```

If Compose reports a stale scanner, restart the lab:

```bash
docker compose -f labs/macchanger/docker-compose.yml down
docker compose -f labs/macchanger/docker-compose.yml up --build -d
```
