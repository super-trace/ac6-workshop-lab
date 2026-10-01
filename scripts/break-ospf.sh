#!/usr/bin/env bash
set -euo pipefail

# Removes the point-to-point network-type override on leaf-jfk's side of
# the leaf-jfk<->spine-jfk link. Without it, SR Linux's OSPF treats the
# link as broadcast-type and needs DR/BDR election to reach Full — on a
# point-to-point veth with no real election outcome, it gets stuck at
# Two-Way indefinitely. A classic, very real OSPF gotcha: no error
# anywhere, adjacency just never finishes.
#
# This site has only one leaf, so this is a full outage for client-jfk,
# not a redundancy-loss-but-still-reachable scenario. That story lives in
# Scenario 4 (WAN path down) instead.
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-leaf-jfk" sr_cli -ed
delete / network-instance default protocols ospf instance main area 0.0.0.0 interface ethernet-1/1.0 interface-type
commit now
CFG

docker exec "${lab}-leaf-jfk" sr_cli "tools network-instance default protocols ospf instance main neighbors clear"

echo ""
echo "Broken: leaf-jfk<->spine-jfk OSPF will settle at Two-Way, not Full."
echo "client-jfk loses reachability entirely — there's only one leaf in this site."
echo "Check: docker exec ${lab}-leaf-jfk sr_cli \"show network-instance default protocols ospf neighbor\""
