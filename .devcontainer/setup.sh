#!/usr/bin/env bash
set -euo pipefail

# just — not preinstalled on the base devcontainer image. postCreateCommand
# runs as the non-root default user (vscode), which can't write to
# /usr/local/bin directly — sudo (passwordless for this user, standard on
# devcontainer base images) is required here.
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
    | sudo bash -s -- --to /usr/local/bin

# sshpass — scripts/verify.sh's manual SSH check needs it (not stcli itself,
# which offers both pubkey and password auth and lets the server pick). The
# README's local setup gets this from Homebrew; the devcontainer needs its
# own install.
sudo apt-get update -qq && sudo apt-get install -y -qq sshpass

# Unlike stcli-3node-lab, nothing here is licensed or proprietary — SR Linux
# and FRRouting are both freely pullable, so there's no GitHub Release asset
# to fetch and no account an attendee needs beyond ssh.supertrace.ai itself.
cd "$(dirname "$0")/.."
just lab-setup

echo ""
echo "Setup complete. Run: just lab-up    then: just verify"
echo "SSH ports 2401-2408 (spine-jfk, leaf-jfk, client-jfk, spine-iad, leaf-iad,"
echo "client-iad, rtr-phl, rtr-ewr) auto-forward — VS Code Ports tab, or"
echo "'gh codespace ports forward'."
