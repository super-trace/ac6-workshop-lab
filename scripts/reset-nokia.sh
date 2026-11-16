#!/usr/bin/env bash
# Put nokia back to its configured baseline without redeploying sonic or
# breaking the links between them. `just lab-up` saves that baseline as the
# SR Linux checkpoint `ac6-baseline` (scripts/lab-ready.sh); reverting to it
# replaces the whole running config, so anything added since is removed.
set -euo pipefail

container="clab-ac6-workshop-nokia"
if ! docker exec "${container}" sr_cli -d 'info from state system configuration checkpoint * name' 2>/dev/null |
        grep -q 'name ac6-baseline$'; then
    echo "nokia has no saved baseline yet (labs started before this recipe existed); run 'just lab-reset'." >&2
    exit 1
fi
docker exec "${container}" sr_cli -d 'tools system configuration checkpoint ac6-baseline revert' >/dev/null
echo "nokia reset to its configured baseline."
