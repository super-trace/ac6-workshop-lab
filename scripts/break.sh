#!/usr/bin/env bash
# Scenario 5: put the lab in the state Scenarios 2 and 4 end in, BGP and the
# trunk both working, then inject fault N. Each fault fails one check-*;
# the README's facilitator reference names them.
set -euo pipefail

cd "$(dirname "$0")/.."
n="${1:-}"
[[ "$n" =~ ^[1-4]$ ]] || { echo "usage: just break 1|2|3|4" >&2; exit 1; }

lab="clab-ac6-workshop"
nokia() { printf '%s\n' "$@" 'commit now' | docker exec -i "${lab}-nokia" sr_cli -ed >/dev/null; }
sonic() { docker exec -i "${lab}-sonic" bash -se >/dev/null; }

# Fault 2 is the only one on nokia; take it off before every break.
nokia 'delete / acl interface ethernet-1/1.0' 'delete / acl acl-filter EDGE-PROTECT type ipv4'

./scripts/reset-sonic.sh >/dev/null
sonic <<'EOF'
config interface ip add Ethernet0 10.0.0.1/31
config loopback add Loopback0
config interface ip add Loopback0 10.255.0.2/32
for v in 110 120 130; do
    config vlan add $v
    config vlan member add $v Ethernet4
    config interface ip add Vlan$v 10.$v.0.2/24
done
d() { sonic-db-cli CONFIG_DB HSET "$1" description "$2"; }
d 'PORT|Ethernet0' 'BGP: eBGP peer AS65001'
d 'PORT|Ethernet4' 'TRUNK: VLANs 110,120,130'
d 'PORT|Ethernet8' ''
d 'VLAN|Vlan110' 'VLAN 110 DATA gateway'
d 'VLAN|Vlan120' 'VLAN 120 VOICE gateway'
d 'VLAN|Vlan130' 'VLAN 130 CAMERAS gateway'
vtysh -c 'conf t' -c 'router bgp 65002' -c 'bgp router-id 10.255.0.2' \
    -c 'no bgp ebgp-requires-policy' -c 'neighbor 10.0.0.0 remote-as 65001' \
    -c 'address-family ipv4 unicast' -c 'network 10.255.0.2/32' -c 'end' -c 'write memory'
EOF

case "$n" in
1) sonic <<<"vtysh -c 'conf t' -c 'router bgp 65002' -c 'neighbor 10.0.0.0 remote-as 65010' -c 'end' -c 'write memory'" ;;
2) nokia 'set / acl acl-filter EDGE-PROTECT type ipv4 entry 10 match ipv4 protocol tcp' \
       'set / acl acl-filter EDGE-PROTECT type ipv4 entry 10 match transport destination-port value 179' \
       'set / acl acl-filter EDGE-PROTECT type ipv4 entry 10 action drop' \
       'set / acl acl-filter EDGE-PROTECT type ipv4 entry 20 match ipv4 protocol tcp' \
       'set / acl acl-filter EDGE-PROTECT type ipv4 entry 20 match transport source-port value 179' \
       'set / acl acl-filter EDGE-PROTECT type ipv4 entry 20 action drop' \
       'set / acl acl-filter EDGE-PROTECT type ipv4 entry 100 action accept' \
       'set / acl interface ethernet-1/1.0 input acl-filter EDGE-PROTECT type ipv4'
   # The ACL only stops new sessions; drop the one that's up.
   docker exec "${lab}-nokia" sr_cli "tools network-instance default protocols bgp neighbor 10.0.0.1 reset-peer" >/dev/null ;;
3) sonic <<<'config interface mtu Ethernet0 1400' ;;
4) sonic <<<'config vlan member del 120 Ethernet4' ;;
esac

./scripts/banner.sh red "FAULT ${n} IS IN"
printf '\n    Something in the lab is broken. Ask stcli why.\n'
