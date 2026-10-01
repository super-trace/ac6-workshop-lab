#!/usr/bin/env bash
set -euo pipefail

# Raises host1's own interface MTU above what the WAN link (core1's
# ethernet-1/2, fixed at SR Linux's 1500 floor) can carry — "someone jumbo-
# configured the customer box." Small pings still succeed; anything bigger
# silently vanishes with no ICMP error. That's the "subtle" part: nothing in
# any routing table or adjacency looks wrong, because nothing router-side
# changed — this one lives entirely on the customer's own device.
lab="clab-ac6-workshop"

docker exec "${lab}-host1" ip link set eth1 mtu 9500

echo ""
echo "Broken: host1's eth1 is back to 9500, mismatched with the 1500 WAN link."
echo "Check: docker exec ${lab}-host1 ping -c2 -s200 192.168.100.1   (works)"
echo "       docker exec ${lab}-host1 ping -c2 -s3000 192.168.100.1 (silently fails)"
