#!/usr/bin/env bash
# Runs as onCreateCommand, before setup.sh (postCreateCommand) and before the
# first terminal opens. Codespaces shows setup.sh's output only in the
# creation log, so this makes every new interactive shell run
# setup-progress.sh, which streams that output while setup is still going.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
progress="${repo}/.devcontainer/setup-progress.sh"

# A terminal can open before setup.sh starts; "pending" tells it to wait.
rm -f /tmp/ac6-workshop-setup.log
echo pending > /tmp/ac6-workshop-setup.state

hook="[ -x \"${progress}\" ] && \"${progress}\""
if ! grep -qF "$hook" ~/.bashrc 2>/dev/null; then
    printf '\n# AC6 workshop: show Codespace setup progress in new terminals.\n%s\n' "$hook" >> ~/.bashrc
fi

# The stcli installer (README step 3) puts stcli in ~/.local/bin. Ubuntu
# adds that to PATH only in login shells, and only if it already existed, so
# a fresh install wouldn't be found in VS Code's terminals without this.
path_line='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qF "$path_line" ~/.bashrc 2>/dev/null; then
    printf '\n# AC6 workshop: stcli installs to ~/.local/bin.\n%s\n' "$path_line" >> ~/.bashrc
fi
