#!/usr/bin/env bash
# Install the shared lab key and the lab's SSH aliases for stcli and ssh; safe
# to re-run. scripts/cleanup-ssh.sh undoes it.
set -euo pipefail

key="$HOME/.ssh/ac6-workshop-key"
staged="$HOME/.ssh/ac6-workshop-ssh-config.conf"
config="$HOME/.ssh/config"
line="Include ${staged}"

mkdir -p "$HOME/.ssh"

# lab/ssh_config points stcli's IdentityFile here — a fixed, home-relative
# path so it resolves the same regardless of where this repo is cloned. Not a
# secret: the matching public key is baked into every node, and only ever
# used against these loopback-only lab containers.
cp lab/ac6-workshop-key "$key"
chmod 600 "$key"

# Include a private copy in ~/.ssh/, not the repo file directly: OpenSSH
# refuses to read an Include'd file that's writable by anyone but its owner,
# and a Codespace's /workspaces mount makes the whole checkout world-writable
# (-rw-rw-rw-) regardless of what's committed — confirmed live ("Bad owner or
# permissions on .../lab/ssh_config"). The copy is refreshed on every run, so
# a lab/ssh_config change needs a re-run to take effect.
cp lab/ssh_config "$staged"
chmod 600 "$staged"

touch "$config"
chmod 600 "$config"

if grep -qF "$line" "$config"; then
    echo "~/.ssh/config already includes ${staged} (just refreshed its contents)"
    exit 0
fi

# Prepend the Include at the very top, before any Host block: OpenSSH
# silently treats an Include as "parse only" (read, never applied) if any
# Host block precedes it anywhere earlier in the file — confirmed debugging
# this lab against a Codespace. An append would eventually land after some
# Host block added later and quietly stop working with no error.
cp "$config" "${config}.bak"
{ echo "$line"; echo; cat "$config"; } > "${config}.new"
mv "${config}.new" "$config"
echo "Added to the top of ~/.ssh/config: ${line}"
echo "(previous version backed up to ${config}.bak)"
