# Run the workshop locally with Docker

The same two-device lab runs locally: `nokia` (SR Linux, configured) and
`arista` (cEOS, blank), joined by a BGP link and a layer 2 trunk. See the
[main README](README.md) for the diagram and the exercises.

## Prepare

Install Git, Docker, `just`, GitHub CLI (`gh`), and a native `stcli` binary.
Allocate **4 CPU cores / 8 GB RAM** to the lab machine. On macOS, use
OrbStack or Docker Desktop and allocate these resources to its Linux VM. On Linux, use
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

`lab-setup` pulls the network OS images and installs the shared lab key and SSH aliases under `~/.ssh/`.
It does not install `stcli`; see Connect below.
The containerlab helper requires privileged Docker access.

## Start and check

```sh
just lab-up
```

```sh
just lab-verify
```

Expect nokia configured, arista blank, both links up, and SSH access to
both. Initial image downloads and device startup can take several minutes.

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

Then start `stcli`:

```sh
stcli
```

The first run signs you in: it prints a verification link with the code
filled in; if this machine has no browser, open the link on another one.
From there, follow the exercises in the main
[README](README.md#4-workshop-exercises). Add
`~/.local/bin` to your shell's PATH to keep the installed CLI available in
new terminals. For a router's native CLI, run `just lab-cli arista`. List
all commands with `just --list`.

## NetBox

`just netbox-up` starts NetBox at http://localhost:8000 (login `admin` /
`ac6-workshop`), empty apart from that login; see the
[main README](README.md#7-netbox) for the API token. `just netbox-down`
stops it and deletes its data.

## Finish

```sh
just netbox-down   # if you started NetBox
just lab-down
just cleanup-ssh
```

Do not run a Codespace port-forwarding tunnel while the local lab is
running: both use SSH ports 2401–2402 (and NetBox's 8000) on your computer.
