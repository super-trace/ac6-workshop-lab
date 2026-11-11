# AC6 workshop lab

A two-device network lab for working with `stcli`, running entirely in
GitHub Codespaces: one Arista cEOS switch that's already configured, one
Nokia SR Linux router that starts blank, and two links between them for you
to bring up.

For local Docker, follow [the local setup guide](README-docker-local.md).

```
      mgmt 172.20.23.3                                   mgmt 172.20.23.2
  ┌──────────────────────┐                           ┌──────────────────────┐
  │ arista               │ Ethernet1          e1-1   │ nokia                │
  │ Arista cEOS          │ ───────────────────────── │ Nokia SR Linux       │
  │ configured           │ 10.0.0.0/31   10.0.0.1/31 │ blank                │
  │                      │     layer 3: eBGP         │                      │
  │                      │                           │                      │
  │                      │ Ethernet2          e1-2   │                      │
  │                      │ ───────────────────────── │                      │
  └──────────────────────┘    layer 2: VLAN trunk    └──────────────────────┘
```

arista's end of the BGP link is configured; nokia's `10.0.0.1/31` is the
address the workshop gives it, since nokia starts with no addresses on
either link. Connect to each device by its management IP.

## 1. Create a Codespace

Open this repository on GitHub and select **Code → Codespaces → Create
codespace on main**. The repository requires a **4-core / 16 GB RAM**
machine, so smaller machine types aren't offered.

Wait for automatic setup to finish. It installs the lab images, `just`, and
SSH configuration, and sets up NetBox's database (about 6 minutes of it). The **GitHub Codespaces** terminal that opens
first shows only a pointer to the creation log; to watch setup live, click
**+** in the terminal panel (or pick the **bash** terminal in the list). That
terminal follows setup step by step and says when it's done.

## 2. Install stcli

In the Codespace terminal, install `stcli`:

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh | bash
```

Reload your shell configuration, so this terminal finds `stcli`:

```sh
source /home/vscode/.bashrc
```

Until `stcli-releases` is public, the `curl` download fails with a 404;
install through your GitHub login instead:
`gh api repos/super-trace/stcli-releases/contents/install.sh --jq .content | base64 -d | bash`.

You'll sign in the first time you run `stcli`, once the lab is up.

## 3. Start and verify

Start the lab (about 3 minutes). This also starts NetBox and its MCP server
(see [step 7](#7-netbox)):

```sh
just lab-up
```

Then check it:

```sh
just lab-verify
```

`lab-verify` checks the starting point: arista
configured, nokia blank, both links up, SSH to both, and NetBox and its MCP
server answering. It ends with **LAB
IS VERIFIED**, or **LAB VERIFICATION FAILED** with each failed check printed
in red above it.

## 4. Workshop exercises

Work through these in order, in one `stcli` tab. Copy each prompt into
`stcli` as written. Each scenario starts with `/new`, which clears the
conversation but keeps your devices connected, so one scenario's answers
don't steer the next.

A ping or other long-running command can be stopped with **Esc**.

### Scenario 1: single device, basic queries and web search

**Explore the Arista.** Start `stcli`:

```sh
stcli
```

The first time, it signs you in: open the verification link in your
computer's browser (the one-time code is already filled in) and wait for
**Signed in.** in the Codespace terminal. Credentials are saved in the
Codespace and refreshed automatically.

Connect to arista by its management IP:

```
connect 172.20.23.3
```

Find the login config:

```
show me the config that controls the username and password on this box
```

Run a command directly on arista, without the agent. Note the software
version: you'll ask about it shortly:

```
!show version
```

Read the routing table. The BGP peer shows as down, because nothing on the
other end is configured yet:

```
Show me routing on this device.
```

Pull the config behind the routing:

```
Show me the configuration snippets behind the routing you just diagnosed.
```

Check the firmware against the web:

```
Search the web for any recent patches on this firmware version that I should be aware of.
```

Audit the device. This one takes a few minutes, so it comes last:

```
Do a full security audit and give me a TLDR of what to focus on.
```

Then ask it whatever you want; be curious.

### Scenario 2: two devices, BGP

Start a fresh conversation. arista stays connected:

```
/new
```

arista has a BGP peer configured at `10.0.0.1`, but nothing in its config
says what that peer is.

Ping the peer across the BGP link. This should fail: the peer's end of the
link has no IP address yet. A good answer explains why rather than only
reporting the failure.

```
Ping the BGP peer at 10.0.0.1.
```

Generate the config for the other end. With only arista in the session, the
agent should write it for Arista EOS:

```
Generate a configuration snippet to configure BGP on a peer to this device.
```

The peer is actually a Nokia. Convert the snippet:

```
Do it for Nokia SR Linux.
```

Connect to the Nokia by its management IP, so both devices are in one
session:

```
/add 172.20.23.2
```

Review the full change before anything runs:

```
Show me the complete Nokia SR Linux config block you would apply to the device you just added. Don't apply anything yet.
```

Apply it. Each command stops at **Approve this command?**; check that it
names the Nokia before you approve it. Expect around 15 approvals:

```
Apply that config block to the Nokia, one command at a time, in order. Don't run anything in parallel.
```

Ping again and check the session. The ping should now succeed, and BGP
should be Established:

```
Ping the BGP peer at 10.0.0.1 again, and verify that BGP is up.
```

Have the agent walk through it:

```
Explain what you did.
```

In a terminal outside `stcli`, this confirms the result. It ends with **BGP
IS UP** once the session is Established and nokia has installed arista's
prefixes:

```sh
just check-bgp
```

### Scenario 3: layer 2

Start a fresh conversation. Both devices stay connected:

```
/new
```

The second link, the Arista's `Ethernet2` to nokia's `ethernet-1/2`, is a
layer 2 link: the Arista already treats it as a trunk carrying several
VLANs, each with a gateway address on the Arista. The Nokia's end is still
at factory defaults.

Test the link. This should fail: the Nokia isn't carrying any of the
Arista's VLANs yet. A good answer works out which VLANs and gateways the
Arista has, tries to reach them, and explains why it can't.

```
Test layer 2 connectivity between the Arista's Ethernet2 and the Nokia's ethernet-1/2.
```

Generate the config: the Arista's existing trunk as the reference, and the
Nokia side to match it, with an address in each VLAN so the Nokia can reach
the Arista's gateways:

```
Show me the Arista's trunk and VLAN configuration on Ethernet2, then generate the matching Nokia SR Linux configuration for ethernet-1/2, with an address in each VLAN. Don't apply anything yet.
```

Apply it. Check that each command names the Nokia before you approve it;
the Arista needs no changes:

```
Apply that config block to the Nokia, one command at a time, in order. Don't run anything in parallel.
```

Test again. The first ping in each VLAN may lose a packet while ARP
resolves:

```
Test layer 2 connectivity between the two devices again.
```

Confirm every VLAN is up, from both ends:

```
Confirm the Nokia can reach the Arista's gateway in every VLAN, and that the Arista has learned the Nokia's MAC address in each one.
```

Have the agent walk through it:

```
Explain what you did.
```

In a terminal outside `stcli`, this confirms the result. It ends with
**LAYER 2 IS UP** once the Nokia reaches the Arista's gateway in every VLAN:

```sh
just check-l2
```

### Start over

Wipe nokia back to blank in seconds, leaving arista alone, then start again
from Scenario 2:

```sh
just reset-nokia
```

Or redeploy both devices from scratch:

```sh
just lab-up
```

If the lab is stuck, tear everything down and start it again. NetBox keeps
its data:

```sh
just lab-down
just lab-up
```

<details>
<summary>Facilitator reference: what arista has configured</summary>

| | arista | nokia (target) |
| --- | --- | --- |
| BGP link | `Ethernet1`, `10.0.0.0/31`, AS 65001 | `ethernet-1/1.0`, `10.0.0.1/31`, AS 65002 |
| Advertised by arista | `10.255.0.1/32` (Loopback0), `172.16.10.0/24` (Loopback1) | |
| Trunk | `Ethernet2`, VLANs 110 DATA, 120 VOICE, 130 CAMERAS | `ethernet-1/2` with `vlan-tagging`, a subinterface per VLAN |
| VLAN gateways | `Vlan110/120/130`: `10.110.0.1/24`, `10.120.0.1/24`, `10.130.0.1/24` | an address in each VLAN, such as `10.110.0.2/24` |

SR Linux rejects every received eBGP route until an import policy accepts
it: the session comes up without one, but `just check-bgp` fails until
nokia installs `172.16.10.0/24`. Every new nokia interface or subinterface
also has to be added to `network-instance default`, or it stays down. The
simplest layer 2 answer is a routed subinterface per VLAN (`vlan encap
single-tagged vlan-id 110` plus an IPv4 address); a mac-vrf with an IRB
works too.

</details>

## 5. Connect to the network

Other ways to connect, beyond the workshop's steps.

Put both devices in one session, so one agent can work across them. Ask
`stcli` in plain language (the easiest way):

```
Can you please connect to arista and nokia?
```

It asks before each connection; press **Enter** to confirm each one. Or add
devices yourself with `/add`, one per line, which skips the confirmation:

```
/add arista
/add nokia
```

`stcli arista nokia` is not the same thing: it opens each device in its own
tab, and every tab is a separate session with its own agent.

Each device also answers on its management IP: `connect 172.20.23.3` for
arista, `connect 172.20.23.2` for nokia.

For a device's native CLI outside `stcli`, run `just lab-cli arista` or
`just lab-cli nokia`.

## 6. Use stcli

- **Ask in plain language:** "is BGP up between nokia and arista?" One agent
  works across every device in the session, and each command it runs is
  labelled with the device it ran on.
- **Approvals.** Read-only commands run straight away. Anything that changes
  a device stops at **Approve this command?**, with the device named beside
  the command. Destructive commands also ask you to type a confirmation
  phrase.
- **Run a command yourself:** `!arista show ip bgp summary`. With several
  devices in the session, name the device first; a bare `!` lists the names.
- **Manage devices:** `/disconnect arista` closes one device;
  `/connect arista` dials it again.
- **Start fresh:** `/new` clears the conversation and keeps the connected
  devices.
- **Tabs are separate sessions.** Switch with
  `/switch`, `ctrl+←/→` or `alt+1..9`; a background tab shows `!` when it is
  waiting for your approval.

## 7. NetBox

NetBox is where device data exported with `stcli` will land; that export
feature is still being built. `just lab-up` starts it on port 8000, with
NetBox Labs' read-only MCP server beside it on port 8001. NetBox starts
empty: no sites, device types or devices. It keeps what you add, even across
a `just lab-down`. To start just NetBox and the MCP
server without the lab, run `just netbox-up`.

- **Open it:** the recipe prints the URL. In a Codespace, that's the
  forwarded port 8000 (Ports tab → NetBox).
- **Log in:** `admin` / `ac6-workshop`.
- **API token:** `Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000`.
- **MCP server:** `http://localhost:8001/mcp` (streamable HTTP, no
  authentication). It reads NetBox with the admin token above. Port 8001
  stays private in a Codespace.
- **Share it:** the recipe makes port 8000 public when the Codespace allows
  it. Otherwise, in the Ports tab, right-click port 8000 and pick **Port
  Visibility → Public**. Anyone with the URL can then log in with the
  password above, so keep it to this disposable lab.

`just netbox-down` stops NetBox and the MCP server and deletes NetBox's
data; the next `just lab-up` then sets up a fresh database, which takes
about 6 minutes in a Codespace.

## 8. Finish

Delete the Codespace from GitHub's Codespaces page when finished to remove
its stored resources. Codespaces usage counts against your GitHub allowance.
