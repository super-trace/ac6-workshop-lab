# Repository Guidelines

## Project Structure & Module Organization

Two-node AC6 workshop lab: `nokia` (SR Linux, fully configured) and `sonic` (SONiC, blank), joined by an eBGP link (`e1-1`↔`Ethernet0`) and an 802.1Q trunk (`e1-2`↔`Ethernet4`) that the workshop configures on sonic.

- `lab/topology.clab.yml`: the containerlab topology; device startup files live in `lab/configs/`.
- `lab/inventory/`: a Nornir inventory of the lab devices. `stcli` doesn't read it; it connects through the `lab/ssh_config` aliases.
- `lab/images/sonic/`: the lab's SONiC image, SONiC's official `docker-sonic-vs` plus the lab login, sshd, bgpd, SONiC's gNMI server (`sonic-gnmi`, port 50051, no TLS; `docker-sonic-vs` leaves it out) and syslog forwarding to Vector. `scripts/sonic-image.sh` builds it from SONiC's pipeline (`docker-sonic-vs.gz` and the same branch's `sonic-gnmi` .deb). It is not published: `ghcr.io/super-trace/ac6-workshop-lab/sonic-vs` doesn't exist, so `sonic-ensure` builds it in the Codespace prebuild, or locally on the first `lab-up` (`just sonic-image --push` would publish it).
- `lab/grafana/`: Scenario 4's observability stack (Compose project `ac6-grafana`): gnmic (gNMI from both devices → Prometheus, normalised to shared `interface_*` metric names by a Starlark processor in `gnmic.yml`), Prometheus, Loki, Vector (syslog on UDP 1514 → Loki; Grafana Alloy is six times the size), Grafana on port 3000 and `grafana-mcp`, Grafana's MCP server at `http://localhost:8003/mcp` (localhost only). It joins containerlab's `ac6` network as an external network with fixed addresses (`.20`–`.25`; Vector is `172.20.23.20`, which nokia's startup config and the SONiC image send syslog to), so it starts after the deploy.
- `scripts/`: verification, exercise checks, and setup helpers; `justfile` wraps them.
- `lab/netbox/`: NetBox and `github-mcp`, a Caddy proxy that serves GitHub's read-only MCP server at `http://localhost:8002/mcp/readonly` with the `GITHUB_TOKEN` of the shell that ran `lab-up` (Scenario 3's `/mcp add`; localhost only) (Compose file and settings). `lab-up` starts both; its network is pinned to `172.20.24.0/24` so it can't overlap containerlab's `172.20.23.0/24`.
- `.devcontainer/`: Codespaces configuration.

## Build, Test, and Development Commands

Run commands from the repository root, with Docker and `just` installed:

- `just --list`: list recipes.
- `just lab-setup`: fetch images and install lab SSH configuration ahead of time (the Codespace prebuild runs it). `lab-up` does both itself, so attendees never need it.
- `just lab-up`: deploy the topology and start NetBox (port 8000), the GitHub MCP proxy (port 8002, localhost only) and the Grafana stack (port 3000; Grafana MCP on 8003, localhost only; `scripts/grafana-up.sh`, after `lab-ready.sh`). It takes the Grafana stack down before the deploy, since it sits on containerlab's network. It redeploys every node from `lab/configs/` (`--reconfigure`), so nothing saved inside a node survives a redeploy; NetBox's data does. It also reinstalls the SSH aliases from `lab/ssh_config` (so a `git pull` is enough after they change) and makes sure the SONiC image matches the checkout (`sonic-ensure`): the image carries a hash of its recipe (`scripts/sonic-recipe.sh`, label `ac6.recipe`), and a missing or stale one is pulled again or rebuilt with `scripts/sonic-image.sh`.
- `just lab-status`: inspect running nodes.
- `just lab-verify`: check the baseline: nokia configured, sonic blank, both links up, SSH to both, NetBox's API, the GitHub MCP proxy's handshake, Grafana with metrics and logs from both devices, and the Grafana MCP handshake.
- `just lab-cli <node>`: open a device's native CLI.
- `just check-bgp` / `just check-l2`: confirm the BGP and layer 2 exercises succeeded.
- `just check-standards`: confirm Scenario 2's standards audit fixed sonic's descriptions. `lab-ready.sh` seeds two off-standard ones (`Ethernet0`, `Ethernet8`) before saving sonic's baseline, so `reset-sonic` puts them back. Keep the README's "Team standards" block and its copy in Scenario 1's prompt (D.1.9), the seed, `scripts/check-standards.sh` and the Scenario 1–3 audit steps in step.
- `just reset-sonic`: return sonic to blank in seconds without redeploying nokia. `lab-ready.sh` saves sonic's CONFIG_DB and FRR config after boot; `scripts/sonic-reset.py` diffs CONFIG_DB back to it (SONiC's `config replace` rejects the virtual switch's default config, and `config reload` needs systemd), then FRR's files are restored and bgpd restarted.
- `just check-netbox` / `just reset-netbox`: confirm NetBox matches nokia where the seed left it stale / put NetBox back as seeded, drift included.
- `just netbox-up` / `just netbox-down`: start NetBox and the GitHub MCP proxy without the lab / stop both and delete NetBox's data.
- `just check-grafana` / `just reset-grafana`: confirm some dashboard shows Prometheus metrics for both nokia and sonic and Loki logs (every panel query is run, with Grafana's macros and variables filled in) / delete every dashboard. The lab provisions none.
- `just grafana-up` / `just grafana-down`: (re)start the Grafana stack while the lab is up / stop it and delete Grafana's dashboards. `grafana-up.sh` creates the Grafana service account `stcli` (role Editor: dashboards and folders, not datasources) and mints a fresh token for `grafana-mcp` on every run. Metrics and logs aren't kept across a restart; dashboards are (volume `grafana-data`).
- `just lab-down`: tear down the lab, NetBox, the GitHub MCP proxy and the Grafana stack, keeping NetBox's database and Grafana's dashboards. The workshop is one-way: attendees aren't told to run it; it's a reset for anyone stuck (`lab-down`, then `lab-up`).

NetBox's own first-start migrations take ~6 minutes in a Codespace, so Postgres instead loads `lab/netbox/initdb/netbox.sql.gz`, an already-migrated database, on an empty volume; NetBox then starts in seconds. After changing the NetBox image in `lab/netbox/compose.yml`, regenerate the dump with `scripts/netbox-snapshot.sh` (it deletes NetBox's data).

`scripts/netbox-seed.sh` (run by `netbox-up.sh`) seeds NetBox once, curl only, with nokia as documented plus the Scenario 3 drift; the `workshop-seed` tag, created last, marks a finished seed. Keep the seed, `scripts/check-netbox.sh` and the README's Scenario 3 facilitator table in step.

## Coding Style & Naming Conventions

Match adjacent files: two-space YAML indentation, four-space Python indentation, and existing Bash/just recipe formatting. Bash scripts use `#!/usr/bin/env bash`, `set -euo pipefail`, and quoted variable expansions. Use descriptive kebab-case script names such as `check-bgp.sh`. No shared formatter is configured.

- Quote any `exec:` command in `topology.clab.yml` that contains `: `; unquoted, YAML reads it as a map and containerlab rejects the whole file.
- Write comments inside a non-shebang recipe as `@#`; `just` echoes plain `#` lines when the recipe runs.
- Scripts that run on the host use bash, curl and jq: the Codespace's base image (`mcr.microsoft.com/devcontainers/base:ubuntu-24.04`) has `jq` but no `python3`.

## Testing Guidelines

Testing uses live lab checks rather than a unit-test framework; no coverage threshold is configured. Run `just lab-verify` before and after changes. For exercise changes, configure sonic the way the exercise intends, confirm `just check-bgp` / `just check-l2` pass, then `just reset-sonic` and confirm they fail again. For the NetBox exercise, `just check-netbox` fails on a fresh seed, passes once NetBox is reconciled, and fails again after `just reset-netbox`. For the Grafana exercise, `just check-grafana` fails with no dashboards, passes once one shows both devices' metrics and their logs, and fails again after `just reset-grafana`. Keep configurations, README instructions, and the README's ASCII diagram consistent. Once attendees start `stcli` (C.3) they stay in it: workshop steps never send them to another terminal for `just` recipes; the `check-*` and `reset-*` recipes are for facilitators and the README's Start over section. Keep `lab/ssh_config` to keywords stcli supports: stcli rejects ones it doesn't implement (it rejected `IdentitiesOnly`), which `lab-verify`'s OpenSSH checks don't catch.

## Commit & Pull Request Guidelines

Use the observed prefixes `feat:`, `fix:`, `docs:`, or `chore:` with an imperative summary. PR descriptions should explain the behavior changed, list validation commands and results, link relevant issues, and update the README diagram for topology changes.

## Security & Configuration

Keep licensed vendor archives, personal credentials, and login tokens out of commits. The shared SSH key is for disposable labs only. Preserve distinct management networks and documented SSH ports; setup recipes can modify `~/.ssh/`.

## Public launch

`super-trace/stcli-releases` is public: both READMEs install stcli with `curl -fsSL https://cli.supertrace.ai/install.sh | sh`, as cli.supertrace.ai shows, and the Codespace no longer asks for access to it. This repository will become public too; test the Codespace link and installation without a GitHub login when it does. Every image the lab pulls is public and redistributable: SR Linux from Nokia's ghcr, NetBox and its dependencies from Docker Hub, gnmic from ghcr (Apache-2.0), Prometheus, Loki, Grafana and `grafana/mcp-grafana` from Docker Hub (Apache-2.0/AGPL-3.0), and Vector from Docker Hub (MPL-2.0). SONiC (Apache-2.0) is built from SONiC's public pipeline. Don't add a vendor image whose licence forbids redistribution (Arista cEOS was dropped for that reason).

Every login in the lab is `oldprotocol` / `newbrain`: both devices (plus SR Linux's built-in admin and linuxadmin, and SONiC's root), NetBox and Grafana. gnmic reads nokia's gNMI with it too. Changing NetBox's means editing `lab/netbox/netbox.env` and rerunning `scripts/netbox-snapshot.sh`.
