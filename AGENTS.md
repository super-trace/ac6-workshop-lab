# Repository Guidelines

## Project Structure & Module Organization

Eight-node AC6 troubleshooting lab using Nokia SR Linux, Arista cEOS, and Linux clients.

- `lab/topology.clab.yml`: the containerlab topology; device startup files live in `lab/configs/`.
- `lab/inventory/`: the Nornir inventory for `stcli -i`.
- `lab/images/`: container build assets; diagrams live under `lab/` and `lab/diagrams/`.
- `scripts/`: break/fix scenarios, verification, and setup helpers; `justfile` wraps them.
- `.devcontainer/`: Codespaces configuration.

## Build, Test, and Development Commands

Run commands from the repository root, with Docker and `just` installed:

- `just --list`: list recipes.
- `just lab-setup`: fetch images, build the SSH-enabled client image, and install lab SSH configuration.
- `just lab-up`: deploy the topology. It redeploys every node from `lab/configs/` (`--reconfigure`), so nothing saved inside a node survives a redeploy.
- `just lab-status`: inspect running nodes.
- `just verify`: check routing, connectivity, and SSH access.
- `just lab-cli <node>`: open a device's native CLI.
- `just break <scenario>` / `just fix <scenario>`: `bgp`, `mtu`, `ospf`, `wan`, or `path`.
- `just lab-diagram`: regenerate the topology diagrams.
- `just lab-down`: tear down the lab.

## Coding Style & Naming Conventions

Match adjacent files: two-space YAML indentation, four-space Python indentation, and existing Bash/just recipe formatting. Bash scripts use `#!/usr/bin/env bash`, `set -euo pipefail`, and quoted variable expansions. Use descriptive kebab-case script names such as `break-ospf.sh`; pair fault scripts with corresponding fixes. No shared formatter is configured.

- Quote any `exec:` command in `topology.clab.yml` that contains `: `; unquoted, YAML reads it as a map and containerlab rejects the whole file.
- Write comments inside a non-shebang recipe as `@#`; `just` echoes plain `#` lines when the recipe runs.

## Testing Guidelines

Testing uses live lab checks rather than a unit-test framework; no coverage threshold is configured. Run `just verify` before and after changes. `just verify` fails on any unhealthy protocol state, a missing WAN path, MTU loss, or a broken SSH alias, so it catches every `break` scenario. For scenario changes, demonstrate the fault, apply its fix, and verify recovery. Keep configurations, README instructions, and diagrams consistent.

## Commit & Pull Request Guidelines

Use the observed prefixes `feat:`, `fix:`, `docs:`, or `chore:` with an imperative summary. PR descriptions should explain the behavior changed, list validation commands and results, link relevant issues, and update diagrams for topology changes.

## Security & Configuration

Keep licensed vendor archives, personal credentials, and login tokens out of commits. The shared SSH key is for disposable labs only. Preserve distinct management networks and documented SSH ports; setup recipes can modify `~/.ssh/`.
