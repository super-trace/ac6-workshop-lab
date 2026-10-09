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

srl_nodes := "spine-jfk leaf-jfk spine-iad leaf-iad"

# default: list recipes
default:
    @just --list

# Pull the lab images and build the SSH-enabled Linux clients.
# The private cEOS image is published for linux/amd64 Codespaces.
lab-setup:
    docker pull {{clab_image}}
    docker pull ghcr.io/nokia/srlinux:25.3.2
    docker pull ghcr.io/super-trace/ac6-workshop-lab/ceos:4.36.2F
    docker build -t client-ssh:latest lab/images/client-ssh
    @just install-key
    @just install-ssh-config
    @just install-stcli

# installs the shared lab keypair to ~/.ssh/ac6-workshop-key — split out of
# lab-setup because `stcli` needs it on whichever machine it runs from
# (your laptop), even in Codespace mode, where lab-setup itself runs
# inside the Codespace instead (see codespace-connect and the README's
# "Codespaces" section).
install-key:
    # lab/ssh_config points stcli's IdentityFile here — a fixed,
    # home-relative path so it resolves the same regardless of where this
    # repo is cloned. Not a secret: the matching public key is baked into
    # every node, and only ever used against these loopback-only lab
    # containers.
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
    # Every node gets a fresh host key on every deploy. lab/ssh_config points
    # stcli and ssh at a dedicated known_hosts file (not /dev/null — see its
    # comment for why); wiping it here is what keeps a redeploy from looking
    # like a man-in-the-middle to either of them.
    @rm -f ~/.ac6-workshop-known-hosts
    {{clab_run}} deploy -t topology.clab.yml
    @echo ""
    @just lab-status
    # An SR Linux node's startup-config
    # has intermittently, silently failed to apply (root cause not fully
    # pinned down). heal-fabric.sh checks all six and fixes defensively;
    # it's a fast no-op when nothing's wrong, which is the common case.
    @sleep 10
    @./scripts/heal-fabric.sh
    @./scripts/fix-mtu.sh

# tear down the lab
lab-down:
    {{clab_run}} destroy -t topology.clab.yml
    @rm -f ~/.ac6-workshop-known-hosts

# table of running lab nodes + their IPs
lab-status:
    {{clab_run}} inspect -t topology.clab.yml

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
      spine-jfk|leaf-jfk|spine-iad|leaf-iad)
        docker exec -it clab-ac6-workshop-{{NODE}} sr_cli ;;
      rtr-phl|rtr-ewr)
        docker exec -it clab-ac6-workshop-{{NODE}} Cli -p 15 ;;
      client-jfk|client-iad)
        docker exec -it clab-ac6-workshop-{{NODE}} sh ;;
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

# break/fix a named scenario: just break bgp | mtu | ospf | wan
break SCENARIO:
    ./scripts/break-{{SCENARIO}}.sh

fix SCENARIO:
    ./scripts/fix-{{SCENARIO}}.sh
