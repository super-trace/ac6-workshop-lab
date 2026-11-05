# containerlab runs in a sidecar container; scripts/clab.sh explains how.
clab_image := "ghcr.io/srl-labs/clab:latest"
clab_run := "CLAB_IMAGE=" + clab_image + " ./scripts/clab.sh"

# ANSI colors for the recipe intros; raw strings, so printf expands the
# escapes. Vendors keep one color each: SR Linux blue, cEOS magenta. The banners' own colors live in scripts/banner.sh.
reset := '\033[0m'
bold := '\033[1m'
yellow := '\033[1;33m'
green := '\033[1;32m'
note := '\033[92m'
srl := '\033[94m'
ceos := '\033[95m'

[private]
default:
    @just --list --unsorted

# deploy both nodes fresh from lab/configs/ (~2 minutes)
[group('lab')]
lab-up:
    @./scripts/banner.sh intro "just lab-up" \
        "Welcome to the workshop! This command starts two network devices," \
        "one Nokia and one Arista. Expect this to take ~2 minutes."
    @printf '\n'
    @# Every node gets a fresh host key on every deploy. lab/ssh_config points
    @# stcli and ssh at a dedicated known_hosts file; wiping it here keeps a
    @# redeploy from looking like a man-in-the-middle to either of them.
    @rm -f ~/.ac6-workshop-known-hosts
    @# --reconfigure: start every node from lab/configs/. Without it cEOS boots
    @# from the config it saved last time, so workshop changes survive.
    @{{clab_run}} deploy --reconfigure -t topology.clab.yml
    @echo ""
    @just lab-status
    @# containerlab applies the SR Linux startup-config as one big commit,
    @# which intermittently applies only part of it; heal-fabric.sh re-applies
    @# it in two smaller commits.
    @sleep 10
    @./scripts/heal-fabric.sh
    @./scripts/arista-baseline.sh
    @printf '\n'
    @./scripts/banner.sh green "LAB IS UP"
    @printf '\n'
    @printf '    {{bold}}nokia{{reset}}   {{srl}}Nokia SR Linux{{reset}}  configured: BGP on e1-1, VLAN trunk on e1-2\n'
    @printf '    {{bold}}arista{{reset}}  {{ceos}}Arista cEOS{{reset}}     blank: Ethernet1 and Ethernet2 unconfigured\n\n'
    @printf '    Links: nokia e1-1 <-> arista Ethernet1 (BGP)\n'
    @printf '           nokia e1-2 <-> arista Ethernet2 (layer 2 trunk)\n'
    @printf '\n{{note}}Expected warnings: containerlab may print these WARN lines for nokia.\n'
    @printf 'They are harmless; ignore them.{{reset}}\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to open /etc/hosts file for srl node nokia: ...\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to populate hosts for node "nokia": ...\n'
    @printf '\n    Next: {{green}}just verify{{reset}}\n'

# check the baseline: nokia configured, arista blank, links and SSH up (~10 seconds)
[group('lab')]
verify:
    @./scripts/banner.sh intro "just verify" \
        "This command checks the lab baseline: nokia configured, arista" \
        "blank, both links up. Expect this to take ~10 seconds."
    @printf '\n'
    @./scripts/verify.sh

# list the running lab nodes and their addresses
[group('lab')]
lab-status:
    @{{clab_run}} inspect -t topology.clab.yml

# open a node's own CLI: nokia or arista
[group('lab')]
lab-cli NODE='nokia':
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{NODE}}" in
      nokia)  docker exec -it clab-ac6-workshop-nokia sr_cli ;;
      arista) docker exec -it clab-ac6-workshop-arista Cli -p 15 ;;
      *) echo "unknown node {{NODE}} (nokia or arista)" >&2; exit 1 ;;
    esac

# tear down the lab
[group('lab')]
lab-down:
    @{{clab_run}} destroy -t topology.clab.yml
    @rm -f ~/.ac6-workshop-known-hosts
    @printf '\n'
    @./scripts/banner.sh red "LAB IS DOWN"

# check the BGP exercise: nokia <-> arista session Established
[group('exercises')]
check-bgp:
    @./scripts/check-bgp.sh

# check the layer 2 exercise: arista reaches nokia in VLANs 110, 120 and 130
[group('exercises')]
check-l2:
    @./scripts/check-l2.sh

# wipe arista back to blank to run the exercises again (seconds; nokia untouched)
[group('exercises')]
reset-arista:
    @./scripts/reset-arista.sh

# start an empty NetBox on port 8000 (~2–3 minutes the first time)
[group('netbox')]
netbox-up:
    @./scripts/banner.sh intro "just netbox-up" \
        "Starting NetBox, the source of truth stcli exports device data to." \
        "Expect ~2–3 minutes the first time, then a few seconds."
    @printf '\n'
    @./scripts/netbox-up.sh

# stop NetBox and delete its data
[group('netbox')]
netbox-down:
    @docker compose -f lab/netbox/compose.yml down -v
    @printf '\n'
    @./scripts/banner.sh red "NETBOX IS DOWN"

# pull the lab images and install SSH config
[group('setup')]
lab-setup:
    @# The private cEOS image supports native AMD64 and ARM64 Docker engines.
    docker pull {{clab_image}}
    docker pull ghcr.io/nokia/srlinux:25.3.2
    docker pull ghcr.io/super-trace/ac6-workshop-lab/ceos:4.36.2F
    ./scripts/install-ssh.sh

# remove the workshop's SSH config and key (undoes lab-setup's SSH step)
[group('setup')]
cleanup-ssh:
    ./scripts/cleanup-ssh.sh

# regenerate lab/topology.clab.png after a topology.clab.yml change
[group('setup')]
lab-diagram:
    @# Two steps: containerlab's own `graph --drawio` (via the clab-io-draw
    @# project) turns the topology into a .drawio file with real
    @# router/switch/host icons and a hierarchical layout (controlled by each
    @# node's `labels.graph-level`/`graph-icon` in topology.clab.yml);
    @# rlespinasse/drawio-desktop-headless then renders that to a static PNG,
    @# since GitHub doesn't render .drawio natively. Needs Docker only — no
    @# local drawio/graphviz install.
    {{clab_run}} graph --drawio -t topology.clab.yml
    docker run --rm -v "$(pwd)/lab":/data rlespinasse/drawio-desktop-headless \
        -x -f png --scale 2 -o /data/topology.clab.png /data/topology.clab.drawio
    @echo "Wrote lab/topology.clab.png and lab/topology.clab.drawio (editable at app.diagrams.net)."
