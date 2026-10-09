#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"
checks_failed=0

echo "== JFK intra-site OSPF (expect Full on the leaf link) =="
docker exec "${lab}-spine-jfk" sr_cli "show network-instance default protocols ospf neighbor"

echo
echo "== IAD intra-site OSPF (expect Full on the leaf link) =="
docker exec "${lab}-spine-iad" Cli -p 15 -c "show ip ospf neighbor"

echo
echo "== spine-jfk eBGP (expect Established to both rtr-phl and rtr-ewr) =="
docker exec "${lab}-spine-jfk" sr_cli "show network-instance default protocols bgp neighbor"

echo
echo "== spine-iad eBGP (expect Established to both rtr-phl and rtr-ewr) =="
docker exec "${lab}-spine-iad" Cli -p 15 -c "show bgp summary"

echo
echo "== WAN core: rtr-phl and rtr-ewr eBGP sessions (expect 3 Established each) =="
docker exec "${lab}-rtr-phl" Cli -p 15 -c "show bgp summary"
docker exec "${lab}-rtr-ewr" sr_cli "show network-instance default protocols bgp neighbor"

echo
echo "== JFK's client1 subnet, as seen from IAD's spine (proves cross-WAN advertisement) =="
docker exec "${lab}-spine-iad" Cli -p 15 -c "show ip bgp 192.168.11.0/24"

echo
echo "== end-to-end: client-jfk -> client-iad, full stack (leaf->spine->WAN->spine->leaf) =="
docker exec "${lab}-client-jfk" ping -c 3 192.168.31.10

echo
echo "== MTU scenario baseline: both small and large pings should succeed =="
docker exec "${lab}-client-jfk" ping -c 2 -s 200 192.168.11.1 || checks_failed=1
docker exec "${lab}-client-jfk" ping -c 2 -s 3000 192.168.11.1 || checks_failed=1

echo
echo "== stcli SSH aliases (requires: just lab-setup, so ~/.ssh/ac6-workshop-key exists) =="
for node in spine-jfk leaf-jfk spine-iad leaf-iad rtr-phl rtr-ewr client-jfk client-iad; do
    echo "-- ${node} --"
    command="show version"
    case "$node" in client-*) command="echo ok" ;; esac
    ssh -F lab/ssh_config -o ConnectTimeout=5 "${node}" "${command}" \
        || { echo "!! ${node} ssh check failed" >&2; checks_failed=1; }
done

echo
if (( checks_failed )); then
    printf '\033[1;31mLAB VERIFICATION FAILED — check the errors above.\033[0m\n' >&2
    exit 1
fi

printf '\033[1;32m'
printf '╔══════════════════════════════════════╗\n'
printf '║                                      ║\n'
printf '║           LAB IS VERIFIED            ║\n'
printf '║                                      ║\n'
printf '╚══════════════════════════════════════╝\n'
printf '\033[0m'
