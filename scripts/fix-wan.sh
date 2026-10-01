#!/usr/bin/env bash
set -euo pipefail

lab="clab-ac6-workshop"

cat << 'CFG' | docker exec -i "${lab}-spine-jfk" sr_cli -ed
set / interface ethernet-1/3 admin-state enable
commit now
CFG

echo ""
echo "Fixed: spine-jfk's link to rtr-phl is back up — BGP reconverges within"
echo "the 5s connect-retry timer (see lab/configs/spine-jfk.cfg)."
