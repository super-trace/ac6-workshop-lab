#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

docker exec "${lab}-rtr-phl" Cli -p 15 -c "configure
router bgp 65021
   no neighbor 172.16.1.0 shutdown
end"

echo ""
echo "Fixed: rtr-phl's BGP session to sw-jfk is enabled again — it reconverges"
echo "within sw-jfk's 5s connect-retry timer (see lab/configs/sw-jfk.cfg)."
