#!/usr/bin/env bash
set -euo pipefail

# Raises client-jfk's own interface MTU above what the WAN link
# (leaf-jfk's ethernet-1/2, fixed at SR Linux's 1500 floor) can carry —
# "someone jumbo-configured the customer box." Small pings still succeed;
# anything bigger silently vanishes with no ICMP error. That's the subtle
# part: nothing in any routing table or adjacency looks wrong, because
# nothing router-side changed — this one lives entirely on the customer's
# own device.
lab="clab-ac6-workshop"

docker exec "${lab}-client-jfk" ip link set eth1 mtu 9500

echo ""
echo "Broken: client-jfk's eth1 is at 9500, mismatched with the 1500 WAN link."
echo "Check: docker exec ${lab}-client-jfk ping -c2 -s200 192.168.11.1   (works)"
echo "       docker exec ${lab}-client-jfk ping -c2 -s3000 192.168.11.1 (silently fails)"
