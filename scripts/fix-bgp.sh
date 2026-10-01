#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-edge1" sr_cli -ed
set / routing-policy prefix-set advertised prefix 192.168.100.0/24 mask-length-range exact
commit now
CFG

docker exec "${lab}-edge1" sr_cli "tools network-instance default protocols bgp neighbor 203.0.113.1 reset-peer"

echo ""
echo "Fixed: edge1 is re-advertising 192.168.100.0/24 to isp1."
