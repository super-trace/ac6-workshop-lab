# Repository Guidelines

## Project Structure & Module Organization

Two-node AC6 workshop lab: `arista` (cEOS, fully configured) and `nokia` (SR Linux, blank), joined by an eBGP link (`Ethernet1`↔`e1-1`) and an 802.1Q trunk (`Ethernet2`↔`e1-2`) that the workshop configures on nokia.

- `lab/topology.clab.yml`: the containerlab topology; device startup files live in `lab/configs/`.
- `lab/inventory/`: a Nornir inventory of the lab devices. `stcli` doesn't read it; it connects through the `lab/ssh_config` aliases.
- `lab/images/ceos-shim/`: an `iptables-restore` wrapper bind-mounted into arista; without it, cEOS SSH never answers on Docker Desktop (see the script).
- `scripts/`: verification, exercise checks, and setup helpers; `justfile` wraps them.
- `lab/netbox/`: NetBox and NetBox Labs' MCP server (Compose file and settings). `lab-up` starts both; its network is pinned to `172.20.24.0/24` so it can't overlap containerlab's `172.20.23.0/24`.
- `.devcontainer/`: Codespaces configuration.

## Build, Test, and Development Commands

Run commands from the repository root, with Docker and `just` installed:

- `just --list`: list recipes.
- `just lab-setup`: fetch images and install lab SSH configuration.
- `just lab-up`: deploy the topology and start NetBox (port 8000) and its MCP server (port 8001, `/mcp`). It redeploys every node from `lab/configs/` (`--reconfigure`), so nothing saved inside a node survives a redeploy; NetBox's data does.
- `just lab-status`: inspect running nodes.
- `just lab-verify`: check the baseline: arista configured, nokia blank, both links up, SSH to both, NetBox's API and an MCP tool call through to NetBox.
- `just lab-cli <node>`: open a device's native CLI.
- `just check-bgp` / `just check-l2`: confirm the BGP and layer 2 exercises succeeded.
- `just reset-nokia`: return nokia to blank in seconds (a saved checkpoint) without redeploying arista.
- `just check-netbox` / `just reset-netbox`: confirm NetBox matches arista where the seed left it stale / put NetBox back as seeded, drift included.
- `just netbox-up` / `just netbox-down`: start NetBox and the MCP server without the lab / stop both and delete NetBox's data.
- `just lab-down`: tear down the lab, NetBox and the MCP server, keeping NetBox's database. The workshop is one-way: attendees aren't told to run it; it's a reset for anyone stuck (`lab-down`, then `lab-up`).

NetBox's own first-start migrations take ~6 minutes in a Codespace, so Postgres instead loads `lab/netbox/initdb/netbox.sql.gz`, an already-migrated database, on an empty volume; NetBox then starts in seconds. After changing the NetBox image in `lab/netbox/compose.yml`, regenerate the dump with `scripts/netbox-snapshot.sh` (it deletes NetBox's data).

`scripts/netbox-seed.sh` (run by `netbox-up.sh`) seeds NetBox once, curl only, with arista as documented plus the Scenario 3 drift; the `workshop-seed` tag, created last, marks a finished seed. Keep the seed, `scripts/check-netbox.sh` and the README's Scenario 3 facilitator table in step.

## Coding Style & Naming Conventions

Match adjacent files: two-space YAML indentation, four-space Python indentation, and existing Bash/just recipe formatting. Bash scripts use `#!/usr/bin/env bash`, `set -euo pipefail`, and quoted variable expansions. Use descriptive kebab-case script names such as `check-bgp.sh`. No shared formatter is configured.

- Quote any `exec:` command in `topology.clab.yml` that contains `: `; unquoted, YAML reads it as a map and containerlab rejects the whole file.
- Write comments inside a non-shebang recipe as `@#`; `just` echoes plain `#` lines when the recipe runs.

## Testing Guidelines

Testing uses live lab checks rather than a unit-test framework; no coverage threshold is configured. Run `just lab-verify` before and after changes. For exercise changes, configure nokia the way the exercise intends, confirm `just check-bgp` / `just check-l2` pass, then `just reset-nokia` and confirm they fail again. For the NetBox exercise, `just check-netbox` fails on a fresh seed, passes once NetBox is reconciled, and fails again after `just reset-netbox`. Keep configurations, README instructions, and the README's ASCII diagram consistent.

## Commit & Pull Request Guidelines

Use the observed prefixes `feat:`, `fix:`, `docs:`, or `chore:` with an imperative summary. PR descriptions should explain the behavior changed, list validation commands and results, link relevant issues, and update the README diagram for topology changes.

## Security & Configuration

Keep licensed vendor archives, personal credentials, and login tokens out of commits. The shared SSH key is for disposable labs only. Preserve distinct management networks and documented SSH ports; setup recipes can modify `~/.ssh/`.

## Public launch

`super-trace/stcli-releases` is public: both READMEs install stcli with `curl -fsSL https://cli.supertrace.ai/install.sh | sh`, as cli.supertrace.ai shows, and the Codespace no longer asks for access to it. This repository will become public too; test the Codespace link and installation without a GitHub login when it does. We never host or push the cEOS image (Arista's licence doesn't allow redistribution): `scripts/ceos-pull.sh` downloads it from arista.com with an `ARISTA_TOKEN` and imports it locally as `arista/ceos:4.36.2F`. The prebuild uses the repository's `ARISTA_TOKEN` Codespaces secret; locally, attendees use their own token or `just ceos-import <tar>`.

Every login in the lab is `oldprotocol` / `newbrain`: both devices (plus SR Linux's built-in admin and linuxadmin), and NetBox. Changing NetBox's means editing `lab/netbox/netbox.env` and rerunning `scripts/netbox-snapshot.sh`.
