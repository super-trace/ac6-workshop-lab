#!/usr/bin/env bash
set -euo pipefail

# This is also what `just lab-up` runs once, after the lab settles, to reach
# the healthy baseline. client-jfk is deliberately the one client whose
# exec: block in topology.clab.yml doesn't set this — its veth defaults to
# 9500 (containerlab's default) otherwise. lab-up calling this is what gets
# it to the healthy 1500 baseline before anyone's watching.
lab="clab-ac6-workshop"

docker exec "${lab}-client-jfk" ip link set eth1 mtu 1500

echo ""
echo "Fixed: client-jfk's eth1 is at 1500, matching the WAN link again."
