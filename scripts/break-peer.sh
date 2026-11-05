#!/usr/bin/env bash
set -euo pipefail

# Shuts down rtr-phl's BGP session to sw-jfk — someone disabled a peer and
# forgot it. The link itself stays up (its /31 still pings), so only the
# BGP state gives it away, and sw-jfk's own config looks clean: the cause
# is on the other end. JFK's traffic shifts entirely onto the rtr-ewr
# path, so reachability survives and only redundancy is lost.
lab="clab-ac6-workshop"

docker exec "${lab}-rtr-phl" Cli -p 15 -c "configure
router bgp 65021
   neighbor 172.16.1.0 shutdown
end"

echo ""
echo "Broken: rtr-phl has shut down its BGP session to sw-jfk. Traffic to/from"
echo "JFK now crosses the WAN via rtr-ewr only — end-to-end reachability"
echo "survives, redundancy doesn't."
echo "Check: docker exec ${lab}-sw-jfk sr_cli \"show network-instance default protocols bgp neighbor\""
