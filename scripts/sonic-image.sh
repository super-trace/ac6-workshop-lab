#!/usr/bin/env bash
# Build the lab's SONiC image: SONiC's official virtual switch
# (docker-sonic-vs, Apache-2.0) plus the lab login, from
# lab/images/sonic/Dockerfile. Maintainers run this; attendees just
# `docker pull` the result (just lab-setup).
#
# SONiC publishes docker-sonic-vs only as a build artifact of its Azure
# pipeline, not in a registry, so this downloads the latest successful build
# of the release branch named by the image tag (202511 → branch 202511).
#
# Usage: sonic-image.sh <image> [--push]
#   e.g. sonic-image.sh ghcr.io/super-trace/ac6-workshop-lab/sonic-vs:202511 --push
# --push publishes it; the ghcr package must be public for attendees to pull.
set -euo pipefail

image="$1"
push="${2:-}"
branch="${image##*:}"
base="docker-sonic-vs:${branch}"
url="https://sonic-build.azurewebsites.net/api/sonic/artifacts?branchName=${branch}&platform=vs&target=target/docker-sonic-vs.gz"

cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Downloading SONiC ${branch} docker-sonic-vs (about 200 MB)..."
curl -fL --retry 3 --connect-timeout 15 --speed-limit 1024 --speed-time 60 \
    -o "${work}/docker-sonic-vs.gz" "$url"
loaded="$(docker load -i "${work}/docker-sonic-vs.gz" | sed -n 's/^Loaded image: //p' | tail -1)"
docker tag "$loaded" "$base"
docker run --rm --platform linux/amd64 --entrypoint cat "$base" /etc/sonic/sonic_version.yml |
    grep -E '^(branch|commit_id|build_date):' || true

# Context is lab/, for the shared lab key.
docker build --platform linux/amd64 --build-arg "BASE=${base}" \
    --label "ac6.recipe=$(./scripts/sonic-recipe.sh)" \
    -f lab/images/sonic/Dockerfile -t "$image" lab
echo "Built ${image}."

if [ "$push" = "--push" ]; then
    docker push "$image"
fi
