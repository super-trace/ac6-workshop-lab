#!/usr/bin/env bash
# Baseline check: nokia is fully configured, arista is reachable and blank,
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

heading "nokia links to arista (expect ethernet-1/1 and ethernet-1/2 up)"
out="$(docker exec "${lab}-nokia" sr_cli "show interface ethernet-1/{1,2} brief")"
echo "$out"
expect "$out" 'ethernet-1/[12] .*\| *enable *\| *up ' 2 "nokia links oper up"

echo
heading "nokia trunk (expect VLANs 110, 120 and 130 bridged on ethernet-1/2)"
out="$(docker exec "${lab}-nokia" sr_cli "show network-instance summary")"
echo "$out"
expect "$out" 'vlan1[123]0 .*mac-vrf .*up' 3 "nokia mac-vrfs up"

echo
heading "nokia BGP (expect neighbor 10.0.0.1 configured toward AS 65002)"
out="$(docker exec "${lab}-nokia" sr_cli "show network-instance default protocols bgp neighbor")"
echo "$out"
expect "$out" '10\.0\.0\.1' 1 "nokia BGP neighbor 10.0.0.1"

echo
heading "arista (expect blank: no BGP configured yet)"
out="$(docker exec "${lab}-arista" Cli -p 15 -c "show running-config section router bgp")"
if [[ -n "$out" ]]; then
    echo "$out"
    echo "   arista already has BGP config; run 'just reset-arista' for a blank slate."
else
    echo "   blank, as expected"
fi

echo
heading "SSH (expect each alias to answer, as stcli connects)"
for node in nokia arista; do
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
