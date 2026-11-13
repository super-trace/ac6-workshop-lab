#!/usr/bin/env bash
# Add GitHub's read-only MCP server to stcli, authenticated with the
# Codespace's own GITHUB_TOKEN, without printing the token. Bash only: the
# Codespace host has neither jq nor python3, so an existing config.json is
# extended by inserting the "mcp" block after its opening brace, and one that
# already has an "mcp" block is left alone (use /mcp add in stcli instead).
set -euo pipefail

url="https://api.githubcopilot.com/mcp/readonly"
dir="${HOME}/.config/stcli"
cfg="${dir}/config.json"

if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "GITHUB_TOKEN isn't set. In a Codespace it always is; elsewhere, export a GitHub token first." >&2
    exit 1
fi

entry="\"mcp\":{\"github\":{\"url\":\"${url}\",\"headers\":{\"Authorization\":\"Bearer ${GITHUB_TOKEN}\"}}}"

mkdir -p "$dir"
umask 077
if [ ! -s "$cfg" ]; then
    printf '{%s}\n' "$entry" >"$cfg"
elif grep -q '"github"' "$cfg" && grep -q "$url" "$cfg"; then
    echo "GitHub's MCP server is already in ${cfg}."
    exit 0
elif grep -q '"mcp"' "$cfg"; then
    echo "${cfg} already lists MCP servers; add this one from stcli instead:" >&2
    echo "  /mcp add github ${url} --header Authorization" >&2
    exit 1
else
    # Insert after the first "{"; a trailing comma only when the object
    # already has members.
    if grep -qE '^[[:space:]]*\{[[:space:]]*\}[[:space:]]*$' "$cfg"; then
        printf '{%s}\n' "$entry" >"$cfg"
    else
        tmp="$(mktemp "${dir}/config.XXXXXX")"
        awk -v e="$entry" 'done || !/\{/ {print; next} {sub(/\{/, "{" e ","); print; done=1}' "$cfg" >"$tmp"
        mv "$tmp" "$cfg"
    fi
fi
chmod 600 "$cfg"
echo "GitHub's MCP server added to ${cfg}. Start stcli (or restart it) and run /mcp list."
