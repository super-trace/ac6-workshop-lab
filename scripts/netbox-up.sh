#!/usr/bin/env bash
# Start the workshop's NetBox and the GitHub MCP proxy (lab/netbox/compose.yml),
# seed NetBox with nokia as documented (scripts/netbox-seed.sh, once: what
# attendees change is kept until `just netbox-down` or `just reset-netbox`),
# and print how to reach both. Both listen on localhost only; NetBox's login
# and API token are public, so sharing port 8000 is left to the operator.
# Safe to re-run.
#
# A first start loads lab/netbox/initdb/'s already-migrated database, so it
# takes seconds rather than the minutes NetBox's own migrations would.
#
# --background starts the containers and returns at once, so `just lab-up`
# can boot NetBox while containerlab deploys; a later run without it waits
# for both to be healthy and prints the banner.
set -euo pipefail

mode="${1:-}"
case "$mode" in
    ""|--background) ;;
    *) echo "usage: netbox-up.sh [--background]" >&2; exit 2 ;;
esac

cd "$(dirname "$0")/../lab/netbox"

green=$'\033[1;32m'
yellow=$'\033[1;33m'
bold=$'\033[1m'
reset=$'\033[0m'

if [ "${CODESPACES:-}" = "true" ] && [ -n "${CODESPACE_NAME:-}" ]; then
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

if [ "$mode" = "--background" ]; then
    docker compose up -d --quiet-pull --remove-orphans >"$log_file" 2>&1 &
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

# --wait returns once NetBox answers its health check.
docker compose up -d --remove-orphans --wait --wait-timeout 900

NETBOX_URL=http://localhost:8000 ../../scripts/netbox-seed.sh


printf '\n'
../../scripts/banner.sh green "NETBOX IS UP"
printf '\n'
printf '    %sURL%s       %s\n' "$bold" "$reset" "$url"
printf '    %sLogin%s     oldprotocol / newbrain\n' "$bold" "$reset"
printf '    %sAPI token%s Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000\n' "$bold" "$reset"
printf '    %sGitHub MCP%s http://localhost:8002/mcp/readonly (proxy, adds your GITHUB_TOKEN)\n' "$bold" "$reset"
printf '\n    NetBox documents nokia: the source of truth for Scenario 3.\n'
printf '    %sjust reset-netbox%s puts it back as seeded.\n' "$green" "$reset"
if [ "${CODESPACES:-}" = "true" ]; then
    printf '
    %sTo let others open it:%s Ports tab, right-click port 8000 (NetBox),
' "$yellow" "$reset"
    printf '    Port Visibility, Public. Anyone with the URL can then change it.
'
fi
printf '\n    Stop it with: %sjust netbox-down%s (also deletes its data)\n' "$green" "$reset"
