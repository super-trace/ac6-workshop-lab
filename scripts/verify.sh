#!/usr/bin/env bash
# Baseline check: nokia is fully configured, sonic is reachable and blank,
# both links are up, both SSH aliases work, and NetBox and the GitHub MCP
# proxy answer.
set -euo pipefail

lab="clab-ac6-workshop"
checks_failed=0

heading() { printf '\033[1;36m== %s ==\033[0m\n' "$*"; }
fail() {
    printf '\033[1;31m!! %s\033[0m\n' "$*" >&2
    checks_failed=1
}

# expect OUTPUT PATTERN COUNT WHAT: fails unless at least COUNT lines of
# OUTPUT match the extended regex PATTERN.
expect() {
    local got
    got="$(grep -cE -- "$2" <<<"$1" || true)"
    if (( got < $3 )); then
        fail "expected ${4} (${3}), found ${got}"
    fi
}

heading "nokia links to sonic (expect ethernet-1/1 and ethernet-1/2 up)"
out="$(docker exec "${lab}-nokia" sr_cli "show interface brief" 2>/dev/null || true)"
grep -E 'ethernet-1/[12] ' <<<"$out" || true
expect "$out" '^\| ethernet-1/[12] +\| enable +\| up ' 2 "nokia links up"

echo
heading "nokia trunk (expect VLAN gateways 110, 120 and 130 up on ethernet-1/2)"
out="$(docker exec "${lab}-nokia" sr_cli "show interface ethernet-1/2" 2>/dev/null || true)"
grep -E 'ethernet-1/2\.1[123]0' <<<"$out" || true
expect "$out" 'ethernet-1/2\.1[123]0 is up' 3 "nokia VLAN subinterfaces up"

echo
heading "nokia BGP (expect neighbor 10.0.0.1 configured toward AS 65002)"
out="$(docker exec "${lab}-nokia" sr_cli "show network-instance default protocols bgp neighbor" 2>/dev/null || true)"
grep -E '10\.0\.0\.1' <<<"$out" || true
expect "$out" '10\.0\.0\.1 .* 65002 ' 1 "nokia BGP neighbor 10.0.0.1"

echo
heading "sonic (expect blank: no addresses, VLANs or BGP yet; Ethernet0 and Ethernet4 up)"
out="$(docker exec "${lab}-sonic" show interfaces status 2>/dev/null || true)"
grep -E '^ +Ethernet[04] ' <<<"$out" || true
expect "$out" '^ +Ethernet[04] .* up +up ' 2 "sonic lab ports up"
leftovers=""
docker exec "${lab}-sonic" vtysh -c "show running-config" 2>/dev/null | grep -q '^router bgp' && leftovers+=" BGP"
docker exec "${lab}-sonic" sonic-db-cli CONFIG_DB KEYS 'VLAN|*' 2>/dev/null | grep -q . && leftovers+=" VLANs"
docker exec "${lab}-sonic" sonic-db-cli CONFIG_DB KEYS 'INTERFACE|*' 2>/dev/null | grep -q . && leftovers+=" addresses"
if [ -n "$leftovers" ]; then
    echo "   sonic already has${leftovers} configured; run 'just reset-sonic' for a blank slate."
else
    echo "   blank, as expected"
fi

echo
heading "SSH (expect each alias to answer, as stcli connects)"
for node in nokia sonic; do
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "${node}" "show version" >/dev/null 2>&1; then
        echo "   ${node}: ok"
    elif [ "${node}" = sonic ] && ! docker exec "${lab}-sonic" supervisorctl status sshd 2>/dev/null | grep -q RUNNING; then
        fail "ssh sonic failed: sshd isn't running on sonic — run 'just lab-up'"
    else
        fail "ssh ${node} failed — run 'just lab-up', which reinstalls the SSH aliases"
    fi
done

echo
heading "NetBox (expect the API to answer on port 8000 and to document nokia)"
netbox_token="nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000"
out="$(curl -s --max-time 10 -H "Authorization: Bearer ${netbox_token}" \
    http://localhost:8000/api/status/ || true)"
version="$(sed -nE 's/.*"netbox-version": *"([^"]+)".*/\1/p' <<<"$out")"
if [ -z "$version" ]; then
    fail "NetBox not answering on http://localhost:8000 — run 'just netbox-up'"
elif curl -s --max-time 10 -H "Authorization: Bearer ${netbox_token}" \
    "http://localhost:8000/api/dcim/devices/?name=nokia&brief=1" | grep -q '"count":1'; then
    echo "   NetBox ${version}: ok, nokia documented"
else
    fail "NetBox ${version} answers but does not document nokia — run 'just reset-netbox'"
fi

echo
heading "GitHub MCP (expect GitHub's MCP server through the proxy on port 8002)"
# Only the handshake: a 200 proves the proxy is up and GitHub took the token.
mcp_headers=(-H "Content-Type: application/json" -H "Accept: application/json, text/event-stream")
code="$(curl -s --max-time 15 -o /dev/null -w '%{http_code}' "${mcp_headers[@]}" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"lab-verify","version":"1"}}}' \
    "http://localhost:8002/mcp/readonly" || true)"
case "$code" in
    200) echo "   GitHub answered: ok" ;;
    401)
        if [ "${CODESPACES:-}" = "true" ]; then
            fail "GitHub refused the token — run 'just lab-up' again from a Codespace terminal"
        else
            echo "   GitHub refused: GITHUB_TOKEN wasn't set when the lab started (fine outside a Codespace; export one and run 'just netbox-up' to use it)"
        fi
        ;;
    *) fail "GitHub MCP proxy not answering on port 8002 (HTTP ${code:-none}) — run 'just netbox-up'" ;;
esac

echo
if (( checks_failed )); then
    ./scripts/banner.sh red "LAB VERIFICATION FAILED"
    exit 1
fi
./scripts/banner.sh green "LAB IS VERIFIED"
