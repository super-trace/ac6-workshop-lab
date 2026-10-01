#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-leaf1" sr_cli -ed
set / network-instance default protocols ospf instance main area 0.0.0.0 interface ethernet-1/2.0 interface-type point-to-point
commit now
CFG

docker exec "${lab}-leaf1" sr_cli "tools network-instance default protocols ospf instance main neighbors clear"

echo ""
echo "Fixed: leaf1<->spine1 OSPF will settle back at Full."
