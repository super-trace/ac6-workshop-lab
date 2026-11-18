#!/usr/bin/env bash
# Build the lab's optional vJunos-switch image: a qcow2 downloaded from Juniper
# packaged by the srl-labs fork of vrnetlab. Built locally and never pushed.
#
# Usage: vjunos-image.sh <image> <qcow2>
#   e.g. vjunos-image.sh vrnetlab/juniper_vjunos-switch:25.2R1.9 ~/Downloads/vJunos-switch-25.2R1.9.qcow2
set -euo pipefail

image="$1"
qcow2="${2:-}"
version="${image##*:}"
vrnetlab_rev=5af59cf917659e3a1b905ea3ffb404c000f83683

if [ ! -f "$qcow2" ]; then
    echo "Download vJunos-switch ${version} (a .qcow2, about 3 GB) from https://support.juniper.net/support/downloads/?p=vjunos-switch" >&2
    echo "then run: just vjunos-image <path to vJunos-switch-${version}.qcow2>" >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git init -q "${work}/vrnetlab"
git -C "${work}/vrnetlab" fetch -q --depth 1 https://github.com/srl-labs/vrnetlab "$vrnetlab_rev"
git -C "${work}/vrnetlab" checkout -q FETCH_HEAD
ln -s "$(realpath "$qcow2")" "${work}/vrnetlab/juniper/vjunosswitch/vjunos-switch-${version}.qcow2"

# `make all` would first run a KVM-only AMD patch, so build the image directly.
make -C "${work}/vrnetlab/juniper/vjunosswitch" docker-image \
    DOCKER_BUILD_CMD="docker buildx build --platform linux/amd64 --load"
docker image inspect "$image" >/dev/null
echo "Built ${image}."
