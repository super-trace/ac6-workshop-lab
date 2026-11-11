#!/usr/bin/env bash
# Put sonic back to its blank baseline without redeploying nokia.
# `just lab-up` saves that baseline (scripts/lab-ready.sh): CONFIG_DB as
# /etc/sonic/ac6-baseline.json and FRR's config as /etc/frr.ac6-baseline.
set -euo pipefail

cd "$(dirname "$0")/.."
container="clab-ac6-workshop-sonic"
# Interfaces, IP addresses, VLANs: back to the baseline CONFIG_DB.
docker exec -i "${container}" python3 - <scripts/sonic-reset.py
# Routing: FRR's saved files back, then restart the daemons that hold BGP
# and static routes, so nothing typed into vtysh survives either.
docker exec "${container}" bash -c \
    'rm -rf /etc/frr && cp -a /etc/frr.ac6-baseline /etc/frr && supervisorctl restart bgpd staticd >/dev/null'
echo "sonic reset to its blank baseline."
