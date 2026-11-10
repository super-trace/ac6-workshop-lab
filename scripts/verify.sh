#!/usr/bin/env bash
# Baseline check: arista is fully configured, nokia is reachable and blank,
# both links are up, both SSH aliases work, and NetBox and its MCP server
# answer.
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

heading "arista links to nokia (expect Ethernet1 and Ethernet2 connected)"
out="$(docker exec "${lab}-arista" Cli -p 15 -c "show interfaces Ethernet1-2 status")"
echo "$out"
expect "$out" '^Et[12] .* connected ' 2 "arista links connected"

echo
heading "arista trunk (expect VLANs 110, 120 and 130 active on Ethernet2)"
out="$(docker exec "${lab}-arista" Cli -p 15 -c "show vlan")"
echo "$out"
expect "$out" '^1[123]0 .*active.*Et2' 3 "arista VLANs active on Ethernet2"

echo
heading "arista BGP (expect neighbor 10.0.0.1 configured toward AS 65002)"
out="$(docker exec "${lab}-arista" Cli -p 15 -c "show ip bgp summary")"
echo "$out"
expect "$out" '10\.0\.0\.1 .*65002' 1 "arista BGP neighbor 10.0.0.1"

echo
heading "nokia (expect blank: no BGP configured yet)"
out="$(docker exec "${lab}-nokia" sr_cli "info from running network-instance default protocols bgp" 2>/dev/null || true)"
if grep -q 'autonomous-system' <<<"$out"; then
    echo "$out"
    echo "   nokia already has BGP config; run 'just reset-nokia' for a blank slate."
else
    echo "   blank, as expected"
fi

echo
heading "SSH (expect each alias to answer, as stcli connects)"
for node in arista nokia; do
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "${node}" "show version" >/dev/null 2>&1; then
        echo "   ${node}: ok"
    else
        fail "ssh ${node} failed — run 'just lab-setup' to install the SSH aliases"
    fi
done

echo
heading "NetBox (expect the API to answer on port 8000 with the admin token)"
netbox_token="nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000"
out="$(curl -s --max-time 10 -H "Authorization: Bearer ${netbox_token}" \
    http://localhost:8000/api/status/ || true)"
version="$(sed -nE 's/.*"netbox-version": *"([^"]+)".*/\1/p' <<<"$out")"
if [ -n "$version" ]; then
    echo "   NetBox ${version}: ok"
else
    fail "NetBox not answering on http://localhost:8000 — run 'just netbox-up'"
fi

echo
heading "NetBox MCP (expect an MCP session and a tool call that reads NetBox)"
# The streamable HTTP handshake: initialize returns a session ID, the client
# confirms with notifications/initialized, then calls a tool. Listing sites
# goes through the MCP server to NetBox, so it also proves the server's token.
mcp="http://localhost:8001/mcp"
mcp_headers=(-H "Content-Type: application/json" -H "Accept: application/json, text/event-stream")
session="$(curl -s --max-time 10 -D - -o /dev/null "${mcp_headers[@]}" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"lab-verify","version":"1"}}}' \
    "$mcp" | tr -d '\r' | awk -F': ' 'tolower($1) == "mcp-session-id" { print $2 }' || true)"
if [ -z "$session" ]; then
    fail "NetBox MCP server not answering on ${mcp} — run 'just netbox-up'"
else
    curl -s --max-time 10 -o /dev/null "${mcp_headers[@]}" -H "mcp-session-id: ${session}" \
        -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' "$mcp" || true
    out="$(curl -s --max-time 30 "${mcp_headers[@]}" -H "mcp-session-id: ${session}" \
        -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"netbox_get_objects","arguments":{"object_type":"dcim.site","filters":{}}}}' \
        "$mcp" || true)"
    if grep -q '"isError":false' <<<"$out" && grep -q '"count":' <<<"$out"; then
        echo "   MCP session ${session:0:8}…, netbox_get_objects: ok"
    else
        echo "$out"
        fail "NetBox MCP server answered, but its call to NetBox failed — see 'docker logs ac6-netbox-netbox-mcp-1'"
    fi
fi

echo
if (( checks_failed )); then
    ./scripts/banner.sh red "LAB VERIFICATION FAILED"
    exit 1
fi
./scripts/banner.sh green "LAB IS VERIFIED"
