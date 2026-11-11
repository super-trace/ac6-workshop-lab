# Run the workshop locally with Docker

The same two-device lab runs locally: `arista` (cEOS, configured) and
`nokia` (SR Linux, blank), joined by a BGP link and a layer 2 trunk. See the
[main README](README.md) for the diagram and the exercises.

## Prepare

Install Git, Docker, `just`, GitHub CLI (`gh`), and a native `stcli` binary.
Allocate **4 CPU cores / 8 GB RAM** to the lab machine. On macOS, use
OrbStack or Docker Desktop and allocate these resources to its Linux VM. On Linux, use
Docker Engine on a machine with these resources.

The Arista cEOS image comes from arista.com under your own free Arista
account; this repository doesn't host it. Create an access token on your
[arista.com profile](https://www.arista.com/en/users/profile), and install Arista's downloader (`pip install
eos-downloader==0.16.0`, or have `uv` or `pipx`; `just` uses whichever it
finds). It fetches the AMD64 or ARM64 build to match your Docker engine.

```sh
git clone https://github.com/super-trace/ac6-workshop-lab.git
cd ac6-workshop-lab
ARISTA_TOKEN=<your arista.com token> just lab-setup
```

Already downloaded `cEOS64-lab-4.36.2F.tar.xz` (or `cEOSarm-lab-…` on
ARM64) from arista.com? Run `just ceos-import path/to/the.tar.xz`, then
`just lab-setup` without the token.

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

Expect arista configured, nokia blank, both links up, SSH access to both,
and NetBox and its MCP server answering. Initial image downloads and device
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
[README](README.md#d-workshop-exercises). For a router's native CLI, run `just lab-cli arista`. List
all commands with `just --list`.

## NetBox

`just lab-up` starts NetBox at http://localhost:8000 (login `oldprotocol` /
`newbrain`), seeded with arista for Scenario 3, and its MCP server at
http://localhost:8001/mcp; see the [main README](README.md#g-netbox) for
the API token. `just netbox-up` starts just those two; `just reset-netbox`
puts NetBox back as seeded; `just netbox-down` stops them and deletes
NetBox's data.

## Finish

```sh
just lab-down
just netbox-down   # lab-down keeps NetBox's data; this deletes it
just cleanup-ssh
```

Do not run a Codespace port-forwarding tunnel while the local lab is
running: both use SSH ports 2401–2402 (and NetBox's 8000 and 8001) on your
computer.
