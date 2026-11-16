#!/usr/bin/env bash
# Goal check for the BGP exercise: the eBGP session between nokia and sonic
# is Established and sonic has installed nokia's prefixes.
set -euo pipefail

lab="clab-ac6-workshop"
failed=0
fail() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; failed=1; }

printf '\033[1;36m== nokia: neighbor 10.0.0.1 ==\033[0m\n'
out="$(docker exec "${lab}-nokia" sr_cli "show network-instance default protocols bgp neighbor 10.0.0.1" 2>&1 || true)"
grep -E '10\.0\.0\.1|configured neighbors' <<<"$out" || true
grep -qE '10\.0\.0\.1 .*established' <<<"$out" || fail "nokia's session to 10.0.0.1 is not established"

echo
printf '\033[1;36m== sonic: route to nokia'"'"'s LAN 172.16.10.0/24 ==\033[0m\n'
out="$(docker exec "${lab}-sonic" vtysh -c "show ip route 172.16.10.0/24" 2>&1 || true)"
echo "$out"
if ! grep -q 'Known via "bgp"' <<<"$out"; then
    fail "sonic has no BGP route to 172.16.10.0/24"
    if docker exec "${lab}-sonic" vtysh -c "show ip bgp summary" 2>/dev/null | grep -q '(Policy)'; then
        echo "   The session is up, but FRR shows (Policy): it exchanges no eBGP routes" >&2
        echo "   until a policy allows them (bgp ebgp-requires-policy)." >&2
    fi
fi

echo
if (( failed )); then ./scripts/banner.sh red "BGP NOT UP"; exit 1; fi
./scripts/banner.sh green "BGP IS UP"
