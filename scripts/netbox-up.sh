#!/usr/bin/env bash
# Start the workshop's NetBox and its MCP server (lab/netbox/compose.yml),
# NetBox starting empty apart from its admin user (and keeping whatever's
# added until `just netbox-down`), and print how to reach both. In a
# Codespace, also make port 8000 (NetBox) public so anyone with the URL can
# open it; port 8001 (MCP) stays private. Safe to re-run.
#
# NetBox's first start runs its database migrations: under 2 minutes on a
# laptop, ~6 in a Codespace. So Codespace setup runs this once (--prepare),
# lab-down keeps the database, and lab-up only waits for a warm start.
#
#   --background  start the containers and return at once, so `just lab-up`
#                 can boot NetBox while containerlab deploys; a later run
#                 without it waits for both to be healthy.
#   --prepare     wait until healthy and leave it running, without the
#                 banner (setup.sh).
set -euo pipefail

mode="${1:-}"
case "$mode" in
    ""|--background|--prepare) ;;
    *) echo "usage: netbox-up.sh [--background|--prepare]" >&2; exit 2 ;;
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

# Say why the wait may be long, unless NetBox is already answering.
if [ "$(docker inspect -f '{{.State.Health.Status}}' ac6-netbox-netbox-1 2>/dev/null)" != "healthy" ]; then
    echo "NetBox: waiting for it to answer (a first start sets up its database:"
    echo "        up to ~7 minutes in a Codespace, ~2 on a laptop)."
fi

# --wait returns once NetBox and the MCP server answer their health checks.
docker compose up -d --wait --wait-timeout 900

if [ "$mode" = "--prepare" ]; then
    echo "NetBox: database ready."
    exit 0
fi

public=""
if [ "${CODESPACES:-}" = "true" ] && [ -n "${CODESPACE_NAME:-}" ]; then
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
# lab-down keeps NetBox's data, so it's only empty the first time.
devices="$(curl -s --max-time 10 \
    -H "Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000" \
    "http://localhost:8000/api/dcim/devices/?limit=1" | sed -nE 's/^\{"count": *([0-9]+).*/\1/p')"
if [ "${devices:-0}" = "0" ]; then
    printf '\n    NetBox is empty: no devices yet.\n'
else
    printf '\n    NetBox has %s device(s), kept from before (just netbox-down wipes it).\n' "$devices"
fi
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
