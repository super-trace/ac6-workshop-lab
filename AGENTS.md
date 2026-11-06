# Repository Guidelines

## Project Structure & Module Organization

Two-node AC6 workshop lab: `nokia` (SR Linux, fully configured) and `arista` (cEOS, blank), joined by an eBGP link (`e1-1`↔`Ethernet1`) and an 802.1Q trunk (`e1-2`↔`Ethernet2`) that the workshop configures on arista.

- `lab/topology.clab.yml`: the containerlab topology; device startup files live in `lab/configs/`.
- `lab/inventory/`: a Nornir inventory of the lab devices. `stcli` doesn't read it; it connects through the `lab/ssh_config` aliases.
- `lab/images/ceos-shim/`: an `iptables-restore` wrapper bind-mounted into arista; without it, cEOS SSH never answers on Docker Desktop (see the script).
- `scripts/`: verification, exercise checks, and setup helpers; `justfile` wraps them.
- `lab/netbox/`: an on-demand, empty NetBox (Compose file and settings).
- `.devcontainer/`: Codespaces configuration.

## Build, Test, and Development Commands

Run commands from the repository root, with Docker and `just` installed:

- `just --list`: list recipes.
- `just lab-setup`: fetch images and install lab SSH configuration.
- `just lab-up`: deploy the topology. It redeploys every node from `lab/configs/` (`--reconfigure`), so nothing saved inside a node survives a redeploy.
- `just lab-status`: inspect running nodes.
- `just verify`: check the baseline: nokia configured, arista blank, both links up, SSH to both.
- `just lab-cli <node>`: open a device's native CLI.
- `just check-bgp` / `just check-l2`: confirm the BGP and layer 2 exercises succeeded.
- `just reset-arista`: return arista to blank in seconds without redeploying nokia.
- `just netbox-up` / `just netbox-down`: start NetBox on port 8000 / stop it and delete its data.
- `just lab-diagram`: regenerate the topology diagrams.
- `just lab-down`: tear down the lab.

## Coding Style & Naming Conventions

Match adjacent files: two-space YAML indentation, four-space Python indentation, and existing Bash/just recipe formatting. Bash scripts use `#!/usr/bin/env bash`, `set -euo pipefail`, and quoted variable expansions. Use descriptive kebab-case script names such as `check-bgp.sh`. No shared formatter is configured.

- Quote any `exec:` command in `topology.clab.yml` that contains `: `; unquoted, YAML reads it as a map and containerlab rejects the whole file.
- Write comments inside a non-shebang recipe as `@#`; `just` echoes plain `#` lines when the recipe runs.

## Testing Guidelines

Testing uses live lab checks rather than a unit-test framework; no coverage threshold is configured. Run `just verify` before and after changes. For exercise changes, configure arista the way the exercise intends, confirm `just check-bgp` / `just check-l2` pass, then `just reset-arista` and confirm they fail again. Keep configurations, README instructions, and diagrams consistent.

## Commit & Pull Request Guidelines

Use the observed prefixes `feat:`, `fix:`, `docs:`, or `chore:` with an imperative summary. PR descriptions should explain the behavior changed, list validation commands and results, link relevant issues, and update diagrams for topology changes.

## Security & Configuration

Keep licensed vendor archives, personal credentials, and login tokens out of commits. The shared SSH key is for disposable labs only. Preserve distinct management networks and documented SSH ports; setup recipes can modify `~/.ssh/`.

## Public launch

This repository and `super-trace/stcli-releases` will both become public. At launch, update both READMEs, remove the private-access workarounds (README step 2's `gh api` install, the local guide's authenticated installer download, and the Codespace's `stcli-releases` permission request), and test installation without a GitHub login.
