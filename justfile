# containerlab runs in a sidecar container; scripts/clab.sh explains how.
clab_image := "ghcr.io/srl-labs/clab:latest"
# SONiC's official virtual switch plus the lab login; scripts/sonic-image.sh builds it.
sonic_image := "ghcr.io/super-trace/ac6-workshop-lab/sonic-vs:202605"
# Optional, local-only MikroTik RouterOS CHR; scripts/mikrotik-image.sh builds it (never pushed).
mikrotik_image := "vrnetlab/mikrotik_routeros:7.25.1"
# Optional, local-only Juniper vJunos-switch; scripts/vjunos-image.sh builds it from Juniper's qcow2 (never pushed).
vjunos_image := "vrnetlab/juniper_vjunos-switch:25.2R1.9"
clab_run := "CLAB_IMAGE=" + clab_image + " ./scripts/clab.sh"

# ANSI colors for the recipe intros; raw strings, so printf expands the
# escapes. Vendors keep one color each: SR Linux blue, SONiC cyan. The banners' own colors live in scripts/banner.sh.
reset := '\033[0m'
bold := '\033[1m'
yellow := '\033[1;33m'
green := '\033[1;32m'
note := '\033[92m'
srl := '\033[94m'
sonic := '\033[96m'
ros := '\033[95m'
junos := '\033[32m'

[private]
default:
    @just --list --unsorted

# deploy both nodes fresh from lab/configs/, plus NetBox and the GitHub MCP proxy (~3 minutes); `lab-up mikrotik vjunos` adds optional RouterOS and Junos nodes (Linux with KVM)
[group('lab')]
lab-up *EXTRA:
    @./scripts/banner.sh intro "just lab-up" \
        "Welcome to the workshop! This command starts two network devices," \
        "one Nokia and one SONiC, plus NetBox." \
        "Expect this to take ~3 minutes."
    @printf '\n'
    @for x in {{EXTRA}}; do case "$x" in mikrotik|vjunos) ;; *) echo "unknown option $x (mikrotik, vjunos)" >&2; exit 1 ;; esac; done
    @# vjunos first: it fails fast without a downloaded image.
    @for x in vjunos mikrotik; do case " {{EXTRA}} " in *" $x "*) just "$x-ensure" || exit ;; esac; done
    @# Refresh the SSH aliases and key from this checkout, so a `git pull`
    @# that changes lab/ssh_config takes effect without rerunning lab-setup.
    @./scripts/install-ssh.sh >/dev/null
    @# The SONiC image: already here, else pulled from ghcr, else built here
    @# from SONiC's official build (once, about 3 minutes).
    @just sonic-ensure
    @# NetBox boots while containerlab deploys; netbox-up.sh waits for it below.
    @./scripts/netbox-up.sh --background
    @# Every node gets a fresh host key on every deploy. lab/ssh_config points
    @# stcli and ssh at a dedicated known_hosts file; wiping it here keeps a
    @# redeploy from looking like a man-in-the-middle to either of them.
    @rm -f ~/.ac6-workshop-known-hosts
    @# --reconfigure: start every node from scratch, so nothing saved inside
    @# a node during the workshop survives a redeploy.
    @# A filtered deploy leaves an optional node from an earlier run alive.
    @for x in mikrotik vjunos; do case " {{EXTRA}} " in *" $x "*) ;; *) docker rm -f "clab-ac6-workshop-$x" >/dev/null 2>&1 || true ;; esac; done
    @{{clab_run}} deploy --reconfigure -t topology.clab.yml --node-filter {{ replace(trim("nokia sonic " + EXTRA), " ", ",") }}
    @echo ""
    @just lab-status
    @# Waits for both devices, saves both baselines for the lab-reset-* recipes,
    @# and waits for SSH.
    @./scripts/lab-ready.sh
    @printf '\n'
    @./scripts/netbox-up.sh
    @printf '\n'
    @./scripts/banner.sh green "LAB IS UP"
    @printf '\n'
    @printf '    {{bold}}nokia{{reset}}  {{srl}}Nokia SR Linux{{reset}}  configured: BGP on ethernet-1/1, VLAN trunk on ethernet-1/2\n'
    @printf '    {{bold}}sonic{{reset}}  {{sonic}}SONiC{{reset}}           blank: Ethernet0 and Ethernet4 unconfigured\n'
    @case " {{EXTRA}} " in *" mikrotik "*) printf '    {{bold}}mikrotik{{reset}}  {{ros}}MikroTik RouterOS{{reset}}  blank: ether2 unconfigured\n' ;; esac
    @case " {{EXTRA}} " in *" vjunos "*) printf '    {{bold}}vjunos{{reset}}  {{junos}}Juniper vJunos-switch{{reset}}  blank: ge-0/0/0 unconfigured\n' ;; esac
    @printf '\n'
    @printf '    Links: nokia ethernet-1/1 <-> sonic Ethernet0 (BGP)\n'
    @printf '           nokia ethernet-1/2 <-> sonic Ethernet4 (layer 2 trunk)\n'
    @case " {{EXTRA}} " in *" mikrotik "*) printf '           nokia ethernet-1/3 <-> mikrotik ether2\n' ;; esac
    @case " {{EXTRA}} " in *" vjunos "*) printf '           nokia ethernet-1/4 <-> vjunos ge-0/0/0\n' ;; esac
    @printf '    NetBox: port 8000; GitHub MCP: http://localhost:8002/mcp/readonly\n'
    @printf '\n{{note}}Expected warnings: containerlab may print these WARN lines for nokia.\n'
    @printf 'They are harmless; ignore them.{{reset}}\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to open /etc/hosts file for srl node nokia: ...\n'
    @printf '    {{yellow}}WARN{{reset}} Unable to populate hosts for node "nokia": ...\n'
    @printf '\n    Next: {{green}}just lab-verify{{reset}}\n'

# check the baseline: nokia configured, sonic blank, links and SSH up, NetBox and MCP answering (~10 seconds)
[group('lab')]
lab-verify:
    @./scripts/banner.sh intro "just lab-verify" \
        "This command checks the lab baseline: nokia configured, sonic" \
        "blank, both links up, NetBox and GitHub's MCP server answering." \
        "Expect this to take ~10 seconds."
    @printf '\n'
    @./scripts/verify.sh

# Same as lab-verify, kept for older docs and muscle memory; hidden from --list.
[private]
verify: lab-verify

# list the running lab nodes and their addresses
[group('lab')]
lab-status:
    @{{clab_run}} inspect -t topology.clab.yml

# open a node's own CLI: nokia, sonic, mikrotik or vjunos
[group('lab')]
lab-cli NODE='nokia':
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{NODE}}" in
      nokia)  docker exec -it clab-ac6-workshop-nokia sr_cli ;;
      sonic)  docker exec -it -u oldprotocol -w /home/oldprotocol clab-ac6-workshop-sonic bash -l ;;
      mikrotik|vjunos) ssh {{NODE}} ;;
      *) echo "unknown node {{NODE}} (nokia, sonic, mikrotik or vjunos)" >&2; exit 1 ;;
    esac

# reset for anyone stuck: tear down the lab and NetBox (keeps NetBox's data), then lab-up
[group('lab')]
lab-down:
    @{{clab_run}} destroy -t topology.clab.yml
    @rm -f ~/.ac6-workshop-known-hosts
    @# Keep NetBox's volumes, so whatever was put into NetBox survives the
    @# reset. netbox-down deletes them.
    @docker compose -f lab/netbox/compose.yml down
    @printf '\n'
    @./scripts/banner.sh red "LAB IS DOWN"

# reset the lab in one step: lab-down, then lab-up (NetBox keeps its data)
[group('lab')]
lab-reset: lab-down lab-up

# put nokia back to its configured baseline (seconds; sonic and the links untouched)
[group('lab')]
lab-reset-nokia:
    @./scripts/reset-nokia.sh

# wipe sonic back to blank to run the exercises again (seconds; nokia untouched)
[group('lab')]
lab-reset-sonic:
    @./scripts/reset-sonic.sh

# put NetBox back as seeded, drift included, to run the NetBox exercise again (seconds)
[group('lab')]
lab-reset-netbox:
    @docker compose -f lab/netbox/compose.yml down -v
    @./scripts/netbox-up.sh

# check the BGP exercise: nokia <-> sonic session Established, routes installed
[group('exercises')]
check-bgp:
    @./scripts/check-bgp.sh

# check the standards audit: sonic's interface descriptions follow the team standard
[group('exercises')]
check-standards:
    @./scripts/check-standards.sh

# check the layer 2 exercise: sonic reaches nokia in VLANs 110, 120 and 130
[group('exercises')]
check-l2:
    @./scripts/check-l2.sh


# check the NetBox exercise: NetBox matches nokia where it was stale
[group('exercises')]
check-netbox:
    @./scripts/check-netbox.sh


# start NetBox on port 8000, seeded with nokia, and the GitHub MCP proxy (lab-up does this too)
[group('netbox')]
netbox-up:
    @./scripts/banner.sh intro "just netbox-up" \
        "Starting NetBox, the source of truth stcli exports device data to," \
        "and the GitHub MCP proxy. Expect ~2–3 minutes the first time, then a" \
        "few seconds."
    @printf '\n'
    @./scripts/netbox-up.sh

# stop NetBox and the GitHub MCP proxy and delete NetBox's data
[group('netbox')]
netbox-down:
    @docker compose -f lab/netbox/compose.yml down -v
    @printf '\n'
    @./scripts/banner.sh red "NETBOX IS DOWN"

# pull the lab images and install SSH config
[group('setup')]
lab-setup:
    docker pull {{clab_image}}
    docker pull ghcr.io/nokia/srlinux:25.3.2
    just sonic-ensure
    docker compose -f lab/netbox/compose.yml pull
    ./scripts/install-ssh.sh

# Use the local SONiC image if it matches this checkout, else pull it, else build it here.
[private]
sonic-ensure:
    #!/usr/bin/env bash
    set -euo pipefail
    want="$(./scripts/sonic-recipe.sh)"
    stamp() { docker image inspect --format '{{{{index .Config.Labels "ac6.recipe"}}' "{{sonic_image}}" 2>/dev/null || true; }
    [ "$(stamp)" = "$want" ] && exit 0
    if docker pull -q "{{sonic_image}}" >/dev/null 2>&1 && [ "$(stamp)" = "$want" ]; then exit 0; fi
    echo "Building the SONiC image from SONiC's official build (once per lab change, about 3 minutes)."
    ./scripts/sonic-image.sh "{{sonic_image}}"

# maintainers: build the SONiC image from SONiC's official build (add --push to publish it)
[group('setup')]
sonic-image *ARGS:
    ./scripts/sonic-image.sh "{{sonic_image}}" {{ARGS}}

# build the optional MikroTik RouterOS image locally (needs no KVM; about 2 minutes)
[group('setup')]
mikrotik-image:
    ./scripts/mikrotik-image.sh "{{mikrotik_image}}"

# build the optional vJunos-switch image locally from Juniper's qcow2 (needs no KVM; a few minutes)
[group('setup')]
vjunos-image QCOW2='':
    ./scripts/vjunos-image.sh "{{vjunos_image}}" "{{QCOW2}}"

# Optional nodes are QEMU VMs: they need KVM on an x86_64 host, which a Codespace and Docker on a Mac lack.
[private]
kvm-check NODE:
    #!/usr/bin/env bash
    set -euo pipefail
    docker run --rm --privileged alpine sh -c '[ "$(uname -m)" = x86_64 ] && test -e /dev/kvm' ||
        { echo "{{NODE}} needs /dev/kvm, which this Docker host lacks (Codespaces and Docker on a Mac have none); use a Linux x86_64 machine with KVM." >&2; exit 1; }

# Build the MikroTik image unless it's here.
[private]
mikrotik-ensure: (kvm-check "MikroTik")
    #!/usr/bin/env bash
    set -euo pipefail
    docker image inspect "{{mikrotik_image}}" >/dev/null 2>&1 && exit 0
    echo "Building the MikroTik image (once, about 2 minutes)."
    ./scripts/mikrotik-image.sh "{{mikrotik_image}}"

# Require the vJunos-switch image, which only you can build: Juniper's qcow2 needs a manual download.
[private]
vjunos-ensure: (kvm-check "vJunos-switch")
    #!/usr/bin/env bash
    set -euo pipefail
    docker image inspect "{{vjunos_image}}" >/dev/null 2>&1 && exit 0
    ./scripts/vjunos-image.sh "{{vjunos_image}}"

# remove the workshop's SSH config and key (undoes lab-setup's SSH step)
[group('setup')]
cleanup-ssh:
    ./scripts/cleanup-ssh.sh
