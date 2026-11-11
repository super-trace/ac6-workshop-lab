#!/usr/bin/env bash
# Run after deploy: wait for both devices, make sure nokia's small startup
# config took, save it as nokia's baseline checkpoint for `just reset-nokia`,
# then wait for SSH on both.
set -euo pipefail

lab="clab-ac6-workshop"
nokia="${lab}-nokia"
arista="${lab}-arista"
cfg="lab/configs/nokia.cfg"

for _ in $(seq 1 90); do
    docker exec "${arista}" Cli -p 15 -c "show version" >/dev/null 2>&1 && break
    sleep 2
done
echo "arista: CLI ready."

for _ in $(seq 1 90); do
    docker exec "${nokia}" sr_cli "show version" >/dev/null 2>&1 && break
    sleep 2
done
# containerlab has intermittently applied only part of an SR Linux
# startup-config; `set` lines are idempotent, so re-applying is a no-op when
# it all took.
{ grep -E '^set / ' "${cfg}"; echo "commit now"; } | docker exec -i "${nokia}" sr_cli -ed >/dev/null
docker exec "${nokia}" sr_cli "tools system configuration generate-checkpoint name baseline comment \"blank workshop start\"" >/dev/null
echo "nokia: blank baseline saved."

# SSH comes up a little after the CLI. Only wait if the aliases are installed.
for node in arista nokia; do
    ssh -G "${node}" 2>/dev/null | grep -qE '^port 240[12]$' || continue
    for _ in $(seq 1 30); do
        if ssh -o BatchMode=yes -o ConnectTimeout=5 "${node}" "show version" >/dev/null 2>&1; then
            echo "${node}: SSH ready."
            continue 2
        fi
        sleep 2
    done
    echo "${node}: SSH not answering yet; 'just lab-verify' will say if it stays down." >&2
done
