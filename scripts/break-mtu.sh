#!/usr/bin/env bash
set -euo pipefail

# Drops core1's host1-facing interface back to the 1500 floor (SR Linux won't
# go lower on this interface type) — mismatched against host1's veth, which
# defaults to 9500 (containerlab's default). Small pings still succeed;
# anything bigger silently vanishes with no ICMP error — an L2-level drop,
# not a router-generated PMTUD response. That's the "subtle" part: nothing
# in the routing tables or adjacencies looks wrong.
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-core1" sr_cli -ed
set / interface ethernet-1/2 mtu 1500
commit now
CFG

echo ""
echo "Broken: core1's ethernet-1/2 is back to 1500, mismatched with host1."
echo "Check: docker exec ${lab}-host1 ping -c2 -s200 192.168.100.1   (works)"
echo "       docker exec ${lab}-host1 ping -c2 -s3000 192.168.100.1 (silently fails)"
