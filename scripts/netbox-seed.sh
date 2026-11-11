#!/usr/bin/env bash
# Seed NetBox with what arista should look like, the source of truth for
# Scenario 3, plus a few deliberate discrepancies for the agent to find (see
# the README's Scenario 3 facilitator reference). Run by netbox-up.sh once
# NetBox is healthy.
#
# Seeds once: the workshop-seed tag is created last, and its presence skips
# the seed, so a lab-down/lab-up keeps whatever attendees changed. A seed
# that failed partway leaves no tag, so the next run fails loudly on a
# duplicate; `just reset-netbox` starts it over.
#
# curl only: the Codespace host has neither jq nor python3.
set -euo pipefail

url="${NETBOX_URL:-http://localhost:8000}"
token="nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000"

# api METHOD PATH [JSON]: prints the response body; fails on a non-2xx status.
api() {
    local body code
    body="$(mktemp)"
    code="$(curl -sS -o "$body" -w '%{http_code}' -X "$1" \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/json" -H "Content-Type: application/json" \
        ${3:+--data "$3"} "${url}/api/$2")"
    if [[ "$code" != 2* ]]; then
        echo "netbox-seed: $1 $2 answered HTTP ${code}: $(head -c 300 "$body")" >&2
        rm -f "$body"
        return 1
    fi
    cat "$body"
    rm -f "$body"
}

# post PATH JSON: creates an object and prints its id (the first "id" in the
# response is the object's own).
post() {
    api POST "$1" "$2" | grep -o '"id":[0-9]*' | head -n1 | cut -d: -f2
}

if api GET "extras/tags/?slug=workshop-seed&brief=1" | grep -q '"count":1'; then
    echo "NetBox: already seeded; keeping its data."
    exit 0
fi

why='"changelog_message":"workshop seed: arista as documented"'

post dcim/sites/ "{\"name\":\"lab\",\"slug\":\"lab\",\"status\":\"active\",${why}}" >/dev/null
post dcim/manufacturers/ "{\"name\":\"Arista\",\"slug\":\"arista\",${why}}" >/dev/null
post dcim/device-types/ "{\"manufacturer\":{\"slug\":\"arista\"},\"model\":\"cEOS-lab\",\"slug\":\"ceos-lab\",\"u_height\":0,${why}}" >/dev/null
post dcim/device-roles/ "{\"name\":\"router\",\"slug\":\"router\",\"color\":\"2196f3\",${why}}" >/dev/null
post dcim/platforms/ "{\"name\":\"Arista EOS\",\"slug\":\"eos\",\"manufacturer\":{\"slug\":\"arista\"},${why}}" >/dev/null

device="$(post dcim/devices/ "{\"name\":\"arista\",\"site\":{\"slug\":\"lab\"},\"device_type\":{\"slug\":\"ceos-lab\"},\"role\":{\"slug\":\"router\"},\"platform\":{\"slug\":\"eos\"},\"status\":\"active\",\"comments\":\"EOS 4.36.2F, AS 65001\",${why}}")"

# Drift: VLAN 130 is CAMERAS on arista.
vlan() { post ipam/vlans/ "{\"vid\":$1,\"name\":\"$2\",\"site\":{\"slug\":\"lab\"},\"status\":\"active\",${why}}"; }
v110="$(vlan 110 DATA)"
v120="$(vlan 120 VOICE)"
v130="$(vlan 130 SECURITY)"

# iface NAME TYPE DESCRIPTION [EXTRA_JSON]: prints the interface id.
iface() {
    post dcim/interfaces/ "{\"device\":${device},\"name\":\"$1\",\"type\":\"$2\",\"description\":\"$3\"${4:-},${why}}"
}
ma0="$(iface Management0 1000base-t "" ',"mgmt_only":true')"
et1="$(iface Ethernet1 1000base-t "BGP: eBGP peer AS65002")"
# Drift, NetBox's side wins: the documented description standard names the
# trunk's VLANs; arista still says "TRUNK: to peer switch".
iface Ethernet2 1000base-t "TRUNK: VLANs 110,120,130" ",\"mode\":\"tagged\",\"tagged_vlans\":[${v110},${v120},${v130}]" >/dev/null
lo0="$(iface Loopback0 virtual "LOOPBACK: router-id 10.255.0.1")"
# Drift: Loopback1 (172.16.10.1/24, the LAN arista advertises) is missing.
sv110="$(iface Vlan110 virtual "VLAN 110 DATA gateway")"
sv120="$(iface Vlan120 virtual "VLAN 120 VOICE gateway")"
sv130="$(iface Vlan130 virtual "VLAN 130 CAMERAS gateway")"

# ip ADDRESS INTERFACE_ID DESCRIPTION [EXTRA_JSON]: prints the address id.
ip() {
    post ipam/ip-addresses/ "{\"address\":\"$1\",\"status\":\"active\",\"assigned_object_type\":\"dcim.interface\",\"assigned_object_id\":$2,\"description\":\"$3\"${4:-},${why}}"
}
mgmt="$(ip 172.20.23.3/24 "$ma0" "Management")"
ip 10.0.0.0/31 "$et1" "eBGP peer AS65002" >/dev/null
ip 10.255.0.1/32 "$lo0" "Router ID" ',"role":"loopback"' >/dev/null
ip 10.110.0.1/24 "$sv110" "VLAN 110 DATA gateway" >/dev/null
# Drift: arista's VLAN 120 gateway is 10.120.0.1.
ip 10.120.0.254/24 "$sv120" "VLAN 120 VOICE gateway" >/dev/null
ip 10.130.0.1/24 "$sv130" "VLAN 130 CAMERAS gateway" >/dev/null
api PATCH "dcim/devices/${device}/" "{\"primary_ip4\":${mgmt},${why}}" >/dev/null

# Last, so only a complete seed is ever skipped.
post extras/tags/ "{\"name\":\"workshop-seed\",\"slug\":\"workshop-seed\",\"description\":\"NetBox was seeded for the AC6 workshop\",${why}}" >/dev/null
echo "NetBox: seeded arista (site lab, 7 interfaces, 3 VLANs, 6 IP addresses)."
