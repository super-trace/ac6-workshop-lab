#!/usr/bin/env bash
set -euo pipefail

# Removes client-jfk's subnet from spine-jfk's BGP export allow-list — a
# realistic "someone edited the prefix-list and dropped an entry" mistake.
# Single membership delete, not a whole-policy edit: avoids any statement-
# ordering ambiguity (see lab/configs/spine-jfk.cfg's comment on this
# design).
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-spine-jfk" sr_cli -ed
delete / routing-policy prefix-set advertised prefix 192.168.11.0/24 mask-length-range exact
commit now
CFG

docker exec "${lab}-spine-jfk" sr_cli "tools network-instance default protocols bgp neighbor 172.16.1.1 reset-peer"
docker exec "${lab}-spine-jfk" sr_cli "tools network-instance default protocols bgp neighbor 172.16.2.1 reset-peer"

echo ""
echo "Broken: spine-jfk no longer advertises 192.168.11.0/24 (client-jfk) to the WAN."
echo "Check from rtr-phl: docker exec ${lab}-rtr-phl vtysh -c 'show ip bgp'"
echo "Check from spine-iad: docker exec ${lab}-spine-iad sr_cli \"show network-instance default protocols bgp routes ipv4 prefix 192.168.11.0/24\""
