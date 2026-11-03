#!/usr/bin/env bash
set -euo pipefail

# Removes client-jfk's subnet from sw-jfk's BGP export allow-list — a
# realistic "someone edited the prefix-list and dropped an entry" mistake.
# Single membership delete, not a whole-policy edit: avoids any statement-
# ordering ambiguity (see lab/configs/sw-jfk.cfg's comment on this
# design).
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-sw-jfk" sr_cli -ed
delete / routing-policy prefix-set advertised prefix 192.168.11.0/24 mask-length-range exact
commit now
CFG

docker exec "${lab}-sw-jfk" sr_cli "tools network-instance default protocols bgp neighbor 172.16.1.1 reset-peer"
docker exec "${lab}-sw-jfk" sr_cli "tools network-instance default protocols bgp neighbor 172.16.2.1 reset-peer"

echo ""
echo "Broken: sw-jfk no longer advertises 192.168.11.0/24 (client-jfk) to the WAN."
echo "Check from rtr-phl: docker exec ${lab}-rtr-phl Cli -p 15 -c 'show ip bgp'"
echo "Check from sw-iad: docker exec ${lab}-sw-iad Cli -p 15 -c \"show ip bgp 192.168.11.0/24\""
