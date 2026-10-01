#!/usr/bin/env bash
set -euo pipefail

# Removes the point-to-point network-type override on edge1's side of the
# edge1<->core1 link. Without it, SR Linux's OSPF treats the link as
# broadcast-type and needs DR/BDR election to reach Full — on a point-to-point
# veth with no real election outcome, it gets stuck at Two-Way indefinitely.
# A classic, very real OSPF gotcha: no error anywhere, adjacency just never
# finishes, confirmed live in this project's own dev session before it ever
# became a scripted scenario.
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-edge1" sr_cli -ed
delete / network-instance default protocols ospf instance main area 0.0.0.0 interface ethernet-1/2.0 interface-type
commit now
CFG

docker exec "${lab}-edge1" sr_cli "tools network-instance default protocols ospf instance main neighbors clear"

echo ""
echo "Broken: edge1<->core1 OSPF will settle at Two-Way, not Full."
echo "Check: docker exec ${lab}-edge1 sr_cli \"show network-instance default protocols ospf neighbor\""
