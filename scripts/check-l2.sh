#!/usr/bin/env bash
# Goal check for the layer 2 exercise: nokia reaches arista's gateway in
# every trunked VLAN, which needs VLAN-tagged subinterfaces on nokia's
# ethernet-1/2 with an address in each VLAN.
set -euo pipefail

lab="clab-ac6-workshop"
failed=0
for vlan in 110 120 130; do
    gw="10.${vlan}.0.1"
    printf '\033[1;36m== VLAN %s: nokia -> arista %s ==\033[0m\n' "${vlan}" "${gw}"
    if docker exec "${lab}-nokia" sr_cli "ping ${gw} network-instance default -c 2 -W 1" 2>/dev/null | grep -q ' 0% packet loss'; then
        echo "   ok"
    else
        printf '\033[1;31m!! VLAN %s: nokia cannot reach %s\033[0m\n' "${vlan}" "${gw}" >&2
        failed=1
    fi
done

echo
printf '\033[1;36m== arista: MACs learned on the trunk ==\033[0m\n'
docker exec "${lab}-arista" Cli -p 15 -c "show mac address-table interface Ethernet2" || true

echo
if (( failed )); then ./scripts/banner.sh red "LAYER 2 NOT UP"; exit 1; fi
./scripts/banner.sh green "LAYER 2 IS UP"
