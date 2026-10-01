#!/usr/bin/env bash
set -euo pipefail

# containerlab applies startup-config as one big atomic `sr_cli -ed` batch +
# commit. core1's batch (interfaces + network-instance membership + OSPF +
# the static default route) intermittently, silently fails that one commit —
# confirmed repeatable, confirmed independent of memory pressure, stale
# checkpoints, and file content (isolated with a binary search: the *exact
# same* lines succeed reliably split across two smaller commits, and fail
# unpredictably as a single one). edge1's startup-config has never shown
# this, despite being comparably sized, so it looks like a core1-specific
# timing quirk rather than a content or size limit. Rather than chase the
# exact mechanism further, this script detects it and re-applies.
lab="clab-ac6-workshop"
cfg="lab/configs/core1.cfg"

has_network_instance() {
    # Exit code alone doesn't distinguish this — a missing network-instance
    # still exits 0 with empty output. Check for real output content instead.
    [ -n "$(docker exec "${lab}-core1" sr_cli 'show network-instance default interfaces' 2>/dev/null)" ]
}

if has_network_instance; then
    echo "core1: network-instance default present, nothing to heal."
    exit 0
fi

echo "core1: network-instance default missing (the known startup-config race) — re-applying in two commits."

# Stage 1: interfaces + network-instance membership.
grep -E '^set / (interface|network-instance default interface)' "${cfg}" \
    | docker exec -i "${lab}-core1" sr_cli -ed
echo "commit now" | docker exec -i "${lab}-core1" sr_cli -ed

# Stage 2: everything else (OSPF, static route).
grep -E '^set / network-instance default (protocols|static-routes|next-hop-groups)' "${cfg}" \
    | docker exec -i "${lab}-core1" sr_cli -ed
echo "commit now" | docker exec -i "${lab}-core1" sr_cli -ed

if has_network_instance; then
    echo "core1: healed."
else
    echo "core1: still missing network-instance default after retry — see README's 'Known containerlab/SR Linux quirk' section." >&2
    exit 1
fi
