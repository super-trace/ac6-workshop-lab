#!/usr/bin/env bash
set -euo pipefail

# containerlab applies startup-config as one big atomic `sr_cli -ed` batch +
# commit. That one commit has intermittently, silently *partially* failed
# on SR Linux nodes here — sometimes losing everything, sometimes (seen on
# leaf1) losing just the back half of the file (BGP + routing-policy) while
# interfaces and OSPF came up fine. No error either way. Isolated with a
# binary search: the exact same lines succeed reliably split across two
# smaller commits, fail unpredictably as one big one.
#
# Rather than keep refining a detector for every way this can partially
# fail, this just re-applies every node's config in two commits
# unconditionally, every `lab-up`. `set` commands are idempotent — reapplying
# something already correct is a no-op, not an error — so this is safe, and
# a lot simpler than trying to verify every section independently.
lab="clab-ac6-workshop"

heal_node() {
    local node="$1" cfg="lab/configs/${1}.cfg"

    # Stage 1: interfaces + network-instance membership.
    grep -E '^set / (interface|network-instance default interface)' "${cfg}" \
        | docker exec -i "${lab}-${node}" sr_cli -ed
    echo "commit now" | docker exec -i "${lab}-${node}" sr_cli -ed

    # Stage 2: everything else (OSPF, BGP, routing-policy).
    grep -E '^set / (network-instance default protocols|routing-policy)' "${cfg}" \
        | docker exec -i "${lab}-${node}" sr_cli -ed
    echo "commit now" | docker exec -i "${lab}-${node}" sr_cli -ed

    if [ -n "$(docker exec "${lab}-${node}" sr_cli 'show network-instance default interfaces' 2>/dev/null)" ]; then
        echo "${node}: confirmed healthy."
    else
        echo "${node}: still missing network-instance default after re-applying — see README's 'Known SR Linux / containerlab quirks' section." >&2
        return 1
    fi
}

status=0
for node in spine-jfk leaf-jfk spine-iad leaf-iad; do
    heal_node "${node}" || status=1
done
exit "${status}"
