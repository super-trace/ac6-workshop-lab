#!/usr/bin/env bash
set -euo pipefail

# containerlab applies an SR Linux startup-config as one big `sr_cli -ed`
# batch + commit, which has intermittently and silently applied only part of
# the file. The same lines apply reliably split across two smaller commits,
# so this re-applies the nokia config that way on every `lab-up`. `set`
# commands are idempotent, so re-applying a correct config is a no-op.
node="nokia"
container="clab-ac6-workshop-${node}"
cfg="lab/configs/${node}.cfg"
stage1='^set / (interface|network-instance default interface)'

# Stage 1: interfaces + default network-instance membership.
grep -E "${stage1}" "${cfg}" | docker exec -i "${container}" sr_cli -ed
echo "commit now" | docker exec -i "${container}" sr_cli -ed

# Stage 2: everything else (mac-vrfs, routing-policy, BGP, the stcli user).
grep -E '^set / ' "${cfg}" | grep -vE "${stage1}" | docker exec -i "${container}" sr_cli -ed
echo "commit now" | docker exec -i "${container}" sr_cli -ed

if docker exec "${container}" sr_cli 'show network-instance default protocols bgp neighbor' 2>/dev/null | grep -q '10.0.0.1'; then
    echo "${node}: config applied."
else
    echo "${node}: BGP neighbor 10.0.0.1 missing after re-applying ${cfg}; inspect the device." >&2
    exit 1
fi
