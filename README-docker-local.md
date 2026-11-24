# Run the workshop locally with Docker

The same lab a Codespace gives you runs on your own computer: `nokia` (SR
Linux, configured) and `sonic` (SONiC, blank), joined by a BGP link and a
layer 2 trunk, plus NetBox and NetBox's MCP server. Every image is public,
so nothing needs a login. This guide replaces the main README's sections
A–C. From D on, follow the [main README](README.md#d-workshop-exercises),
with the few local differences listed below.

## Prepare

You need:

- **Docker:** [OrbStack](https://orbstack.dev) or Docker Desktop on macOS,
  or Docker Engine on Linux. The containerlab helper runs a privileged
  container, so rootless Docker won't do.
- **[`just`](https://just.systems):** for example `brew install just`.
- **Git, curl and perl:** macOS and most Linux distributions have them
  already.
- **Resources:** 4 CPU cores and 8 GB of RAM for Docker; the running lab
  uses about 3 GB. On macOS, set this in OrbStack's or Docker Desktop's
  settings.
- **Free local ports:** 2401 and 2402 (SSH to the devices), 8000 (NetBox)
  and 8002 (NetBox's MCP server).

The SONiC image is AMD64 only. On an Apple silicon Mac, Docker runs it
under Rosetta: OrbStack uses Rosetta by default; in Docker Desktop, turn on
**Settings → General → Use Rosetta for x86_64/amd64 emulation on Apple
Silicon**.

Then clone the lab:

**In the terminal:**

```sh
git clone https://github.com/super-trace/ac6-workshop-lab.git
cd ac6-workshop-lab
```

✅ **You should see:** a new `ac6-workshop-lab` folder, and your terminal in it.

## Start and check

#### 1. Start the lab

`just lab-up` does all the setup itself:

- It installs the shared lab key and the `nokia` and `sonic` SSH aliases
  under `~/.ssh/`.
- The first time, it builds the SONiC image from SONiC's official build.
- It starts both devices, plus NetBox and its MCP server.

**In the terminal:**

```sh
just lab-up
```

✅ **You should see:** **Next: just lab-verify** at the end. The first run downloads the images
and builds SONiC's, so it takes a few minutes; later runs take under a
minute. Two yellow **WARN** lines about nokia's hosts file are harmless.

#### 2. Check the lab

**In the terminal:**

```sh
just lab-verify
```

✅ **You should see:** **LAB IS VERIFIED**, then **Open NetBox: http://localhost:8000**.

It checks that nokia is configured, sonic is blank, both links are up, SSH
reaches both devices, NetBox answers with its config templates and BGP AS
field, and NetBox's MCP server answers.

#### 3. Install stcli

Install `stcli` on your computer (macOS, Linux or WSL), the same way as on
[cli.supertrace.ai](https://cli.supertrace.ai):

**In the terminal:**

```sh
curl -fsSL https://cli.supertrace.ai/install.sh | sh
```

If the installer added `stcli` to your PATH, reload your shell's settings
(`source ~/.zshrc` on macOS, `source ~/.bashrc` on most Linux systems, or the
profile it names), or open a new terminal. Then check it:

**In the terminal:**

```sh
stcli --version
```

✅ **You should see:** `stcli`'s version number.

#### 4. Start stcli

Start `stcli` from this folder:

**In the terminal:**

```sh
stcli
```

The first run signs you in: it prints a verification link with the code
filled in. If this machine has no browser, open the link on another one.

✅ **You should see:** **Signed in.**, then `stcli`'s prompt.

Now follow the exercises in the main README, from
[D. Workshop exercises](README.md#d-workshop-exercises).

## How the workshop differs locally

The main README is written for a Codespace. Every `stcli` prompt and command
works the same locally, including the `nokia` and `sonic` SSH aliases, the
management IPs, `/netbox connect http://localhost:8000`, and `/mcp add netbox
http://localhost:8002/mcp`. Only these differ:

- **NetBox:** open <http://localhost:8000> in your browser. There's no
  Codespace **Ports** tab.
- **Files `stcli` saves:** `sonic-bgp.conf` (Scenario 2) and
  `security-audit.md` (Scenario 3) land in the folder you started `stcli`
  from, instead of the Codespace's file explorer.
- **SSH ports:** "the Codespace's forwarded port" means a local port here:
  Docker publishes nokia's SSH on `127.0.0.1:2401` and sonic's on
  `127.0.0.1:2402`. That's why `connect 172.20.23.2` works even where Docker
  can't route to container IPs, as on macOS.

## NetBox

`just lab-up` starts NetBox at <http://localhost:8000> (login
`oldprotocol:newbrain`), seeded with nokia and two config templates for
Scenario 3. Its API token is
`nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000` (send it as
`Authorization: Bearer <token>`). NetBox's MCP server answers at
`http://localhost:8002/mcp` and signs in to NetBox with that token for you.

- `just netbox-up` starts NetBox and its MCP server without the devices.
- `just lab-reset-netbox` puts NetBox back as seeded.
- `just netbox-down` stops both and deletes NetBox's data.

## Reset and finish

The main README's [E. Reset the lab](README.md#e-reset-the-lab) recipes work
the same locally. When you're done:

**In the terminal:**

```sh
just lab-down
just netbox-down   # lab-down keeps NetBox's data; this deletes it
just cleanup-ssh
```

✅ **You should see:** **LAB IS DOWN**, then **NETBOX IS DOWN**.

## Troubleshooting

- **A port is already in use:** something else is listening on 2401, 2402,
  8000 or 8002, such as a Codespace port-forwarding tunnel (`gh codespace
  ports forward`) or another NetBox. Stop it, then run `just lab-up` again.
- **A network overlaps:** the lab uses `172.20.23.0/24` and NetBox
  `172.20.24.0/24`. If another Docker network already holds one of them,
  remove it (`docker network ls`, `docker network rm <name>`) and run
  `just lab-up` again.
- **sonic never comes up on Apple silicon:** check that Rosetta is turned on
  (see [Prepare](#prepare)).
- **Anything else:** `just lab-reset` tears the lab down and starts it
  again from scratch. NetBox keeps its data.
