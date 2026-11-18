#!/usr/bin/env bash
# Build the lab's optional MikroTik image: RouterOS CHR packaged by the
# srl-labs fork of vrnetlab (upstream vrnetlab's image doesn't work with
# containerlab's mikrotik_ros kind). Built locally and never pushed:
# MikroTik's redistribution terms are unclear.
#
# Usage: mikrotik-image.sh <image>
#   e.g. mikrotik-image.sh vrnetlab/mikrotik_routeros:7.25.1
set -euo pipefail

image="$1"
version="${image##*:}"
vrnetlab_rev=5af59cf917659e3a1b905ea3ffb404c000f83683
url="https://download.mikrotik.com/routeros/${version}/chr-${version}.vmdk.zip"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Downloading RouterOS CHR ${version} (about 45 MB)..."
curl -fL --retry 3 --connect-timeout 15 -o "${work}/chr.zip" "$url"
git init -q "${work}/vrnetlab"
git -C "${work}/vrnetlab" fetch -q --depth 1 https://github.com/srl-labs/vrnetlab "$vrnetlab_rev"
git -C "${work}/vrnetlab" checkout -q FETCH_HEAD
unzip -q "${work}/chr.zip" "chr-${version}.vmdk" -d "${work}/vrnetlab/mikrotik/routeros"

make -C "${work}/vrnetlab/mikrotik/routeros" docker-image
# The fork tags <version>-amd64, and <version> only on amd64 hosts.
docker tag "vrnetlab/mikrotik_routeros:${version}-amd64" "$image"
echo "Built ${image}."
