# containerlab runs in a sidecar container; scripts/clab.sh explains how.
clab_image := "ghcr.io/srl-labs/clab:latest"
clab_run := "CLAB_IMAGE=" + clab_image + " ./scripts/clab.sh"

# ANSI colors for the recipe intros; raw strings, so printf expands the
# escapes. Vendors keep one color each: SR Linux blue, cEOS magenta, Linux
# green. The banners' own colors live in scripts/banner.sh.
reset := '\033[0m'
bold := '\033[1m'
yellow := '\033[1;33m'
green := '\033[1;32m'
red := '\033[1;31m'
note := '\033[92m'
srl := '\033[94m'
ceos := '\033[95m'
linux := '\033[92m'

[private]
default:
    @just --list --unsorted

# deploy every node fresh from lab/configs/ (~2–5 minutes)
[group('lab')]
lab-up:
    @./scripts/banner.sh intro "just lab-up" \
        "Welcome to the workshop! This command will provision multiple" \
        "containers to simulate a network. Expect this to take ~2–5 minutes."
    @printf '\n'
    @# Every node gets a fresh host key on every deploy. lab/ssh_config points
    @# stcli and ssh at a dedicated known_hosts file (not /dev/null — see its
    @# comment for why); wiping it here is what keeps a redeploy from looking
    @# like a man-in-the-middle to either of them.
    @rm -f ~/.ac6-workshop-known-hosts
    @# --reconfigure: start every node from lab/configs/. Without it cEOS boots
    @# from the config it saved in its lab directory last time, so config
    @# changes (and any scenario left broken) silently survive a redeploy.
    @{{clab_run}} deploy --reconfigure -t topology.clab.yml
    @echo ""
    @just lab-status
    @# containerlab applies each SR Linux startup-config as one big commit,
    @# which intermittently and silently applies only part of it.
    @# heal-fabric.sh re-applies every SR Linux config in two smaller commits,
    @# every time; see the script for how that was pinned down.
    @sleep 10
    @./scripts/heal-fabric.sh
    @./scripts/fix-mtu.sh
    @printf '\n'
    @./scripts/banner.sh green "LAB IS UP"
    @printf '\n'
    @printf '    {{bold}}JFK{{reset}}  sw-jfk {{srl}}(Nokia SR Linux){{reset}} + client-jfk {{linux}}(Linux){{reset}}\n'
    @printf '    {{bold}}IAD{{reset}}  sw-iad {{ceos}}(Arista cEOS){{reset}} + client-iad {{linux}}(Linux){{reset}}\n'
    @printf '    {{bold}}WAN{{reset}}  rtr-phl {{ceos}}(Arista cEOS){{reset}} + rtr-ewr {{srl}}(Nokia SR Linux){{reset}}, eBGP to each site\n\n'
    @printf '    Every node booted fresh from lab/configs/, so changes made inside a node\n'
    @printf '    last until the next lab-up. The SR Linux configs were re-applied in two\n'
    @printf '    smaller commits (one big commit sometimes partly fails), and client-jfk\n'
    @printf '    is back at MTU 1500.\n'
    @printf '\n{{note}}Expected warnings: containerlab may print these WARN lines for the SR Linux\n'
    @printf 'nodes (sw-jfk, rtr-ewr). They are harmless; ignore them.{{reset}}\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to open /etc/hosts file for srl node <node>: ...\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to populate hosts for node "<node>": ...\n'
    @printf '\n    Next: {{green}}just verify{{reset}}\n'

# check BGP, routing, reachability, MTU and SSH on every node (~20 seconds)
[group('lab')]
verify:
    @./scripts/banner.sh intro "just verify" \
        "This command checks that the lab network is healthy before you" \
        "start breaking things. Expect this to take ~20 seconds."
    @printf '\n'
    @just _verify-checks
    @printf '\n'
    @printf '    Ends with {{green}}LAB IS VERIFIED{{reset}}, or {{red}}LAB VERIFICATION FAILED{{reset}} with each failed\n'
    @printf '    check printed in red above it.\n\n'
    @sleep 3
    @# The list repeats after the result, failed or not; the exit status is
    @# kept so a failed verify still fails.
    @./scripts/verify.sh; status=$?; printf '\n'; just _verify-checks; exit $status

# The five checks verify runs, printed before and after them.
[private]
_verify-checks:
    @printf '    {{yellow}}1. eBGP{{reset}}          switches and WAN routers have every session Established\n'
    @printf '    {{yellow}}2. Routing{{reset}}       sw-iad learns 192.168.11.0/24 over both WAN paths\n'
    @printf '    {{yellow}}3. Reachability{{reset}}  client-jfk pings client-iad end to end\n'
    @printf '    {{yellow}}4. MTU{{reset}}           200 B and 3000 B pings from client-jfk to its gateway\n'
    @printf '    {{yellow}}5. SSH{{reset}}           every node answers on its lab alias, as stcli connects\n'

# list the running lab nodes and their addresses
[group('lab')]
lab-status:
    @{{clab_run}} inspect -t topology.clab.yml

# open a node's own CLI: sw-jfk, sw-iad, rtr-phl, rtr-ewr, client-jfk, client-iad
[group('lab')]
lab-cli NODE='sw-jfk':
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{NODE}}" in
      sw-jfk|rtr-ewr)
        docker exec -it clab-ac6-workshop-{{NODE}} sr_cli ;;
      sw-iad|rtr-phl)
        docker exec -it clab-ac6-workshop-{{NODE}} Cli -p 15 ;;
      client-jfk|client-iad)
        docker exec -it clab-ac6-workshop-{{NODE}} sh ;;
      *) echo "unknown node {{NODE}}" >&2; exit 1 ;;
    esac

# tear down the lab
[group('lab')]
lab-down:
    @{{clab_run}} destroy -t topology.clab.yml
    @rm -f ~/.ac6-workshop-known-hosts
    @printf '\n'
    @./scripts/banner.sh red "LAB IS DOWN"

# break a scenario: peer, prefix, filter, mtu or icmp
[group('scenarios')]
break SCENARIO:
    ./scripts/break-{{SCENARIO}}.sh

# undo a scenario: peer, prefix, filter, mtu or icmp
[group('scenarios')]
fix SCENARIO:
    ./scripts/fix-{{SCENARIO}}.sh

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

# pull the lab images, build the client image, install SSH config and stcli
[group('setup')]
lab-setup:
    @# The private cEOS image supports native AMD64 and ARM64 Docker engines.
    docker pull {{clab_image}}
    docker pull ghcr.io/nokia/srlinux:25.3.2
    docker pull ghcr.io/super-trace/ac6-workshop-lab/ceos:4.36.2F
    docker build --progress=plain -t client-ssh:latest lab/images/client-ssh
    ./scripts/install-ssh.sh
    ./scripts/install-stcli.sh

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
