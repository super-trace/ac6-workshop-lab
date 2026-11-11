#!/usr/bin/env bash
# Put nokia back to its blank baseline without redeploying arista.
# `just lab-up` saves that baseline as the "baseline" checkpoint.
set -euo pipefail

container="clab-ac6-workshop-nokia"
docker exec "${container}" sr_cli "tools system configuration checkpoint baseline revert" >/dev/null
echo "nokia reset to its blank baseline."
