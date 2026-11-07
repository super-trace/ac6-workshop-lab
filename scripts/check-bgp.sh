#!/usr/bin/env bash
# Goal check for the BGP exercise: the eBGP session between arista and nokia
# is Established and nokia has installed arista's prefixes.
set -euo pipefail

lab="clab-ac6-workshop"
failed=0
fail() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; failed=1; }

printf '\033[1;36m== arista: neighbor 10.0.0.1 ==\033[0m\n'
out="$(docker exec "${lab}-arista" Cli -p 15 -c "show ip bgp summary")"
echo "$out"
grep -qE '10\.0\.0\.1 .*Estab' <<<"$out" || fail "arista's session to 10.0.0.1 is not established"

echo
printf '\033[1;36m== nokia: route to arista'"'"'s LAN 172.16.10.0/24 ==\033[0m\n'
out="$(docker exec "${lab}-nokia" sr_cli "show network-instance default route-table ipv4-unicast prefix 172.16.10.0/24" 2>&1 || true)"
echo "$out"
if ! grep -q 'bgp' <<<"$out"; then
    fail "nokia has no BGP route to 172.16.10.0/24"
    echo "   SR Linux rejects every eBGP route until an import policy accepts it." >&2
fi

echo
if (( failed )); then ./scripts/banner.sh red "BGP NOT UP"; exit 1; fi
./scripts/banner.sh green "BGP IS UP"
