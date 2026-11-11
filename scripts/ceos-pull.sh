#!/usr/bin/env bash
# Get the cEOS-lab image into the local Docker engine, straight from
# arista.com. super-trace doesn't host or redistribute it: cEOS-lab is
# Arista's, free behind an arista.com account, and its licence doesn't let us
# hand it out. Two ways in, both under the attendee's (or workshop's) own
# Arista account:
#
#   ARISTA_TOKEN set  Arista's eos-downloader (ardl) fetches it with that
#                     token and imports it. Create the token on your
#                     arista.com profile page. For Codespaces, it's a
#                     Codespaces secret named ARISTA_TOKEN (the repo's, so
#                     the prebuild has it, or the attendee's own).
#   a downloaded tar  `just ceos-import <cEOS64-lab-...tar.xz>` imports a file
#                     you downloaded from arista.com yourself.
#
# Usage: ceos-pull.sh <image>   e.g. arista/ceos:4.36.2F
# With AC6_CEOS_OPTIONAL set, a missing token is a warning, not a failure.
set -euo pipefail

image="$1"
name="${image%:*}"
version="${image##*:}"

docker image inspect "$image" >/dev/null 2>&1 && exit 0

how_to() {
    cat >&2 <<EOF
The Arista cEOS image ($image) isn't here yet. It comes from arista.com,
under your own (free) Arista account. Either:
  1. Create an access token at https://www.arista.com/en/users/profile, then
       ARISTA_TOKEN=<token> just ceos-pull
     In a Codespace, save it as a Codespaces secret named ARISTA_TOKEN
     (github.com/settings/codespaces) so it's there every time.
  2. Download cEOS64-lab-${version}.tar.xz (cEOSarm-lab on ARM64) from
     arista.com → Software Downloads → cEOS-lab, then
       just ceos-import path/to/cEOS64-lab-${version}.tar.xz
EOF
}

if [ -z "${ARISTA_TOKEN:-}" ]; then
    if [ -n "${AC6_CEOS_OPTIONAL:-}" ]; then
        echo "cEOS not downloaded: no ARISTA_TOKEN. 'just lab-up' asks for it later." >&2
        exit 0
    fi
    how_to
    exit 1
fi

case "$(docker version --format '{{.Server.Arch}}')" in
    arm64|aarch64) format=cEOSarm ;;
    *) format=cEOS64 ;;
esac

if command -v ardl >/dev/null 2>&1; then
    ardl=(ardl)
elif command -v uvx >/dev/null 2>&1; then
    ardl=(uvx --from eos-downloader==0.16.0 ardl)
elif command -v pipx >/dev/null 2>&1; then
    ardl=(pipx run --spec eos-downloader==0.16.0 ardl)
else
    echo "Arista's downloader (ardl) isn't installed: pip install eos-downloader==0.16.0, or install uv or pipx." >&2
    how_to
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
echo "Downloading ${format}-lab ${version} from arista.com (several hundred MB)..."
"${ardl[@]}" get eos --version "$version" --format "$format" --output "$work" \
    --import-docker --docker-name "$name" --docker-tag "$version" --no-progress
docker image inspect "$image" >/dev/null
echo "Imported $image."
