#!/usr/bin/env bash
# Run locally on macOS, WSL, or desktop Linux; copy a token for Codespaces.
set -euo pipefail
set +x

cli="${1:-stcli}"
for dependency in jq; do
    command -v "$dependency" >/dev/null 2>&1 || {
        echo "Missing required command: $dependency" >&2
        exit 1
    }
done
if command -v pbcopy >/dev/null 2>&1; then
    clipboard=(pbcopy)
elif command -v clip.exe >/dev/null 2>&1; then
    clipboard=(clip.exe)
elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    clipboard=(wl-copy)
elif [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
    clipboard=(xclip -selection clipboard)
else
    echo "No clipboard available. Use pbcopy (macOS), clip.exe (WSL), wl-copy (Wayland), or xclip (X11)." >&2
    exit 1
fi
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
printf '%s' "$token" | "${clipboard[@]}"
unset token
echo "Access token copied to clipboard. In the Codespace, run:"
echo "  read -rsp 'Paste access token: ' STCLI_TOKEN; echo; export STCLI_TOKEN"
echo "Then paste and press Enter, and run: stcli spine-jfk"
echo "If the token expires, run this helper again."
