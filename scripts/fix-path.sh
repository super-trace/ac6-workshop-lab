#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

docker exec "${lab}-rtr-phl" Cli -p 15 -c "configure
router bgp 65021
   no neighbor 172.16.3.0 route-map TO-IAD out
no route-map TO-IAD
no ip prefix-list JFK-CLIENTS
end
clear ip bgp 172.16.3.0 soft out"

echo ""
echo "Fixed: rtr-phl advertises 192.168.11.0/24 (client-jfk) to sw-iad again."
