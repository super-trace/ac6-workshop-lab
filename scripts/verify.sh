#!/usr/bin/env bash
# Baseline check: arista is fully configured, nokia is reachable and blank,
# both links are up, and both SSH aliases work.
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
if (( checks_failed )); then
    ./scripts/banner.sh red "LAB VERIFICATION FAILED"
    exit 1
fi
./scripts/banner.sh green "LAB IS VERIFIED"
