#!/usr/bin/env bash
# clab.sh ARGS...: run containerlab ARGS from the repository root, via
# Docker-on-Docker (works on macOS + OrbStack, and on a Codespace's nested
# dockerd): a privileged sidecar shares the engine kernel and manages bridge
# interfaces. CLAB_IMAGE overrides the sidecar image.
set -euo pipefail

image="${CLAB_IMAGE:-ghcr.io/srl-labs/clab:latest}"
lab="$(pwd)/lab"

# IMPORTANT: the project's lab dir is mounted at the SAME path inside the
# privileged container as on the host. containerlab generates per-node config
# files and asks the docker daemon to bind-mount them into the lab nodes; the
# daemon only sees host filesystem paths, so the paths must mirror.
args=(--rm --privileged --pid=host --network=host
    -v /var/run/docker.sock:/var/run/docker.sock
    -v "${lab}:${lab}" -w "${lab}" --entrypoint containerlab)

# containerlab also writes each SR Linux node's hosts file through the
# daemon's own path, /var/lib/docker/containers/<id>/hosts; without that
# directory mounted, lab-up warns "Unable to populate hosts". Linux only: on
# macOS the daemon runs in a VM, so that host path isn't the daemon's.
if [[ "$(uname -s)" == Linux ]]; then
    args+=(-v /var/lib/docker/containers:/var/lib/docker/containers)
fi

if [[ ! -t 0 || ! -t 1 ]]; then
    exec docker run "${args[@]}" "$image" "$@"
fi

# containerlab colors its log and tables only on a terminal, so give it one.
# -t alone isn't enough: containerlab queries the terminal's colors, and
# without -i the replies spill into the shell. It prints log keys (file=,
# name=) faint, which most terminals render as hard-to-read gray; the filter
# recolors faint and bright-black text blue. It reads raw chunks, not lines,
# so the color queries (which end without a newline) pass straight through,
# and holds back an escape sequence split across two reads.
docker run -it "${args[@]}" "$image" "$@" | perl -e '
    $| = 1;
    my $carry = "";
    while (sysread(STDIN, my $chunk, 4096)) {
        $chunk = $carry . $chunk;
        $carry = $chunk =~ s/(\e[\[0-9;]*)\z// ? $1 : "";
        $chunk =~ s/\e\[(?:2|90)m/\e[34m/g;
        print $chunk;
    }
    print $carry;
'
