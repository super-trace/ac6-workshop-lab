#!/usr/bin/env bash
# Start the workshop's NetBox (lab/netbox/compose.yml), load the lab's
# skeleton into it (lab/netbox/seed.py) and print how to reach it. In a
# Codespace, also make port 8000 public so anyone with the URL can open it.
# Safe to re-run.
set -euo pipefail

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

# --wait returns once NetBox answers its health check; the first start also
# creates the database, so it takes longer than later ones.
docker compose up -d --wait --wait-timeout 600

# The grep hides the config-loading lines NetBox prints on every start.
docker compose exec -T netbox /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py \
    shell --no-startup --no-imports --interface python < seed.py 2>&1 \
    | grep -vE '^🧬 loaded config|LOGIN_REQUIRED is deprecated|^  warnings\.warn\($'

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
printf '\n    Loaded: sites JFK, IAD and WAN; Nokia, Arista and Linux device types,\n'
printf '    platforms; roles switch, wan and client. No devices yet.\n'
if [ "${CODESPACES:-}" = "true" ]; then
    if [ -n "$public" ]; then
        printf '\n    %sPort 8000 is public: anyone with the URL can open NetBox.%s\n' "$green" "$reset"
    else
        printf '\n    %sTo let others open it:%s Ports tab, right-click port 8000 (NetBox),\n' "$yellow" "$reset"
        printf '    Port Visibility, Public.\n'
    fi
fi
printf '\n    Stop it with: %sjust netbox-down%s (also deletes its data)\n' "$green" "$reset"
