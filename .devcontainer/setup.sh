#!/usr/bin/env bash
set -euo pipefail

# just — not preinstalled on the base devcontainer image.
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
    | bash -s -- --to /usr/local/bin

# Unlike stcli-3node-lab, nothing here is licensed or proprietary — SR Linux
# and FRRouting are both freely pullable, so there's no GitHub Release asset
# to fetch and no account an attendee needs beyond ssh.supertrace.ai itself.
cd "$(dirname "$0")/.."
just lab-setup

echo ""
echo "Setup complete. Run: just lab-up    then: just verify"
echo "SSH ports 2401 (edge1) / 2402 (core1) auto-forward — VS Code Ports tab, or 'gh codespace ports forward'."
