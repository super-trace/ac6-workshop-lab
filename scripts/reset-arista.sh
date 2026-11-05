#!/usr/bin/env bash
# Put arista back to its blank baseline without redeploying nokia.
# `just lab-up` saves that baseline as flash:baseline.cfg; it includes the
# Management0 address containerlab injects, so SSH keeps working.
set -euo pipefail

container="clab-ac6-workshop-arista"
docker exec "${container}" Cli -p 15 -c $'configure replace flash:baseline.cfg\nwrite memory' >/dev/null
echo "arista reset to its blank baseline."
