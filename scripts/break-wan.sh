#!/usr/bin/env bash
set -euo pipefail

# Shuts spine-jfk's interface to rtr-phl — a link/WAN failure, not a config
# mistake (Scenario 1 already covers that story). JFK's traffic shifts
# entirely onto the rtr-ewr path. This is where the old topology's "lose
# one path, redundancy gone, reachability survives" story now lives —
# moved up from intra-site (there's only one spine per site now) to
# inter-site, which is arguably the more realistic place for it: a real
# 2-path WAN losing one path shouldn't be visible from a ping test, only
# from actually checking both BGP sessions.
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-spine-jfk" sr_cli -ed
set / interface ethernet-1/3 admin-state disable
commit now
CFG

echo ""
echo "Broken: spine-jfk's link to rtr-phl is down. Traffic to/from JFK now"
echo "crosses the WAN via rtr-ewr only — end-to-end reachability survives,"
echo "redundancy doesn't."
echo "Check: docker exec ${lab}-spine-jfk sr_cli \"show network-instance default protocols bgp neighbor\""
