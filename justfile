set positional-arguments

# containerlab via Docker-on-Docker (works on macOS + OrbStack, and on a
# Codespace's nested dockerd): a privileged sidecar shares the engine kernel
# and manages bridge interfaces.
#
# IMPORTANT: the project's lab dir is mounted at the SAME path inside the
# privileged container as on the host. containerlab generates per-node config
# files and asks the docker daemon to bind-mount them into the lab nodes; the
# daemon only sees host filesystem paths, so the paths must mirror.
#
# containerlab also writes each SR Linux node's hosts file through the
# daemon's own path, /var/lib/docker/containers/<id>/hosts; without that
# directory mounted, lab-up warns "Unable to populate hosts". Linux only: on
# macOS the daemon runs in a VM, so that host path isn't the daemon's.
clab_image := "ghcr.io/srl-labs/clab:latest"
clab_containers_mount := if os() == "linux" { "-v /var/lib/docker/containers:/var/lib/docker/containers " } else { "" }
#
# containerlab colors its log and tables only on a terminal, so give it one
# (-it) when just runs in one. -t alone isn't enough: containerlab queries the
# terminal's colors, and without -i the replies spill into the shell. The test
# checks stderr, not stdout: inside $(...), stdout is the substitution's pipe.
clab_run := "docker run --rm $([ -t 0 ] && [ -t 2 ] && echo -it) --privileged --pid=host --network=host -v /var/run/docker.sock:/var/run/docker.sock " + clab_containers_mount + "-v $(pwd)/lab:$(pwd)/lab -w $(pwd)/lab --entrypoint containerlab " + clab_image

srl_nodes := "spine-jfk leaf-jfk rtr-ewr"

# ANSI colors for the recipe intros and their green banner; raw strings, so printf expands the escapes.
# Vendors keep one color each: SR Linux blue, cEOS magenta, Linux green.
reset := '\033[0m'
bold := '\033[1m'
banner := '\033[32m'
banner_title := '\033[1;92m'
banner_text := '\033[92m'
yellow := '\033[1;33m'
green := '\033[1;32m'
red := '\033[1;31m'
srl := '\033[94m'
ceos := '\033[95m'
linux := '\033[92m'

# default: list recipes
default:
    @just --list

# Pull the lab images and build the SSH-enabled Linux clients.
# The private cEOS image supports native AMD64 and ARM64 Docker engines.
lab-setup:
    docker pull {{clab_image}}
    docker pull ghcr.io/nokia/srlinux:25.3.2
    docker pull ghcr.io/super-trace/ac6-workshop-lab/ceos:4.36.2F
    docker build --progress=plain -t client-ssh:latest lab/images/client-ssh
    @just install-key
    @just install-ssh-config
    @just install-stcli

# installs the shared lab keypair to ~/.ssh/ac6-workshop-key — split out of
# lab-setup because `stcli` needs it on whichever machine it runs from
# (your laptop), even in Codespace mode, where lab-setup itself runs
# inside the Codespace instead (see codespace-connect and the README's
# "Codespaces" section).
install-key:
    @# lab/ssh_config points stcli's IdentityFile here — a fixed,
    @# home-relative path so it resolves the same regardless of where this
    @# repo is cloned. Not a secret: the matching public key is baked into
    @# every node, and only ever used against these loopback-only lab
    @# containers.
    @mkdir -p ~/.ssh
    @cp lab/ac6-workshop-key ~/.ssh/ac6-workshop-key
    @chmod 600 ~/.ssh/ac6-workshop-key

# wires lab/ssh_config into ~/.ssh/config via Include — idempotent, safe to
# re-run. Always prepended at the very top of the file, before any Host
# block: OpenSSH silently treats an Include as "parse only" (read, never
# applied) if any Host block precedes it anywhere earlier in the file —
# confirmed directly debugging this lab against a Codespace, see README's
# "Codespaces details". A naive append would eventually land after some
# Host block the user adds later and quietly stop working with no error.
#
# Includes a private copy in ~/.ssh/, not the repo file directly: OpenSSH
# refuses to read an Include'd file that's writable by anyone but its
# owner, and a Codespace's /workspaces mount makes the whole repo checkout
# world-writable (-rw-rw-rw-) regardless of what's committed — confirmed
# live ("Bad owner or permissions on .../lab/ssh_config"). The copy is
# re-synced on every run, so a lab/ssh_config change still needs re-running
# this to take effect — not automatic the way Including the live file
# would have been, but that only worked on a normal filesystem anyway.
install-ssh-config:
    #!/usr/bin/env bash
    set -euo pipefail
    staged="$HOME/.ssh/ac6-workshop-ssh-config.conf"
    config="$HOME/.ssh/config"
    line="Include ${staged}"

    mkdir -p "$HOME/.ssh"
    cp lab/ssh_config "$staged"
    chmod 600 "$staged"

    touch "$config"
    chmod 600 "$config"

    if grep -qF "$line" "$config"; then
        echo "~/.ssh/config already includes ${staged} (just refreshed its contents)"
        exit 0
    fi

    cp "$config" "${config}.bak"
    { echo "$line"; echo; cat "$config"; } > "${config}.new"
    mv "${config}.new" "$config"
    echo "Added to the top of ~/.ssh/config: ${line}"
    echo "(previous version backed up to ${config}.bak)"

# removes only workshop SSH configuration and keys; run after stopping the lab/tunnel.
cleanup-ssh:
    bash ./scripts/cleanup-ssh.sh

# installs stcli itself into /usr/local/bin — but only inside a Codespace
# ($CODESPACES, the standard env var every Codespace sets). Without that
# guard this would be unsafe to call unconditionally from lab-setup: a
# local-mode user on their own Mac/Linux machine likely already has a real
# stcli there, and this committed binary is Linux-only (see lab/bin/
# README.md — it's a placeholder for a real release download, not the
# long-term plan). The guard is what makes "just works, no extra step"
# possible for Codespace mode without risking a local install.
install-stcli:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "${CODESPACES:-}" != "true" ]; then
        echo "not inside a Codespace — not installing the Linux-only stcli binary here"
        echo "(install/build stcli for this machine yourself)"
        exit 0
    fi
    sudo cp lab/bin/stcli-linux-amd64 /usr/local/bin/stcli
    sudo chmod +x /usr/local/bin/stcli
    echo "Installed stcli to /usr/local/bin/stcli"

# bring up the lab (creates the ac6 mgmt network)
lab-up:
    @printf '{{banner}}╔══════════════════════════════════════════════════════════════════════════╗{{reset}}\n'
    @printf '{{banner}}║{{reset}}                                                                          {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}   {{banner_title}}AC6 WORKSHOP LAB{{reset}}                                         {{banner_text}}just lab-up{{reset}}   {{banner}}║{{reset}}\n'
    @printf '{{banner}}╟──────────────────────────────────────────────────────────────────────────╢{{reset}}\n'
    @printf '{{banner}}║{{reset}}                                                                          {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}   {{banner_text}}Welcome to the workshop! This command will provision multiple{{reset}}          {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}   {{banner_text}}containers to simulate a network. Expect this to take ~2–5 minutes.{{reset}}    {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}                                                                          {{banner}}║{{reset}}\n'
    @printf '{{banner}}╚══════════════════════════════════════════════════════════════════════════╝{{reset}}\n'
    @printf '\n'
    @printf '    {{bold}}JFK{{reset}}  spine-jfk, leaf-jfk {{srl}}(Nokia SR Linux){{reset}} + client-jfk {{linux}}(Linux){{reset}}\n'
    @printf '    {{bold}}IAD{{reset}}  spine-iad, leaf-iad {{ceos}}(Arista cEOS){{reset}} + client-iad {{linux}}(Linux){{reset}}\n'
    @printf '    {{bold}}WAN{{reset}}  rtr-phl {{ceos}}(Arista cEOS){{reset}} + rtr-ewr {{srl}}(Nokia SR Linux){{reset}}, eBGP to each site\n\n'
    @printf '    Every node boots fresh from lab/configs/; changes made inside a node are\n'
    @printf '    discarded. Afterwards it lists the nodes, re-applies the SR Linux\n'
    @printf '    configs in two smaller commits (one big commit sometimes partly fails),\n'
    @printf '    and sets client-jfk MTU back to 1500.\n'
    @printf '    Next: {{green}}just verify{{reset}}\n\n'
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
    @# An SR Linux node's startup-config
    @# has intermittently, silently failed to apply (root cause not fully
    @# pinned down). heal-fabric.sh checks all SR Linux nodes and fixes defensively;
    @# it's a fast no-op when nothing's wrong, which is the common case.
    @sleep 10
    @./scripts/heal-fabric.sh
    @./scripts/fix-mtu.sh
    @printf '\n\033[1;32m╔══════════════════════════════════════════════════════════════════════════╗\n║                                                                          ║\n║                                LAB IS UP                                 ║\n║                                                                          ║\n╚══════════════════════════════════════════════════════════════════════════╝\033[0m\n'
    @printf '\n{{banner_text}}Expected warnings: containerlab may print these WARN lines for the SR Linux\n'
    @printf 'nodes (spine-jfk, leaf-jfk, rtr-ewr). They are harmless; ignore them.{{reset}}\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to open /etc/hosts file for srl node <node>: ...\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to populate hosts for node "<node>": ...\n'

# tear down the lab
lab-down:
    @{{clab_run}} destroy -t topology.clab.yml
    @printf '\n{{red}}╔══════════════════════════════════════════════════════════════════════════╗\n║                                                                          ║\n║                               LAB IS DOWN                                ║\n║                                                                          ║\n╚══════════════════════════════════════════════════════════════════════════╝{{reset}}\n'
    @rm -f ~/.ac6-workshop-known-hosts

# table of running lab nodes + their IPs
lab-status:
    @{{clab_run}} inspect -t topology.clab.yml

# resolves which codespace to use: {{CODESPACE}} if given, otherwise the
# one codespace on this repo if there's exactly one. Echoes the name on
# stdout; errors (ambiguous or none found) go to stderr so `name="$(just
# _codespace-name ...)"` in another recipe doesn't capture them. Prefixed
# with _ by just's own convention for a helper recipe, not a top-level one.
_codespace-name CODESPACE='':
    #!/usr/bin/env bash
    set -euo pipefail
    name="{{CODESPACE}}"
    if [ -z "$name" ]; then
        matches="$(gh codespace list --json name,repository \
            -q '.[] | select(.repository=="super-trace/ac6-workshop-lab") | .name')"
        count="$(echo "$matches" | grep -c . || true)"
        if [ "$count" -eq 0 ]; then
            echo "no codespace found for super-trace/ac6-workshop-lab — create one first" >&2
            exit 1
        elif [ "$count" -gt 1 ]; then
            echo "more than one codespace found; pass one explicitly:" >&2
            echo "$matches" >&2
            exit 1
        fi
        name="$matches"
    fi
    echo "$name"

# the primary way to work the Codespace-hosted lab: just codespace-ssh
# [name] drops you into a real shell inside it, from your own terminal —
# everything (lab-up, stcli itself) then runs there, in that one shell. No
# ports, no tunnels: see codespace-connect below for the alternate,
# run-stcli-locally-instead path.
codespace-ssh CODESPACE='':
    #!/usr/bin/env bash
    set -euo pipefail
    name="$(just _codespace-name {{CODESPACE}})"
    exec gh codespace ssh -c "$name"

# alternate/advanced path: run stcli on your own machine against a
# Codespace-hosted lab, bridged by a port forward — just codespace-connect
# [name]. Local and Codespace-hosted are mutually exclusive on one machine
# this way — both use the same canonical ports 2401-2408 via the same
# lab/ssh_config aliases, which is what lets `stcli spine-jfk` etc. work
# identically either way, but only if whichever one isn't active right now
# isn't holding those ports. Run `just lab-down` first if you've been
# running the lab locally. The primary path (just codespace-ssh, above)
# doesn't have this limitation at all, since nothing is forwarded.
#
# Deliberately gh codespace ports forward, not VS Code's own forwarding:
# VS Code auto-offsets ports when something else holds them locally
# (confirmed firsthand — 2401-2408 silently became 2409-2416), which
# breaks lab/ssh_config's aliases with no clear error. This maps 1:1 or
# fails loudly, which is what you want from a script.
#
# Everything else — lab-setup, lab-up, lab-down, verify, break, fix,
# lab-cli — talks to Docker directly and only exists inside the Codespace,
# so those still need to run in the Codespace's own terminal. This recipe
# only gets stcli (and a human) there; it doesn't run the lab remotely.
codespace-connect CODESPACE='':
    #!/usr/bin/env bash
    set -euo pipefail
    name="$(just _codespace-name {{CODESPACE}})"

    for port in 2401 2402 2403 2404 2405 2406 2407 2408; do
        if lsof -iTCP:"$port" -sTCP:LISTEN -n -P >/dev/null 2>&1; then
            echo "port $port is already in use locally — if the local lab is up, run 'just lab-down' first" >&2
            exit 1
        fi
    done

    just install-key
    just install-ssh-config

    echo "Forwarding ${name}'s SSH ports to 127.0.0.1:2401-2408 — leave this running, Ctrl-C to stop."
    gh codespace ports forward \
        2401:2401 2402:2402 2403:2403 2404:2404 \
        2405:2405 2406:2406 2407:2407 2408:2408 \
        -c "$name"

# open a vendor CLI directly on a node: just lab-cli spine-jfk | leaf-jfk | ... | rtr-phl | client-jfk
lab-cli NODE='spine-jfk':
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{NODE}}" in
      spine-jfk|leaf-jfk|rtr-ewr)
        docker exec -it clab-ac6-workshop-{{NODE}} sr_cli ;;
      spine-iad|leaf-iad|rtr-phl)
        docker exec -it clab-ac6-workshop-{{NODE}} Cli -p 15 ;;
      client-jfk|client-iad)
        docker exec -it clab-ac6-workshop-{{NODE}} sh ;;
      *) echo "unknown node {{NODE}}" >&2; exit 1 ;;
    esac

# run the infra verification checks (OSPF + BGP + prefix reachability)
verify:
    @printf '{{banner}}╔══════════════════════════════════════════════════════════════════════════╗{{reset}}\n'
    @printf '{{banner}}║{{reset}}                                                                          {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}   {{banner_title}}AC6 WORKSHOP LAB{{reset}}                                         {{banner_text}}just verify{{reset}}   {{banner}}║{{reset}}\n'
    @printf '{{banner}}╟──────────────────────────────────────────────────────────────────────────╢{{reset}}\n'
    @printf '{{banner}}║{{reset}}                                                                          {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}   {{banner_text}}This command checks that the lab network is healthy before you{{reset}}         {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}   {{banner_text}}start breaking things. Expect this to take ~20 seconds.{{reset}}                {{banner}}║{{reset}}\n'
    @printf '{{banner}}║{{reset}}                                                                          {{banner}}║{{reset}}\n'
    @printf '{{banner}}╚══════════════════════════════════════════════════════════════════════════╝{{reset}}\n'
    @printf '\n'
    @printf '    {{yellow}}1. OSPF{{reset}}          each spine has a Full neighbor to its leaf\n'
    @printf '    {{yellow}}2. eBGP{{reset}}          spines and WAN routers have every session Established\n'
    @printf '    {{yellow}}3. Routing{{reset}}       spine-iad learns 192.168.11.0/24 over both WAN paths\n'
    @printf '    {{yellow}}4. Reachability{{reset}}  client-jfk pings client-iad end to end\n'
    @printf '    {{yellow}}5. MTU{{reset}}           200 B and 3000 B pings from client-jfk to its gateway\n'
    @printf '    {{yellow}}6. SSH{{reset}}           every node answers on its lab alias, as stcli connects\n\n'
    @printf '    Ends with {{green}}LAB IS VERIFIED{{reset}}, or {{red}}LAB VERIFICATION FAILED{{reset}} with each failed\n'
    @printf '    check printed in red above it.\n\n'
    @./scripts/verify.sh

# regenerate the physical-link diagram lab/topology.clab.png —
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

# break/fix a named scenario: just break path | bgp | mtu | ospf | wan
break SCENARIO:
    ./scripts/break-{{SCENARIO}}.sh

fix SCENARIO:
    ./scripts/fix-{{SCENARIO}}.sh
