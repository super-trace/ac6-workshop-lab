#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-sw-jfk" sr_cli -ed
delete / acl interface ethernet-1/1.0
delete / acl acl-filter LAN-IN type ipv4
commit now
CFG

echo ""
echo "Fixed: sw-jfk's LAN port no longer filters ping; client-jfk pings again."
