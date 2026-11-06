#!/usr/bin/env bash
# Wait for arista to finish booting, then save its blank config as
# flash:baseline.cfg for `just reset-arista`. The saved copy includes the
# Management0 address containerlab injects, so a reset keeps SSH working.
set -euo pipefail

container="clab-ac6-workshop-arista"

for _ in $(seq 1 90); do
    docker exec "${container}" Cli -p 15 -c "show version" >/dev/null 2>&1 && break
    sleep 2
done
docker exec "${container}" Cli -p 15 -c "copy running-config flash:baseline.cfg" >/dev/null
echo "arista: blank baseline saved."

# SSH comes up a little after the CLI. Only wait if the alias is installed.
if ssh -G arista 2>/dev/null | grep -q '^port 2402$'; then
    for _ in $(seq 1 30); do
        ssh -o BatchMode=yes -o ConnectTimeout=5 arista "show hostname" >/dev/null 2>&1 \
            && { echo "arista: SSH ready."; exit 0; }
        sleep 2
    done
    echo "arista: SSH not answering yet; 'just lab-verify' will say if it stays down." >&2
fi
