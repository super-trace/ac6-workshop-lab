set positional-arguments

# containerlab via Docker-on-Docker (works on macOS + OrbStack, and on a
# Codespace's nested dockerd): a privileged sidecar shares the engine kernel
# and manages bridge interfaces.
#
# IMPORTANT: the project's lab dir is mounted at the SAME path inside the
# privileged container as on the host. containerlab generates per-node config
# files and asks the docker daemon to bind-mount them into the lab nodes; the
# daemon only sees host filesystem paths, so the paths must mirror.
clab_image := "ghcr.io/srl-labs/clab:latest"
clab_run := "docker run --rm --privileged --pid=host --network=host -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/lab:$(pwd)/lab -w $(pwd)/lab --entrypoint containerlab " + clab_image

# default: list recipes
default:
    @just --list

# pre-pull images — everything here is free/public, no accounts or licenses
lab-setup:
    docker pull {{clab_image}}
    docker pull ghcr.io/nokia/srlinux:25.3.2
    docker pull frrouting/frr:latest
    docker pull ghcr.io/srl-labs/network-multitool

# bring up the lab (creates the ac6 mgmt network)
lab-up:
    {{clab_run}} deploy -t topology.clab.yml
    @echo ""
    @just lab-status
    # See README's "Known quirks" section: an SR Linux node's startup-config
    # has intermittently, silently failed to apply (root cause not fully
    # pinned down). heal-fabric.sh checks all four and fixes defensively;
    # it's a fast no-op when nothing's wrong, which is the common case.
    @sleep 10
    @./scripts/heal-fabric.sh

# tear down the lab
lab-down:
    {{clab_run}} destroy -t topology.clab.yml

# table of running lab nodes + their IPs
lab-status:
    {{clab_run}} inspect -t topology.clab.yml

# open a vendor CLI directly on a node: just lab-cli leaf1 | leaf2 | spine1 | spine2 | isp1 | host1
lab-cli NODE='leaf1':
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{NODE}}" in
      leaf1|leaf2|spine1|spine2) docker exec -it clab-ac6-workshop-{{NODE}} sr_cli ;;
      isp1)                      docker exec -it clab-ac6-workshop-isp1 vtysh ;;
      host1)                     docker exec -it clab-ac6-workshop-host1 sh ;;
      *) echo "unknown node {{NODE}}" >&2; exit 1 ;;
    esac

# run the infra verification checks (OSPF + BGP + prefix reachability)
verify:
    ./scripts/verify.sh

# quick structural sanity-check: does the real topology.clab.yml still match
# what the README's diagram claims? (needs graphviz locally —
# `brew install graphviz` — not needed to run the lab)
lab-graph:
    {{clab_run}} graph --dot -t topology.clab.yml
    dot -Tsvg lab/clab-ac6-workshop/graph/topology.clab.dot -o /tmp/ac6-workshop.svg
    @echo "Wrote /tmp/ac6-workshop.svg — open it and compare against the README diagram."
    @open /tmp/ac6-workshop.svg 2>/dev/null || true

# regenerate lab/topology.clab.png, the real diagram embedded in the README —
# run this after any topology.clab.yml change. Two steps: containerlab's own
# `graph --drawio` (via the clab-io-draw project) turns the topology into a
# .drawio file with real router/switch/host icons and a hierarchical layout
# (controlled by each node's `labels.graph-level`/`graph-icon` in
# topology.clab.yml); rlespinasse/drawio-desktop-headless then renders that
# to a static PNG, since GitHub doesn't render .drawio natively. Needs
# Docker only — no local drawio/graphviz install.
lab-diagram:
    {{clab_run}} graph --drawio -t topology.clab.yml
    docker run --rm -v "$(pwd)/lab":/data rlespinasse/drawio-desktop-headless \
        -x -f png --scale 2 -o /data/topology.clab.png /data/topology.clab.drawio
    @echo "Wrote lab/topology.clab.png and lab/topology.clab.drawio (editable at app.diagrams.net)."

# break/fix a named scenario: just break bgp | mtu | ospf
break SCENARIO:
    ./scripts/break-{{SCENARIO}}.sh

fix SCENARIO:
    ./scripts/fix-{{SCENARIO}}.sh
