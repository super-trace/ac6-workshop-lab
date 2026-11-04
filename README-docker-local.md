# Run the workshop locally with Docker

The same six-node topology runs locally: SR Linux at JFK (`sw-jfk`) and
`rtr-ewr`, cEOS at IAD (`sw-iad`) and `rtr-phl`, and Linux clients at both
sites.

![Routing topology](lab/diagrams/routing-topology.png)

## Prepare

Install Git, Docker, `just`, GitHub CLI (`gh`), and a native `stcli` binary.
Allocate **4 CPU cores / 16 GB RAM** to the lab machine. On macOS, use
OrbStack and allocate these resources to its Linux VM. On Linux, use
Docker Engine on a machine with these resources. The cEOS package
supports both AMD64 and ARM64; Docker selects your native architecture.

Authenticate GitHub CLI with an account that can access this repository
and its private container package:

```sh
gh auth login
gh auth refresh --scopes read:packages
git clone git@github.com:super-trace/ac6-workshop-lab.git
cd ac6-workshop-lab
gh auth token | docker login ghcr.io -u "$(gh api user --jq .login)" --password-stdin
just lab-setup
```

`lab-setup` pulls the network OS images, builds the Linux client image,
and installs the shared lab key and SSH aliases under `~/.ssh/`.
It does not install the Linux-only bundled `stcli` on your computer.
The containerlab helper requires privileged Docker access.

## Start and check

```sh
just lab-up
just verify
```

Wait for startup configuration to finish. Expect Established BGP sessions,
successful client pings, and SSH access to all nodes. Initial image
downloads and device startup can take several minutes.

## Connect

Install the native CLI on your computer (macOS, Linux, or WSL). While the
release repository is private, use your authenticated GitHub CLI:

```sh
gh api repos/super-trace/stcli-releases/contents/install.sh \
  --jq .content | base64 --decode > /tmp/stcli-install.sh
bash /tmp/stcli-install.sh
export PATH="$HOME/.local/bin:$PATH"
stcli --version
```

Then sign in and start a session on one device:

```sh
stcli login
stcli sw-jfk
```

Inside `stcli`, add the other devices to the same session, one per line:

```
/add sw-iad
/add rtr-phl
/add rtr-ewr
/add client-jfk
/add client-iad
```

`stcli sw-jfk sw-iad` would open each device in its own tab, a separate
session. The main [README](README.md#4-connect-to-the-network) covers the
agent-driven way to connect, approvals, and the scenarios.

`stcli login` prints a verification link with the code filled in; if this
machine has no browser, open the link on another one. Add
`~/.local/bin` to your shell's PATH to keep the installed CLI available in
new terminals. For a router's native CLI, run `just lab-cli rtr-ewr`. List
all commands with `just --list`.

## Finish

```sh
just lab-down
just cleanup-ssh
```

Do not run a Codespace port-forwarding tunnel while the local lab is
running: both use SSH ports 2401–2406 on your computer.
