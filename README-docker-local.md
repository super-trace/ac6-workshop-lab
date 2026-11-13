# Run the workshop locally with Docker

The same two-device lab runs locally: `nokia` (SR Linux, configured) and
`sonic` (SONiC, blank), joined by a BGP link and a layer 2 trunk. See the
[main README](README.md) for the diagram and the exercises.

## Prepare

Install Git, Docker, `just`, GitHub CLI (`gh`), and a native `stcli` binary.
Allocate **4 CPU cores / 8 GB RAM** to the lab machine. On macOS, use
OrbStack or Docker Desktop and allocate these resources to its Linux VM. On Linux, use
Docker Engine on a machine with these resources. The SONiC image is
AMD64 only: on an Apple silicon Mac, Docker runs it under emulation, so
`sonic` takes a few minutes longer to start.

```sh
git clone https://github.com/super-trace/ac6-workshop-lab.git
cd ac6-workshop-lab
```

The containerlab helper requires privileged Docker access.

## Start and check

`just lab-up` does all the setup itself: it installs the shared lab key and
SSH aliases under `~/.ssh/`, gets the SONiC image (pulled, or built locally
from SONiC's official build the first time, about 3 minutes), and starts
both devices and NetBox. It does not install `stcli`; see Connect below.

Scenario 3 uses GitHub's MCP server through a local proxy that signs in with
a `GITHUB_TOKEN` (a Codespace has one). Export one first, for example from
the GitHub CLI:

```sh
export GITHUB_TOKEN="$(gh auth token)"
```

```sh
just lab-up
```

```sh
just lab-verify
```

Expect nokia configured, sonic blank, both links up, SSH access to both,
and NetBox and GitHub's MCP server answering. Initial image downloads and device
startup can take several minutes.

## Connect

Install the native CLI on your computer (macOS, Linux, or WSL), the same way
as on [cli.supertrace.ai](https://cli.supertrace.ai):

```sh
curl -fsSL https://cli.supertrace.ai/install.sh | sh
```

If the installer added `stcli` to your PATH, run `source ~/.zshrc` (or the
profile it names) or open a new terminal, then check it:

```sh
stcli --version
```

Then start `stcli`:

```sh
stcli
```

The first run signs you in: it prints a verification link with the code
filled in; if this machine has no browser, open the link on another one.
From there, follow the exercises in the main
[README](README.md#d-workshop-exercises). For a router's native CLI, run `just lab-cli nokia` or `just lab-cli sonic`. List
all commands with `just --list`.

## NetBox

`just lab-up` starts NetBox at http://localhost:8000 (login `oldprotocol` /
`newbrain`), seeded with nokia for Scenario 3; see the
[main README](README.md#g-netbox) for the API token. `just netbox-up` starts
NetBox and the GitHub MCP proxy without the devices; run it after exporting
`GITHUB_TOKEN` to give a running lab's proxy the token. `just reset-netbox`
puts NetBox back as seeded; `just netbox-down` stops both and deletes
NetBox's data.

## Finish

```sh
just lab-down
just netbox-down   # lab-down keeps NetBox's data; this deletes it
just cleanup-ssh
```

Do not run a Codespace port-forwarding tunnel while the local lab is
running: both use SSH ports 2401–2402 (and NetBox's 8000) on your
computer.
