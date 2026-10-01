#!/usr/bin/env bash
set -euo pipefail

# This is also what `just lab-up` runs once, after the lab settles, to reach
# the healthy baseline — see the note in the justfile's lab-up recipe for why
# this isn't baked into core1's startup-config instead.
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-core1" sr_cli -ed
set / interface ethernet-1/2 mtu 9000
commit now
CFG

echo ""
echo "Fixed: core1's ethernet-1/2 is jumbo (9000), matching host1 again."
