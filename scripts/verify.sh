#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

echo "== fabric OSPF neighbors (expect Full on all 4 leaf<->spine adjacencies) =="
docker exec "${lab}-leaf1" sr_cli "show network-instance default protocols ospf neighbor"
docker exec "${lab}-leaf2" sr_cli "show network-instance default protocols ospf neighbor"

echo
echo "== eBGP session (leaf1 <-> isp1, expect Established) =="
docker exec "${lab}-leaf1" sr_cli "show network-instance default protocols bgp neighbor"
docker exec "${lab}-isp1" vtysh -c "show ip bgp summary"

echo
echo "== customer LAN prefix on isp1 (expect 192.168.100.0/24) =="
docker exec "${lab}-isp1" vtysh -c "show ip bgp"

echo
echo "== end-to-end: host1 -> isp1 loopback (crosses both spines via ECMP) =="
docker exec "${lab}-host1" ping -c 3 203.0.113.1

echo
echo "== MTU scenario baseline: both small and large pings should succeed =="
docker exec "${lab}-host1" ping -c 2 -s 200 192.168.100.1 || true
docker exec "${lab}-host1" ping -c 2 -s 3000 192.168.100.1 || true

echo
echo "== stcli SSH aliases (requires: Include .../workshop/lab/ssh_config) =="
for node in leaf1 leaf2; do
    echo "-- ${node} --"
    # -o PubkeyAuthentication=no, PreferredAuthentications=password: SR
    # Linux's sshd doesn't offer keyboard-interactive, and plain `ssh` tries
    # every local key first, hitting MaxAuthTries before it ever offers a
    # password. stcli doesn't have this problem (internal/ssh/auth.go offers
    # both methods and lets the server pick) — this is purely an artifact of
    # testing with a bare `ssh` command.
    sshpass -p 'NokiaSrl1!' ssh -F lab/ssh_config -o PubkeyAuthentication=no \
        -o PreferredAuthentications=password -o ConnectTimeout=5 \
        "${node}" "show version" \
        || echo "!! ${node} ssh check failed" >&2
done
