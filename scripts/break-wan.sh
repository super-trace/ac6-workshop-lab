#!/usr/bin/env bash
set -euo pipefail

# Shuts sw-jfk's interface to rtr-phl — a link/WAN failure, not a config
# mistake (the bgp scenario covers that story). JFK's traffic shifts
# entirely onto the rtr-ewr path: redundancy gone, reachability survives.
# A real 2-path WAN losing one path shouldn't be visible from a ping test,
# only from actually checking both BGP sessions.
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-sw-jfk" sr_cli -ed
set / interface ethernet-1/3 admin-state disable
commit now
CFG

echo ""
echo "Broken: sw-jfk's link to rtr-phl is down. Traffic to/from JFK now"
echo "crosses the WAN via rtr-ewr only — end-to-end reachability survives,"
echo "redundancy doesn't."
echo "Check: docker exec ${lab}-sw-jfk sr_cli \"show network-instance default protocols bgp neighbor\""
