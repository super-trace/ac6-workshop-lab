#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

docker exec "${lab}-host1" ip link set eth1 mtu 1500

echo ""
echo "Fixed: host1's eth1 is back to 1500, matching the WAN link again."
