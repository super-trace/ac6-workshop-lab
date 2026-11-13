#!/usr/bin/env bash
# Run after deploy: wait for both devices, make sure nokia's startup config
# took, turn sonic's two lab ports on, seed its off-standard descriptions and
# save sonic's blank baseline for `just reset-sonic`, then wait for SSH on
# both.
set -euo pipefail

lab="clab-ac6-workshop"
nokia="${lab}-nokia"
sonic="${lab}-sonic"
cfg="lab/configs/nokia.cfg"

for _ in $(seq 1 90); do
    docker exec "${nokia}" sr_cli "show version" >/dev/null 2>&1 && break
    sleep 2
done
# containerlab has intermittently applied only part of an SR Linux
# startup-config; `set` lines are idempotent, so re-applying is a no-op when
# it all took.
{ grep -E '^set / ' "${cfg}"; echo "commit now"; } | docker exec -i "${nokia}" sr_cli -ed >/dev/null
echo "nokia: configured."

# SONiC is ready once its services are up: syncd has created the ports and
# bgpd (started last) is running.
for _ in $(seq 1 120); do
    if docker exec "${sonic}" supervisorctl status bgpd 2>/dev/null | grep -q RUNNING &&
       docker exec "${sonic}" sonic-db-cli APPL_DB EXISTS "PORT_TABLE:Ethernet4" 2>/dev/null | grep -q 1; then
        break
    fi
    sleep 2
done
# The image starts bgpd at boot; make sure, since a blank sonic without it
# can't run Scenario 2 at all.
docker exec "${sonic}" supervisorctl start bgpd >/dev/null 2>&1 || true
# SONiC ships every port admin-down. Turn on the two lab ports, so the
# cables are "plugged in"; the workshop configures everything else.
docker exec "${sonic}" config interface startup Ethernet0
docker exec "${sonic}" config interface startup Ethernet4
# Port counters for Scenario 4's metrics (gnmic reads COUNTERS_DB over gNMI).
# A real switch enables counter polling at boot; the virtual switch leaves it
# off, so COUNTERS_DB stays empty. It's saved in the baseline below, so
# reset-sonic keeps it.
docker exec "${sonic}" counterpoll port enable >/dev/null 2>&1
docker exec "${sonic}" counterpoll port interval 10000 >/dev/null 2>&1
# Two descriptions that break the team standard (README, "Team standards"),
# for Scenario 2's audit to find: Ethernet0 has no role or peer AS, and
# Ethernet8 describes a BGP peer though nothing is connected to it. They
# configure nothing, so sonic is still blank. This SONiC has no `config
# interface description`; a description is a CONFIG_DB field.
docker exec "${sonic}" sonic-db-cli CONFIG_DB HSET 'PORT|Ethernet0' description 'to nokia' >/dev/null
docker exec "${sonic}" sonic-db-cli CONFIG_DB HSET 'PORT|Ethernet8' description 'BGP: eBGP peer AS65003' >/dev/null
# The blank baseline for reset-sonic: CONFIG_DB and FRR's config files.
docker exec "${sonic}" bash -c \
    'sonic-cfggen -d --print-data > /etc/sonic/ac6-baseline.json &&
     rm -rf /etc/frr.ac6-baseline && cp -a /etc/frr /etc/frr.ac6-baseline'
echo "sonic: ports up, blank baseline saved."

# SSH comes up a little after the CLI. Only wait if the aliases are installed.
for node in nokia sonic; do
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
