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
    # See README's "Known quirks" section: core1's startup-config has
    # intermittently, silently failed to apply (root cause not fully pinned
    # down). heal-core1.sh detects and fixes that defensively; it's a fast
    # no-op when nothing's wrong, which is the common case.
    @sleep 10
    @./scripts/heal-core1.sh

# tear down the lab
lab-down:
    {{clab_run}} destroy -t topology.clab.yml

# table of running lab nodes + their IPs
lab-status:
    {{clab_run}} inspect -t topology.clab.yml

# open a vendor CLI directly on a node: just lab-cli edge1 | core1 | isp1 | host1
lab-cli NODE='edge1':
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{NODE}}" in
      edge1|core1) docker exec -it clab-ac6-workshop-{{NODE}} sr_cli ;;
      isp1)        docker exec -it clab-ac6-workshop-isp1 vtysh ;;
      host1)       docker exec -it clab-ac6-workshop-host1 sh ;;
      *) echo "unknown node {{NODE}}" >&2; exit 1 ;;
    esac

# run the infra verification checks (OSPF + BGP + prefix reachability)
verify:
    ./scripts/verify.sh

# break/fix a named scenario: just break bgp | mtu | ospf
break SCENARIO:
    ./scripts/break-{{SCENARIO}}.sh

fix SCENARIO:
    ./scripts/fix-{{SCENARIO}}.sh
