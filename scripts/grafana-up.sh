#!/usr/bin/env bash
# Start the lab's observability stack (lab/grafana/compose.yml): gnmic,
# Prometheus, Loki, Vector, Grafana and Grafana's MCP server. It joins
# containerlab's management network, so the lab must be deployed first. In a
# Codespace, Grafana's links point at the forwarded port 3000, which this
# makes public so the attendee's browser (and anyone they share the URL with)
# can open it; the MCP server listens on localhost only. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/../lab/grafana"

green=$'\033[1;32m'
yellow=$'\033[1;33m'
red=$'\033[1;31m'
bold=$'\033[1m'
reset=$'\033[0m'

if ! docker network inspect ac6 >/dev/null 2>&1; then
    printf '%sThe lab is not deployed: Grafana needs its network. Run just lab-up.%s\n' "$red" "$reset" >&2
    exit 1
fi

if [ "${CODESPACES:-}" = "true" ] && [ -n "${CODESPACE_NAME:-}" ]; then
    host="${CODESPACE_NAME}-3000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    url="https://${host}"
else
    host="localhost:3000"
    url="http://localhost:3000"
fi
# Grafana builds redirects and links from its root URL, and rejects a login
# posted from an origin it doesn't trust; the MCP server tells the agent which
# URL to give the attendee.
export GRAFANA_ORIGIN="$url" GRAFANA_HOST="$host"

# Everything but the MCP server first; --wait returns once Grafana answers its
# health check.
docker compose up -d --quiet-pull --remove-orphans --wait --wait-timeout 300 \
    gnmic prometheus loki syslog grafana

# The MCP server signs in as the service account `stcli`, role Editor: it can
# build dashboards and folders but not change datasources. Create the account
# once (it lives in Grafana's volume) and mint a fresh token each run,
# deleting the old ones, so no token needs storing anywhere.
api() {
    local method="$1" path="$2"; shift 2
    curl -fsS --max-time 10 -u oldprotocol:newbrain -X "$method" \
        -H "Content-Type: application/json" "$@" "http://localhost:3000/api/${path}"
}
sa_id="$(api GET 'serviceaccounts/search?query=stcli' | jq -r '[.serviceAccounts[] | select(.name == "stcli") | .id][0] // empty')"
if [ -z "$sa_id" ]; then
    sa_id="$(api POST serviceaccounts -d '{"name":"stcli","role":"Editor"}' | jq -r .id)"
fi
for old in $(api GET "serviceaccounts/${sa_id}/tokens" | jq -r '.[].id'); do
    api DELETE "serviceaccounts/${sa_id}/tokens/${old}" >/dev/null
done
GRAFANA_MCP_TOKEN="$(api POST "serviceaccounts/${sa_id}/tokens" -d '{"name":"grafana-mcp"}' | jq -r .key)"
export GRAFANA_MCP_TOKEN

docker compose up -d --quiet-pull --force-recreate --wait --wait-timeout 120 grafana-mcp

public=""
if [ "${CODESPACES:-}" = "true" ] && [ -n "${CODESPACE_NAME:-}" ]; then
    if gh codespace ports visibility 3000:public -c "$CODESPACE_NAME" >/dev/null 2>&1; then
        public=yes
    fi
fi

printf '\n'
../../scripts/banner.sh green "GRAFANA IS UP"
printf '\n'
printf '    %sURL%s         %s\n' "$bold" "$reset" "$url"
printf '    %sLogin%s       oldprotocol / newbrain\n' "$bold" "$reset"
printf '    %sGrafana MCP%s http://localhost:8003/mcp\n' "$bold" "$reset"
printf '\n    Metrics: gNMI from nokia and sonic (Prometheus). Logs: syslog from both (Loki).\n'
if [ "${CODESPACES:-}" = "true" ]; then
    if [ -n "$public" ]; then
        printf '\n    %sPort 3000 is public: anyone with the URL can open Grafana.%s\n' "$green" "$reset"
    else
        printf '\n    %sTo open it from another browser:%s Ports tab, right-click port 3000\n' "$yellow" "$reset"
        printf '    (Grafana), Port Visibility, Public.\n'
    fi
fi
printf '\n    Stop it with: %sjust grafana-down%s (also deletes its dashboards)\n' "$green" "$reset"
