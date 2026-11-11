#!/usr/bin/env bash
# Goal check for the NetBox exercise: NetBox documents nokia as it really is
# wherever the seed left NetBox stale (see the README's Scenario 3 facilitator
# reference). The ethernet-1/2 description, where NetBox is the side that is
# right, is the attendee's call and is not checked.
set -euo pipefail

url="${NETBOX_URL:-http://localhost:8000}"
token="nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000"
failed=0
fail() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; failed=1; }
heading() { printf '\033[1;36m== %s ==\033[0m\n' "$*"; }

get() {
    curl -sS --max-time 10 -H "Authorization: Bearer ${token}" -H "Accept: application/json" "${url}/api/$1"
}

if ! get status/ | grep -q '"netbox-version"'; then
    fail "NetBox is not answering on ${url}; run 'just netbox-up'"
    ./scripts/banner.sh red "NETBOX NOT CHECKED"
    exit 1
fi

# first FIELD JSON: the first value of a string field, "" when there is none.
first() { { grep -o "\"$1\":\"[^\"]*\"" <<<"$2" || true; } | head -n1 | cut -d'"' -f4; }

# addresses INTERFACE: nokia's addresses on INTERFACE, space-separated; ""
# when the interface or its addresses are missing.
addresses() {
    local id
    id="$(get "dcim/interfaces/?device=nokia&name=$1&fields=id" | { grep -o '"id":[0-9]*' || true; } | head -n1 | cut -d: -f2)"
    [[ -n "$id" ]] || return 0
    get "ipam/ip-addresses/?interface_id=${id}&fields=address" | { grep -o '"address":"[^"]*"' || true; } | cut -d'"' -f4 | tr '\n' ' '
}

heading "VLAN 130 (nokia's gateway names it CAMERAS)"
name="$(first name "$(get "ipam/vlans/?site=lab&vid=130&fields=vid,name")")"
echo "   NetBox: ${name:-(no VLAN 130)}"
[[ "$name" == "CAMERAS" ]] || fail "NetBox names VLAN 130 '${name:-nothing}', nokia names it CAMERAS"

echo
heading "lo1 (nokia has 172.16.10.1/24)"
addrs="$(addresses lo1)"
echo "   NetBox: ${addrs:-(no lo1, or no address on it)}"
[[ " $addrs " == *" 172.16.10.1/24 "* ]] || fail "NetBox has no 172.16.10.1/24 on nokia's lo1"

echo
heading "VLAN 120 gateway, ethernet-1/2.120 (nokia has 10.120.0.1/24)"
addrs="$(addresses ethernet-1/2.120)"
echo "   NetBox: ${addrs:-(no address on ethernet-1/2.120)}"
[[ " $addrs " == *" 10.120.0.1/24 "* ]] || fail "NetBox does not give nokia's ethernet-1/2.120 10.120.0.1/24"
[[ " $addrs " != *" 10.120.0.254/24 "* ]] || fail "NetBox still gives nokia's ethernet-1/2.120 the stale 10.120.0.254/24"

echo
if (( failed )); then ./scripts/banner.sh red "NETBOX DOES NOT MATCH NOKIA"; exit 1; fi
./scripts/banner.sh green "NETBOX MATCHES NOKIA"
