#!/usr/bin/env bash
set -euo pipefail

# just — not preinstalled on the base devcontainer image. postCreateCommand
# runs as the non-root default user (vscode), which can't write to
# /usr/local/bin directly — sudo (passwordless for this user, standard on
# devcontainer base images) is required here.
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
    | sudo bash -s -- --to /usr/local/bin

# docker-in-docker's nested dockerd starts in the background and isn't
# necessarily ready the moment postCreateCommand runs — confirmed live
# ("failed to connect to the docker API ... no such file or directory" on
# an otherwise-clean build). Wait for the socket rather than racing it.
for i in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
done
docker info >/dev/null 2>&1 || { echo "dockerd never became ready" >&2; exit 1; }

# Unlike stcli-3node-lab, nothing here is licensed or proprietary — SR Linux
# and FRRouting are both freely pullable, so there's no GitHub Release asset
# to fetch and no account an attendee needs beyond ssh.supertrace.ai itself.
cd "$(dirname "$0")/.."
just lab-setup

echo ""
echo "Setup complete. Run: just lab-up    then: just verify"
echo "SSH ports 2401-2408 (spine-jfk, leaf-jfk, client-jfk, spine-iad, leaf-iad,"
echo "client-iad, rtr-phl, rtr-ewr) auto-forward — VS Code Ports tab, or"
echo "'gh codespace ports forward'."
