#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"
checks_failed=0

# heading prints a check's title in cyan; fail prints a failure in red on
# stderr and marks the run failed. Colors keep both visible between the
# device output.
heading() { printf '\033[1;36m== %s ==\033[0m\n' "$*"; }
fail() {
    printf '\033[1;31m!! %s\033[0m\n' "$*" >&2
    checks_failed=1
}

# expect OUTPUT PATTERN COUNT WHAT: fails the run unless at least COUNT lines
# of OUTPUT match the extended regex PATTERN.
expect() {
    local got
    got="$(grep -cE -- "$2" <<<"$1" || true)"
    if (( got < $3 )); then
        fail "expected ${4} (${3}), found ${got}"
    fi
}

heading "JFK intra-site OSPF (expect Full on the leaf link)"
out="$(docker exec "${lab}-spine-jfk" sr_cli "show network-instance default protocols ospf neighbor")"
echo "$out"
expect "$out" ' full ' 1 "spine-jfk OSPF neighbor Full"

echo
heading "IAD intra-site OSPF (expect Full on the leaf link)"
out="$(docker exec "${lab}-spine-iad" Cli -p 15 -c "show ip ospf neighbor")"
echo "$out"
expect "$out" ' FULL ' 1 "spine-iad OSPF neighbor Full"

echo
heading "spine-jfk eBGP (expect Established to both rtr-phl and rtr-ewr)"
out="$(docker exec "${lab}-spine-jfk" sr_cli "show network-instance default protocols bgp neighbor")"
echo "$out"
expect "$out" ' wan .* established ' 2 "spine-jfk eBGP sessions established"

echo
heading "spine-iad eBGP (expect Established to both rtr-phl and rtr-ewr)"
out="$(docker exec "${lab}-spine-iad" Cli -p 15 -c "show bgp summary")"
echo "$out"
expect "$out" '^172\.16\..* Established' 2 "spine-iad eBGP sessions Established"

echo
heading "WAN core: rtr-phl and rtr-ewr eBGP sessions (expect 3 Established each)"
out="$(docker exec "${lab}-rtr-phl" Cli -p 15 -c "show bgp summary")"
echo "$out"
expect "$out" ' Established ' 3 "rtr-phl eBGP sessions Established"
out="$(docker exec "${lab}-rtr-ewr" sr_cli "show network-instance default protocols bgp neighbor")"
echo "$out"
expect "$out" ' established ' 3 "rtr-ewr eBGP sessions established"

echo
heading "JFK's client1 subnet, as seen from IAD's spine (proves cross-WAN advertisement)"
out="$(docker exec "${lab}-spine-iad" Cli -p 15 -c "show ip bgp 192.168.11.0/24")"
echo "$out"
# Both WAN paths, not just reachability: one path alone is the wan or path
# scenario still broken.
expect "$out" 'Paths: 2 available' 1 "192.168.11.0/24 at spine-iad via both rtr-phl and rtr-ewr"

echo
heading "end-to-end: client-jfk -> client-iad, full stack (leaf->spine->WAN->spine->leaf)"
docker exec "${lab}-client-jfk" ping -c 3 192.168.31.10

echo
heading "MTU scenario baseline: both small and large pings should succeed"
docker exec "${lab}-client-jfk" ping -c 2 -s 200 192.168.11.1 || fail "client-jfk 200-byte ping to its gateway failed"
docker exec "${lab}-client-jfk" ping -c 2 -s 3000 192.168.11.1 || fail "client-jfk 3000-byte ping to its gateway failed"

echo
heading "stcli SSH aliases (requires: just lab-setup, so ~/.ssh/ac6-workshop-key exists)"
for node in spine-jfk leaf-jfk spine-iad leaf-iad rtr-phl rtr-ewr client-jfk client-iad; do
    printf '\033[2m-- %s --\033[0m\n' "${node}"
    command="show version"
    case "$node" in client-*) command="echo ok" ;; esac
    ssh -F lab/ssh_config -o ConnectTimeout=5 "${node}" "${command}" \
        || fail "${node} ssh check failed"
done

echo
if (( checks_failed )); then
    printf '\033[1;31mLAB VERIFICATION FAILED — check the errors above.\033[0m\n' >&2
    exit 1
fi

printf '\033[1;32m'
printf '╔══════════════════════════════════════════════════════════════════════════╗\n'
printf '║                                                                          ║\n'
printf '║                             LAB IS VERIFIED                              ║\n'
printf '║                                                                          ║\n'
printf '╚══════════════════════════════════════════════════════════════════════════╝\n'
printf '\033[0m'
