#!/usr/bin/env bash
# Run locally on macOS, WSL, or desktop Linux; print a token for Codespaces.
set -euo pipefail
set +x

cli="${1:-stcli}"
for dependency in jq; do
    command -v "$dependency" >/dev/null 2>&1 || {
        echo "Missing required command: $dependency" >&2
        exit 1
    }
done
command -v "$cli" >/dev/null 2>&1 || {
    echo "stcli not found. Pass its path: $0 ./stcli-local" >&2
    exit 1
}

# A bearer override must not affect this browser-login flow.
env -u STCLI_TOKEN "$cli" login

config_dir="${XDG_CONFIG_HOME:-}"
case "$config_dir" in
    /*) ;;
    *) config_dir="$HOME/.config" ;;
esac
credentials="$config_dir/stcli/credentials.json"
token="$(jq -er '.access_token | select(type == "string" and length > 0)' "$credentials")" || {
    echo "Login did not save a usable access token in $credentials" >&2
    exit 1
}
echo "Access token (copy the entire line below):"
printf '%s\n' "$token"
unset token
echo
echo "In the Codespace, run this command first, then copy the token above:"
echo "  read -rsp 'Paste access token: ' STCLI_TOKEN; echo; export STCLI_TOKEN"
echo "Then paste and press Enter, and run: stcli nokia"
echo "If the token expires, run this helper again."
