#!/usr/bin/env bash
# Start the workshop's NetBox and its MCP server (lab/netbox/compose.yml),
# NetBox empty apart from its admin user, and print how to reach both. In a
# Codespace, also make port 8000 (NetBox) public so anyone with the URL can
# open it; port 8001 (MCP) stays private. Safe to re-run.
#
# --background starts the containers and returns at once, so `just lab-up`
# can boot NetBox while containerlab deploys; a later run without it waits
# for both to be healthy and prints the banner.
set -euo pipefail

background=""
if [ "${1:-}" = "--background" ]; then
    background=yes
fi

cd "$(dirname "$0")/../lab/netbox"

green=$'\033[1;32m'
yellow=$'\033[1;33m'
bold=$'\033[1m'
reset=$'\033[0m'

if [ "${CODESPACES:-}" = "true" ]; then
    url="https://${CODESPACE_NAME}-8000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
    url="http://localhost:8000"
fi
# NetBox rejects a login form posted from an origin it doesn't trust.
export NETBOX_ORIGIN="$url"

# The background start's PID and output, so the foreground run can wait for
# it (two overlapping `compose up`s can race to create the same container).
# The log is only for debugging; the foreground run reports any failure.
pid_file="${TMPDIR:-/tmp}/ac6-netbox-up.pid"
log_file="${TMPDIR:-/tmp}/ac6-netbox-up.log"

if [ -n "$background" ]; then
    docker compose up -d --quiet-pull >"$log_file" 2>&1 &
    echo $! >"$pid_file"
    disown
    echo "NetBox: starting in the background."
    exit 0
fi

if [ -f "$pid_file" ]; then
    pid="$(cat "$pid_file")"
    while kill -0 "$pid" 2>/dev/null; do sleep 1; done
    rm -f "$pid_file"
fi

# --wait returns once NetBox and the MCP server answer their health checks;
# the first start also creates the database, so it takes longer than later
# ones.
docker compose up -d --wait --wait-timeout 600

public=""
if [ "${CODESPACES:-}" = "true" ]; then
    if gh codespace ports visibility 8000:public -c "$CODESPACE_NAME" >/dev/null 2>&1; then
        public=yes
    fi
fi

printf '\n'
../../scripts/banner.sh green "NETBOX IS UP"
printf '\n'
printf '    %sURL%s       %s\n' "$bold" "$reset" "$url"
printf '    %sLogin%s     admin / ac6-workshop\n' "$bold" "$reset"
printf '    %sAPI token%s Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000\n' "$bold" "$reset"
printf '    %sMCP%s       http://localhost:8001/mcp (streamable HTTP, read-only, no auth)\n' "$bold" "$reset"
printf '\n    NetBox is empty: no sites, device types or devices yet.\n'
if [ "${CODESPACES:-}" = "true" ]; then
    if [ -n "$public" ]; then
        printf '\n    %sPort 8000 is public: anyone with the URL can open NetBox.%s\n' "$green" "$reset"
    else
        printf '\n    %sTo let others open it:%s Ports tab, right-click port 8000 (NetBox),\n' "$yellow" "$reset"
        printf '    Port Visibility, Public.\n'
    fi
fi
printf '\n    Stop it with: %sjust netbox-down%s (also deletes its data;\n' "$green" "$reset"
printf '    %sjust lab-down%s stops it too)\n' "$green" "$reset"
