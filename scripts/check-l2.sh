#!/usr/bin/env bash
# Goal check for the layer 2 exercise: sonic reaches nokia's gateway in
# every trunked VLAN, which needs the VLANs on sonic, Ethernet4 as a tagged
# member of each, and an address in each VLAN.
set -euo pipefail

lab="clab-ac6-workshop"
failed=0
for vlan in 110 120 130; do
    gw="10.${vlan}.0.1"
    printf '\033[1;36m== VLAN %s: sonic -> nokia %s ==\033[0m\n' "${vlan}" "${gw}"
    if docker exec "${lab}-sonic" ping -c 2 -W 1 "${gw}" 2>/dev/null | grep -q ' 0% packet loss'; then
        echo "   ok"
    else
        printf '\033[1;31m!! VLAN %s: sonic cannot reach %s\033[0m\n' "${vlan}" "${gw}" >&2
        failed=1
    fi
done

echo
printf '\033[1;36m== nokia: neighbors learned on the trunk ==\033[0m\n'
docker exec "${lab}-nokia" sr_cli "show arpnd arp-entries interface ethernet-1/2" 2>/dev/null || true

echo
if (( failed )); then ./scripts/banner.sh red "LAYER 2 NOT UP"; exit 1; fi
./scripts/banner.sh green "LAYER 2 IS UP"
