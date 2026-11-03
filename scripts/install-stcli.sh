#!/usr/bin/env bash
# Install the bundled stcli to /usr/local/bin, inside a Codespace only.
set -euo pipefail

# $CODESPACES is set in every Codespace. On your own machine you likely
# already have a real stcli there, and this committed binary is Linux-only
# (see lab/bin/README.md — a placeholder for a release download). The guard
# is what makes it safe for lab-setup to run this unconditionally.
if [ "${CODESPACES:-}" != "true" ]; then
    echo "not inside a Codespace — not installing the Linux-only stcli binary here"
    echo "(install/build stcli for this machine yourself)"
    exit 0
fi

sudo cp lab/bin/stcli-linux-amd64 /usr/local/bin/stcli
sudo chmod +x /usr/local/bin/stcli
echo "Installed stcli to /usr/local/bin/stcli"
