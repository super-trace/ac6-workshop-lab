#!/usr/bin/env bash
# Hidden-along-the-path fault: rtr-phl quietly stops passing JFK's client
# prefix on to spine-iad. spine-jfk still advertises it, rtr-ewr still carries
# it, so IAD keeps reachability via EWR only — the PHL path is silently gone.
set -euo pipefail

lab="clab-ac6-workshop"

docker exec "${lab}-rtr-phl" Cli -p 15 -c "configure
ip prefix-list JFK-CLIENTS seq 10 permit 192.168.11.0/24
route-map TO-IAD deny 10
   match ip address prefix-list JFK-CLIENTS
route-map TO-IAD permit 20
router bgp 65021
   neighbor 172.16.3.0 route-map TO-IAD out
end
clear ip bgp 172.16.3.0 soft out"

echo ""
echo "Broken: rtr-phl filters 192.168.11.0/24 (client-jfk) toward spine-iad."
echo "IAD now reaches JFK only via rtr-ewr."
echo "Check from spine-iad: docker exec ${lab}-spine-iad Cli -p 15 -c \"show ip bgp 192.168.11.0/24\""
