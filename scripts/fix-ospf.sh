#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-leaf-jfk" sr_cli -ed
set / network-instance default protocols ospf instance main area 0.0.0.0 interface ethernet-1/1.0 interface-type point-to-point
commit now
CFG

docker exec "${lab}-leaf-jfk" sr_cli "tools network-instance default protocols ospf instance main neighbors clear"

echo ""
echo "Fixed: leaf-jfk<->spine-jfk OSPF will settle back at Full."
