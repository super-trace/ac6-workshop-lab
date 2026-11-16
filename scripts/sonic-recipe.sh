#!/usr/bin/env bash
# Print a hash of everything the lab's SONiC image is built from: its
# Dockerfile and the lab key it bakes in. sonic-image.sh stamps the image
# with it (label ac6.recipe), and `just lab-up` rebuilds or re-pulls any image
# whose stamp doesn't match the checkout, so a changed recipe never leaves an
# attendee on a stale image.
set -euo pipefail
cd "$(dirname "$0")/.."
sum=sha256sum
command -v sha256sum >/dev/null 2>&1 || sum="shasum -a 256"
cat lab/images/sonic/Dockerfile lab/ac6-workshop-key.pub | $sum | cut -c1-16
