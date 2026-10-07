#!/usr/bin/env bash
# Remove workshop SSH files on the machine where local stcli ran.
set -euo pipefail

config="$HOME/.ssh/config"
include="Include $HOME/.ssh/ac6-workshop-ssh-config.conf"

if [ -f "$config" ] && grep -qxF "$include" "$config"; then
    # Preserve current edits; don't restore the backup from initial setup.
    backup="$(mktemp "${config}.ac6-cleanup-backup.XXXXXX")"
    cp -p "$config" "$backup"
    temporary="$(mktemp "${config}.ac6-cleanup.XXXXXX")"
    trap 'rm -f "$temporary"' EXIT
    awk -v include="$include" '$0 != include' "$config" > "$temporary"
    # Writing through the existing file retains its permissions and symlink.
    cat "$temporary" > "$config"
    echo "Removed workshop Include; previous config saved to $backup"
fi

rm -f "$HOME/.ssh/ac6-workshop-key" \
    "$HOME/.ssh/ac6-workshop-ssh-config.conf" \
    "$HOME/.ac6-workshop-known-hosts"
echo "Workshop SSH files removed. Other SSH configuration retained."
