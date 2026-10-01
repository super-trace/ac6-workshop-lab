#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-spine-jfk" sr_cli -ed
set / routing-policy prefix-set advertised prefix 192.168.11.0/24 mask-length-range exact
commit now
CFG

docker exec "${lab}-spine-jfk" sr_cli "tools network-instance default protocols bgp neighbor 172.16.1.1 reset-peer"
docker exec "${lab}-spine-jfk" sr_cli "tools network-instance default protocols bgp neighbor 172.16.2.1 reset-peer"

echo ""
echo "Fixed: spine-jfk is re-advertising 192.168.11.0/24 (client-jfk) to the WAN."
