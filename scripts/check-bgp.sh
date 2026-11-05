#!/usr/bin/env bash
# Goal check for the BGP exercise: the eBGP session between nokia and arista
# is Established and arista has learned nokia's prefixes.
set -euo pipefail

lab="clab-ac6-workshop"
failed=0
fail() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; failed=1; }

printf '\033[1;36m== nokia: neighbor 10.0.0.1 ==\033[0m\n'
out="$(docker exec "${lab}-nokia" sr_cli "show network-instance default protocols bgp neighbor 10.0.0.1")"
echo "$out"
grep -qi 'established' <<<"$out" || fail "nokia's session to 10.0.0.1 is not established"

echo
printf '\033[1;36m== arista: BGP summary and routes from nokia ==\033[0m\n'
docker exec "${lab}-arista" Cli -p 15 -c "show ip bgp summary" || true
out="$(docker exec "${lab}-arista" Cli -p 15 -c "show ip bgp" 2>&1 || true)"
echo "$out"
grep -q '172.16.10.0/24' <<<"$out" || fail "arista has not learned 172.16.10.0/24 from nokia"

echo
if (( failed )); then ./scripts/banner.sh red "BGP NOT UP"; exit 1; fi
./scripts/banner.sh green "BGP IS UP"
