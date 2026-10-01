#!/usr/bin/env bash
set -euo pipefail

# Removes the customer LAN prefix from leaf1's BGP export allow-list — a
# realistic "someone edited the prefix-list and dropped an entry" mistake.
# Single membership delete, not a whole-policy edit: avoids any statement-
# ordering ambiguity (see lab/configs/leaf1.cfg's comment on this design).
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-leaf1" sr_cli -ed
delete / routing-policy prefix-set advertised prefix 192.168.100.0/24 mask-length-range exact
commit now
CFG

docker exec "${lab}-leaf1" sr_cli "tools network-instance default protocols bgp neighbor 203.0.113.1 reset-peer"

echo ""
echo "Broken: leaf1 no longer advertises 192.168.100.0/24 to isp1."
echo "Check from isp1: docker exec ${lab}-isp1 vtysh -c 'show ip bgp'"
