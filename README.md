# AC6 workshop lab — "Old Protocol, New Brain"

An eight-node network lab for troubleshooting BGP, MTU, OSPF, and WAN
faults with `stcli`. Run the lab in GitHub Codespaces or locally with Docker.

## Contents

- [Prepare your computer](#prepare-your-computer)
- [Codespaces](#codespaces)
- [Codespace lab + local stcli](#codespace-lab--local-stcli)
- [Local Docker lab](#local-docker-lab)
- [SSH setup](#ssh-setup)
- [Lab commands](#lab-commands)
- [Teardown](#teardown)
- [Topology](#topology)
- [Scenarios](#scenarios)
- [Troubleshooting](#troubleshooting)

Choose a setup path:

| Lab location | `stcli` location | Authentication |
|---|---|---|
| [Codespaces](#codespaces) | Codespace | Local login, then paste a token |
| [Codespaces + local stcli](#codespace-lab--local-stcli) | Your computer | Local browser login |
| [Local Docker](#local-docker-lab) | Your computer | Local browser login |

## Prepare your computer

All paths need Git, SSH, a local `stcli` binary, and a browser for login.
Codespaces also needs GitHub CLI (`gh`); its token helper needs `jq`.

**macOS**, with Homebrew already installed:

```sh
brew install gh jq
```

**Linux (Ubuntu/Debian desktop):**

```sh
sudo apt update
sudo apt install git gh jq openssh-client xdg-utils
```

For other distributions, install the equivalent packages. If your packaged
`gh` is too old for Codespaces, use the
[official GitHub CLI installation instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md).
Local login needs a desktop browser that `xdg-open` can launch; a headless
Linux SSH session has the same login limitation as the Codespace.

**Windows: use WSL2 with Ubuntu.** If needed, install it from an
administrator PowerShell terminal with `wsl --install`, restart when
prompted, and open Ubuntu. Follow Microsoft's
[WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install).
Run all remaining local commands in the Ubuntu/WSL terminal, not PowerShell.
Keep the repository under your Linux home directory (for example `~/labs`)
so Linux SSH permissions work normally.

Install the Ubuntu/Debian packages above. For login in your Windows browser,
install `wslu` using its
[Ubuntu installation instructions](https://wslutiliti.es/wslu/install.html#ubuntu), then:

```sh
export BROWSER=wslview
command -v xdg-open
command -v wslview
xdg-open https://github.com
```

Check that the Windows browser opens. If sign-in completes but the CLI
waits for its callback, check [WSL localhost networking](https://learn.microsoft.com/en-us/windows/wsl/networking).
The WSL login flow has not yet been tested end to end in this workshop.

**For Codespaces:** authenticate GitHub CLI using SSH:

```sh
gh auth login --git-protocol ssh
```

Use your GitHub SSH key for repository access. If you haven't configured
one, follow [GitHub's SSH setup guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh).
Clone the workshop repository and enter its folder:

```sh
git clone git@github.com:super-trace/ac6-workshop-lab.git
cd ac6-workshop-lab
```

If you already have the repository, enter its folder and run `git pull
--ff-only` instead. Run the remaining local commands from that folder.

If `stcli` is already installed on your computer, skip the build below. Otherwise,
install Go 1.26 or newer ([official installation guide](https://go.dev/doc/install))
and build a local binary (requires access to the
`super-trace/stcli` repository):

```sh
# macOS: brew install go
# Linux/WSL: install Go 1.26+ using the guide above, then check go version.
git clone git@github.com:super-trace/stcli.git stcli-source
(cd stcli-source && go build -o ../stcli-local .) && echo "Built ./stcli-local"
```

This builds for the operating system and architecture of your terminal
(macOS or Linux/WSL). The bundled `lab/bin/stcli-linux-amd64` cannot run on
macOS or ARM Linux. On x86-64 Linux/WSL, you can use that bundled binary
instead of installing Go and building from source:

```sh
# Only if uname -m prints x86_64:
uname -m
cp lab/bin/stcli-linux-amd64 stcli-local
chmod +x stcli-local
```

## Codespaces

This path runs both the lab and `stcli` inside the Codespace.

### 1. Create the environment

From the workshop folder on your computer:

```sh
gh codespace create --repo super-trace/ac6-workshop-lab --branch main \
  --machine standardLinux32gb --display-name "AC6 workshop" --status
```

Use **4 cores / 16 GB RAM**, the tested configuration. Automatic setup
installs the images, `just`, `stcli`, and SSH configuration. Wait for it to
finish. Codespaces usage counts against your GitHub allowance.

You can also create it on GitHub via **Code → Codespaces → New with
options**, selecting the same machine size and `main` branch.

### 2. Log in locally

**Temporary workaround:** `stcli login` currently fails inside the
Codespace because its browser launcher is unavailable. Run the helper on
your local computer to complete browser login and print the saved access token:

```sh
# If you built the local binary in the preparation section:
./scripts/login-token.sh ./stcli-local
# Or, if stcli is already installed on PATH:
./scripts/login-token.sh
```

Run one command. Expect `Signed in.` and the token on its own line. Keep
this terminal open; copy the token when the Codespace prompt is ready.

### 3. Start and verify the lab

From your local terminal (no local `just` installation needed):

```sh
gh codespace ssh --repo super-trace/ac6-workshop-lab
```

Choose the workshop Codespace if prompted. **The following commands run
inside the Codespace:**

```sh
cd /workspaces/ac6-workshop-lab
command -v just
command -v stcli
docker info >/dev/null && echo "Docker ready"
just lab-up
```

The command checks should show installed paths. Wait for `just lab-up`
to finish configuring all four SR Linux nodes before continuing.

```sh
just verify
```

Check the [healthy baseline](#healthy-baseline) before connecting.

### 4. Connect with stcli

Inside the Codespace's Bash shell:

```sh
read -rsp 'Paste access token: ' STCLI_TOKEN
```

Once that prompt is waiting, return to your local terminal and copy only
the token line printed by the helper. Paste it into the Codespace prompt
and press Enter. It will not echo.
Then run:

```sh
echo
export STCLI_TOKEN
stcli spine-jfk
```

Use any device in [Node roles](#node-roles). `STCLI_TOKEN` is set only in
this shell and cannot refresh itself. Enter it again in new terminals;
rerun local login when it expires. Keep the token and scrollback private.

For native access without `stcli`, use `just lab-cli spine-jfk`.
For `stcli` on your computer instead, see
[Codespace lab + local stcli](#codespace-lab--local-stcli).

### 5. Finish and remove the Codespace

Exit `stcli`. Inside the Codespace, from the workshop folder:

```sh
just lab-down
unset STCLI_TOKEN
exit
```

Back in your **local terminal**, stop any `just codespace-connect` tunnel
with Ctrl-C. Find the Codespace name and delete that environment:

```sh
gh codespace list
gh codespace delete --codespace <codespace-name>
```

For local port forwarding, also run `just cleanup-ssh` in the local
workshop folder. Deleting the Codespace removes its own SSH files.

Replace `<codespace-name>` with the workshop environment's name from the
list. Deletion removes its files and saved lab state; save any work you
want to keep first. `just lab-down` alone does not remove the Codespace.

To keep the environment for another session, stop it instead of deleting:

```sh
gh codespace stop --codespace <codespace-name>
```

## Codespace lab + local stcli

Run the lab in Codespaces and `stcli` locally. Complete
[preparation](#prepare-your-computer), then Codespaces steps 1 and 3 above.
Skip the token steps: local `stcli` handles login and refresh.

On your computer, install `just` (`brew install just` on macOS; see the
[installation guide](https://github.com/casey/just#installation) for Linux/WSL)
and `lsof` (`sudo apt install lsof` on Ubuntu/Debian). For WSL, run both the
tunnel and local `stcli` in WSL terminals. From the workshop folder,
stop any local lab with `just lab-down` first if it is running. Then
start the tunnel and leave this terminal running:

```sh
just codespace-connect
# If you have multiple workshop Codespaces:
# gh codespace list
# just codespace-connect <codespace-name>
```

The tunnel recipe installs your lab SSH key and aliases automatically.
In a second local terminal, enter the workshop folder and check access:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=10 spine-jfk 'echo ok'
```

Expect `ok` after the device banner. Then log in and connect:

```sh
./stcli-local login
./stcli-local spine-jfk
# Use stcli instead of ./stcli-local if installed on PATH.
```

Keep the tunnel running; Ctrl-C stops it. Run `just break`, `just fix`, and
other lab commands inside the Codespace. The tunnel installs local SSH
aliases and forwards ports 2401–2408; it does not launch `stcli`.

If several workshop Codespaces exist, pass the name from `gh codespace
list`. Occupied local ports cause the tunnel to fail. Use this recipe
instead of browser port URLs or VS Code forwarding to preserve the SSH
port mappings. For host-key errors after redeployment, see
[Troubleshooting](#troubleshooting). When finished, follow
[Codespace teardown](#5-finish-and-remove-the-codespace).

## Local Docker lab

The lab images support **Linux AMD64 and ARM64**, including Apple Silicon.
`just lab-setup` builds the client and FRR SSH images for your Docker
engine's native architecture. FRR uses the pinned multi-platform image
`quay.io/frrouting/frr:10.7.1`.

Complete [preparation](#prepare-your-computer), then install:

- **Docker:** Docker Desktop or OrbStack on macOS, Docker Engine on Linux,
  or Docker Desktop with Ubuntu/WSL2 integration on Windows.
- **just:** `brew install just` on macOS, or follow the
  [Linux/WSL installation guide](https://github.com/casey/just#installation).

Use a Docker VM with enough memory for four SR Linux nodes; 16 GB is the
tested Codespace allocation. Stop any Codespace port-forwarding tunnel so
local ports 2401–2408 are free.

From the workshop repository folder on your own machine:

```sh
docker info >/dev/null && echo "Docker ready"
just lab-setup
just lab-up
just verify
```

Wait for `just lab-up` to finish before verifying. Check the
[healthy baseline](#healthy-baseline).

Setup installs the lab SSH key and aliases. Use your local binary to connect:

```sh
./stcli-local login
./stcli-local spine-jfk
# If stcli is installed on PATH, use stcli instead of ./stcli-local.
```

## SSH setup

SSH setup is automatic on the machine running `stcli`:

| Connection path | What installs SSH configuration | Where it is installed |
|---|---|---|
| `stcli` inside Codespaces | Automatic Codespace setup (`just lab-setup`) | Inside the Codespace |
| Local `stcli`, Codespace lab | `just codespace-connect` | Your local computer |
| Local `stcli`, local Docker lab | `just lab-setup` | Your local computer |

Setup installs these owner-only files:

- Key: `~/.ssh/ac6-workshop-key`
- Aliases: `~/.ssh/ac6-workshop-ssh-config.conf`

It prepends an `Include` to `~/.ssh/config`, preserving existing entries
and saving the original as `~/.ssh/config.bak`.

To refresh SSH setup, run from that machine's workshop folder:

```sh
just install-key
just install-ssh-config
```

Check an alias and then test connectivity while the lab is running (and,
for the forwarded path, while the tunnel is open):

```sh
ssh -G spine-jfk
ssh -o BatchMode=yes -o ConnectTimeout=10 spine-jfk 'echo ok'
```

Expect `hostname 127.0.0.1`, `port 2401`, `user stcli`, and the lab
`identityfile`, followed by a banner and `ok` without a password.
For WSL, configure SSH inside WSL, not in Windows.

## Lab commands

Run these where Docker and the lab are running: inside the Codespace or on
your local computer for the Docker option.

| Command | Purpose |
|---|---|
| `just lab-up` | Deploy and configure the lab |
| `just lab-status` | List containers and management addresses |
| `just verify` | Check routing, pings, and SSH |
| `just lab-cli <node>` | Open a native device CLI |
| `just break <scenario>` | Inject a fault: `bgp`, `mtu`, `ospf`, or `wan` |
| `just fix <scenario>` | Restore that scenario's configuration |
| `just lab-down` | Tear down the lab |
| `just cleanup-ssh` | Remove workshop SSH setup on the local CLI machine |

Use one device per `stcli` session; open another terminal for another device.

### Healthy baseline

Read the output of `just verify` and check:

- OSPF neighbors are `full` at both sites.
- Each spine and WAN router has three established BGP peers.
- IAD sees the JFK prefix `192.168.11.0/24`.
- End-to-end, small-packet, and large-packet pings succeed.
- SSH checks return `ok`.

The script masks some MTU/SSH failures and only prints protocol states;
exit code 0 alone is insufficient. If routing is still converging, wait a
few seconds and repeat.

## Teardown

Exit your `stcli` sessions first. If using local port forwarding, press
**Ctrl-C** in the terminal running `just codespace-connect`.

### Local Docker lab

From the local workshop folder:

```sh
just lab-down
```

This removes the lab containers and management network and clears the
local lab host-key file. Images, SSH configuration, and saved device
configuration remain available for the next run. For a clean reset, see
[Reset saved configuration](#reset-saved-configuration).

For Codespaces, follow [Finish and remove the Codespace](#5-finish-and-remove-the-codespace)
in the walkthrough above.

### Remove local SSH setup

After stopping the lab or port-forwarding tunnel, run this from the local
workshop folder if you no longer need the device aliases:

```sh
just cleanup-ssh
```

It removes the workshop `Include` from `~/.ssh/config`, the shared lab key,
the alias file, and the lab host-key file. Other SSH entries and edits are
preserved; the current config is backed up before changing it. It does not
restore the old setup backup. Rerun `just install-key` and
`just install-ssh-config` to use the lab again.

## Topology

Two independent sites (JFK, IAD), each a single-spine Clos — spine, one
leaf, one client — connected by a small WAN core of two FRR routers
(`rtr-phl`, `rtr-ewr`) that gives the sites two independent paths, plus a
direct link between the WAN routers for a third form of resilience.

![Routing topology: OSPF within each site, iBGP between spine and leaf loopbacks, and eBGP across the WAN](lab/diagrams/routing-topology.png)

SR Linux provides the spines and leaves; FRRouting provides the WAN
routers. The images are public and require no vendor license downloads.

### Routing

- Each site's OSPF area `0.0.0.0` carries the spine–leaf link and loopbacks.
- Spine and leaf peer iBGP over loopbacks in the site's AS.
- Each spine peers eBGP with both WAN routers. The WAN routers also peer
  eBGP with each other.
- The spine sets `next-hop-self` toward its leaf so WAN routes resolve
  through the spine's OSPF-reachable loopback.
- A spine export allow-list controls which local prefixes reach the WAN.
  The BGP scenario removes one entry from that list.

To update the routing image, see [diagram generation](lab/diagrams/README.md).
`just lab-diagram` generates the physical-link diagram;
`just lab-graph` provides a Graphviz view (requires `graphviz`).

### Node roles

| Node | Role | Kind | AS | SSH port |
|---|---|---|---|---|
| `spine-jfk` | JFK's only spine; OSPF + iBGP to `leaf-jfk`, eBGP to both WAN routers | SR Linux | 65010 | 2401 |
| `leaf-jfk` | JFK's only leaf; OSPF + iBGP to `spine-jfk`, customer LAN to `client-jfk` | SR Linux | 65010 | 2402 |
| `client-jfk` | JFK customer traffic source/sink | plain Linux | — | 2403 |
| `spine-iad` | IAD's only spine, mirrors `spine-jfk` | SR Linux | 65030 | 2404 |
| `leaf-iad` | IAD's only leaf, mirrors `leaf-jfk` | SR Linux | 65030 | 2405 |
| `client-iad` | IAD customer traffic source/sink | plain Linux | — | 2406 |
| `rtr-phl` | WAN router, path 1 | FRRouting | 65021 | 2407 |
| `rtr-ewr` | WAN router, path 2 | FRRouting | 65022 | 2408 |

All eight nodes accept `stcli` connections using the shared lab SSH key.
SR Linux aliases log in as `stcli`; Linux clients and FRR routers use
`root`. For manual password login, SR Linux uses `admin` / `NokiaSrl1!`,
and the Linux clients and FRR routers use `root` / `admin`.

## Scenarios

Start from a healthy lab and fix each fault before trying another.
Run `break` and `fix` where the lab runs; use `stcli` on the device you
want to investigate.

| Scenario | Segment | Break | Fix |
|---|---|---|---|
| BGP prefix advertisement | Guided | `just break bgp` | `just fix bgp` |
| MTU mismatch | Self-serve | `just break mtu` | `just fix mtu` |
| OSPF adjacency | Optional | `just break ospf` | `just fix ospf` |
| WAN path loss | Optional | `just break wan` | `just fix wan` |

### BGP: missing prefix

Removes `192.168.11.0/24` (the JFK client subnet) from `spine-jfk`'s export
allow-list. BGP sessions remain established, but `spine-iad` loses the
prefix. Diagnose and repair the advertisement on `spine-jfk`.

To inspect the route from IAD, run `just lab-cli spine-iad`, then:

```text
show network-instance default protocols bgp routes ipv4 prefix 192.168.11.0/24
```

### MTU: small packets work, large packets fail

Raises `client-jfk`'s `eth1` MTU to 9500 while its link to `leaf-jfk` uses
1500. Routing and adjacencies remain healthy. On `client-jfk`, compare:

```sh
ping -c 2 -s 200 192.168.11.1
ping -c 2 -s 3000 192.168.11.1
```

The small ping succeeds; the large ping fails with the fault active.
The fix returns the client MTU to 1500.

### OSPF: adjacency stuck at Two-Way

Removes the point-to-point interface-type setting on `leaf-jfk`'s fabric
link. Its adjacency to `spine-jfk` stays at `two-way`, disrupting the
loopback path used by iBGP and isolating the JFK client.

On `leaf-jfk`, inspect:

```text
show network-instance default protocols ospf neighbor
```

### WAN: reduced redundancy

Disables `spine-jfk`'s link to `rtr-phl`. That BGP session drops, while
traffic continues through `rtr-ewr`. Check both WAN BGP peers on
`spine-jfk`; a successful ping alone does not prove redundancy.

## Troubleshooting

### Login fails inside Codespaces

Use the local login/token helper or the local `stcli` port-forwarding
option above. `STCLI_TOKEN` cannot refresh itself; if authentication fails
after token expiry, obtain and enter a new token.

### SSH alias fails

On the machine running `stcli`, check `ssh -G spine-jfk` and rerun
`just install-key` and `just install-ssh-config` from the workshop folder.
For local `stcli` with a Codespace lab, keep `just codespace-connect`
running and check that ports 2401–2408 are free before starting it.

For a host-key mismatch after redeployment, clear the disposable
lab's host-key file on the machine running `stcli`:

```sh
rm -f ~/.ac6-workshop-known-hosts
```

### Lab starts but routing or interfaces fail

Wait until `just lab-up` finishes its configuration step, then inspect
`just verify`. `scripts/heal-fabric.sh` reapplies all four SR Linux configs
in two commits to handle incomplete startup configuration.

Check memory availability and `show system application` on SR Linux if
ports report `port-not-present` or forwarding fails. A stopped or failed
`xdp_lc_1` process can indicate memory pressure. Use the 16 GB Codespace
configuration above; a container being listed as running does not prove
its forwarding processes are healthy.

### Reset saved configuration

Containerlab retains device state under `lab/clab-ac6-workshop`.
For a clean reset, run the following **where the lab runs**, from the
workshop folder. This discards saved lab configuration:

```sh
just lab-down
rm -rf lab/clab-ac6-workshop
just lab-up
just verify
```

### Editing device configuration

- SR Linux BGP groups need an explicit import policy; the lab uses
  `accept-all`. Established sessions alone do not prove routes are accepted.
- FRR configurations use `no bgp ebgp-requires-policy`; preserve it unless
  you supply explicit inbound and outbound policies.
- SR Linux physical `mtu` and logical `ip-mtu` are separate settings.
  The workshop MTU fault is applied to the Linux client.
- WAN BGP connect-retry timers are set to five seconds for quick recovery.
- SR Linux key login uses the configured `stcli` account; the reserved
  `admin` account cannot take the lab's SSH key.

The bundled Codespace binary and its build provenance are documented in
[lab/bin/README.md](lab/bin/README.md). Automatic setup installs it at
`/usr/local/bin/stcli`; local users supply their own native binary.
