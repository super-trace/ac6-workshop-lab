#!/usr/bin/env bash
# Goal check for the layer 2 exercise: arista reaches nokia's gateway in
# every trunked VLAN, which needs the trunk, the VLANs, and an address in
# each VLAN on the arista side.
set -euo pipefail

lab="clab-ac6-workshop"
failed=0
for vlan in 110 120 130; do
    gw="10.${vlan}.0.1"
    printf '\033[1;36m== VLAN %s: arista -> nokia %s ==\033[0m\n' "${vlan}" "${gw}"
    if docker exec "${lab}-arista" Cli -p 15 -c "ping ${gw} repeat 2 timeout 1" | grep -q ' 0% packet loss'; then
        echo "   ok"
    else
        printf '\033[1;31m!! VLAN %s: arista cannot reach %s\033[0m\n' "${vlan}" "${gw}" >&2
        failed=1
    fi
done

echo
printf '\033[1;36m== nokia: MACs learned on the trunk ==\033[0m\n'
for vlan in 110 120 130; do
    docker exec "${lab}-nokia" sr_cli "show network-instance vlan${vlan} bridge-table mac-table all" | grep -E 'ethernet-1/2' || true
done

echo
if (( failed )); then ./scripts/banner.sh red "LAYER 2 NOT UP"; exit 1; fi
./scripts/banner.sh green "LAYER 2 IS UP"
