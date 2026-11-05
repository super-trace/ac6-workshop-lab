#!/usr/bin/env bash
set -euo pipefail

# Puts an ACL on sw-jfk's LAN port (ethernet-1/1, toward client-jfk) that
# drops ping — echo requests and echo replies — and accepts everything
# else. Every ping to or from client-jfk fails, even to its own gateway,
# yet traffic flows and `traceroute` (UDP probes; the ICMP time-exceeded
# and port-unreachable answers it relies on still pass) shows every hop.
# ICMP traceroute (`traceroute -I`, mtr, Windows tracert) fails like ping.
# An input filter is enough: everything client-jfk sends, requests and
# replies alike, enters sw-jfk on this port.
lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-sw-jfk" sr_cli -ed
set / acl acl-filter LAN-IN type ipv4 description "client-jfk LAN, inbound"
set / acl acl-filter LAN-IN type ipv4 entry 10 match ipv4 protocol icmp
set / acl acl-filter LAN-IN type ipv4 entry 10 match ipv4 icmp type echo
set / acl acl-filter LAN-IN type ipv4 entry 10 action drop
set / acl acl-filter LAN-IN type ipv4 entry 20 match ipv4 protocol icmp
set / acl acl-filter LAN-IN type ipv4 entry 20 match ipv4 icmp type echo-reply
set / acl acl-filter LAN-IN type ipv4 entry 20 action drop
set / acl acl-filter LAN-IN type ipv4 entry 1000 action accept
set / acl interface ethernet-1/1.0 interface-ref interface ethernet-1/1
set / acl interface ethernet-1/1.0 interface-ref subinterface 0
set / acl interface ethernet-1/1.0 input acl-filter LAN-IN type ipv4
commit now
CFG

echo ""
echo "Broken: sw-jfk drops ping on its LAN port, both ways. client-jfk can't"
echo "ping anything (or be pinged), but traceroute still shows every hop."
echo "Check: docker exec ${lab}-client-jfk ping -c2 192.168.11.1"
echo "       docker exec ${lab}-client-jfk traceroute -n 192.168.31.10"
