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

## A. Create a Codespace

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/super-trace/ac6-workshop-lab?quickstart=1&geo=UsEast)

Open the link above:
<https://codespaces.new/super-trace/ac6-workshop-lab?quickstart=1&geo=UsEast>.
It creates your Codespace from a prebuilt image, or reopens the one you
already have. The repository requires a **4-core / 16 GB RAM** machine, so
smaller machine types aren't offered.

The Codespace opens in about a minute with the lab images, `just` and SSH
configuration already in place, including the Arista cEOS image. If
`just lab-up` says cEOS is missing, it prints how to fetch it from
arista.com with your own (free) Arista account.

## B. Install stcli

**B.1** In the Codespace terminal, install `stcli`, the same way as on
[cli.supertrace.ai](https://cli.supertrace.ai):

```sh
curl -fsSL https://cli.supertrace.ai/install.sh | sh
```

**B.2** The installer adds `stcli` to your PATH in `~/.bashrc`. Reload it, so this
terminal finds `stcli`:

```sh
source ~/.bashrc
```

You'll sign in the first time you run `stcli`, once the lab is up.

## C. Start and verify

**C.1** Start the lab (about 3 minutes). This also starts NetBox and its MCP server
(see [G. NetBox](#g-netbox)):

```sh
just lab-up
```

**C.2** Then check it:

```sh
just lab-verify
```

`lab-verify` checks the starting point: arista
configured, nokia blank, both links up, SSH to both, and NetBox and its MCP
server answering. It ends with **LAB
IS VERIFIED**, or **LAB VERIFICATION FAILED** with each failed check printed
in red above it.

## D. Workshop exercises

Work through these in order, in one `stcli` tab. Copy each prompt into
`stcli` as written. Each scenario starts with `/new`, which clears the
conversation but keeps your devices connected, so one scenario's answers
don't steer the next.

A ping or other long-running command can be stopped with **Esc**.

### Scenario 1: single device, basic queries and web search

**1.1** **Explore the Arista.** Start `stcli`:

```sh
stcli
```

The first time, it signs you in: open the verification link in your
computer's browser (the one-time code is already filled in) and wait for
**Signed in.** in the Codespace terminal. Credentials are saved in the
Codespace and refreshed automatically.

**1.2** Connect to arista by its management IP, as the lab user:

```
connect oldprotocol@172.20.23.3
```

> [!NOTE]
> When `stcli` asks for the password, type **`newbrain`**. Both devices use
> the same login: user `oldprotocol`, password `newbrain`.

**1.3** Find the login config:

```
show me the config that controls the username and password on this box
```

**1.4** Run a command directly on arista, without the agent. Note the software
version: you'll ask about it shortly:

```
!show version
```

**1.5** Read the routing table. The BGP peer shows as down, because nothing on the
other end is configured yet:

```
Show me routing on this device.
```

**1.6** Pull the config behind the routing:

```
Show me the configuration snippets behind the routing you just diagnosed.
```

**1.7** Check the firmware against the web:

```
Search the web for any recent patches on this firmware version that I should be aware of.
```

**1.8** Audit the device. This one takes a few minutes, so it comes last:

```
Do a full security audit and give me a TLDR of what to focus on.
```

Then ask it whatever you want; be curious.

### Scenario 2: two devices, BGP

**2.1** Start a fresh conversation. arista stays connected:

```
/new
```

arista has a BGP peer configured at `10.0.0.1`, but nothing in its config
says what that peer is.

**2.2** Ping the peer across the BGP link. This should fail: the peer's end of the
link has no IP address yet. A good answer explains why rather than only
reporting the failure.

```
Ping the BGP peer at 10.0.0.1.
```

**2.3** Generate the config for the other end. With only arista in the session, the
agent should write it for Arista EOS:

```
Generate a configuration snippet to configure BGP on a peer to this device.
```

**2.4** The peer is actually a Nokia. Convert the snippet:

```
Do it for Nokia SR Linux.
```

**2.5** Connect to the Nokia by its management IP, so both devices are in one
session:

```
/add oldprotocol@172.20.23.2
```

> [!NOTE]
> Password: **`newbrain`**

**2.6** Review the full change before anything runs:

```
Show me the complete Nokia SR Linux config block you would apply to the device you just added. Don't apply anything yet.
```

**2.7** Apply it. Each command stops at **Approve this command?**; check that it
names the Nokia before you approve it. Expect around 15 approvals:

```
Apply that config block to the Nokia, one command at a time, in order. Don't run anything in parallel.
```

**2.8** Ping again and check the session. The ping should now succeed, and BGP
should be Established:

```
Ping the BGP peer at 10.0.0.1 again, and verify that BGP is up.
```

**2.9** Have the agent walk through it:

```
Explain what you did.
```

**2.10** In a terminal outside `stcli`, this confirms the result. It ends with **BGP
IS UP** once the session is Established and nokia has installed arista's
prefixes:

```sh
just check-bgp
```

### Scenario 3: NetBox, drift and updating the source of truth

**3.1** Start a fresh conversation. Both devices stay connected:

```
/new
```

NetBox is the lab's source of truth: it documents what arista should look
like. Like every real NetBox, it has drifted: in a few places it no longer
matches the network. In this scenario the agent finds where NetBox and
arista disagree, asks you which side is right, and fixes the side that's
wrong.

**3.2** Connect `stcli` to NetBox:

```
/netbox connect http://localhost:8000
```

> [!NOTE]
> When it asks for the API token, paste the lab's token:
>
> ```
> nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000
> ```
>
> The token stays in the Codespace, like an SSH password: `stcli` never sends
> it to the agent.

**3.3** Ask what NetBox knows. Reads from NetBox run without asking you:

```
What does NetBox document for arista? List its interfaces, IP addresses and VLANs.
```

**3.4** Compare NetBox with the real device:

```
Compare arista's running configuration with NetBox and show me every difference.
```

**3.5** A good answer is a table of discrepancies, and a question: for each one,
which side is right? It won't change either side until you answer. Decide
item by item. Where arista is right, NetBox is stale:

```
For every difference where arista is right, update NetBox to match.
```

The agent proposes one changeset. **Apply these changes to NetBox?** shows
every field it will change, `current → new`, with the reason for each.
Nothing is written until you press `y`.

Where NetBox is right, arista has drifted. Have the agent fix arista
instead; that's a device change, with its own approval.

**3.6** Check the result in the NetBox UI (**Ports** tab → port 8000, login
`oldprotocol` / `newbrain`): each change is in **Operations → Change Log**,
with the agent's reason as its message. In a terminal outside `stcli`, this
confirms it. It ends with **NETBOX MATCHES ARISTA** once NetBox no longer
disagrees with arista anywhere arista is right:

```sh
just check-netbox
```

**3.7** Have the agent walk through it:

```
Explain what you changed in NetBox and why.
```

**3.8** To run this scenario again, put NetBox back as it was seeded, drift
included (seconds; the devices are untouched):

```sh
just reset-netbox
```

<details>
<summary>Facilitator reference: what NetBox gets wrong</summary>

| Object | NetBox says | arista has | Right side | Fix |
| --- | --- | --- | --- | --- |
| VLAN 130 name | `SECURITY` | `CAMERAS` | arista | update the VLAN in NetBox |
| Loopback1 | missing | `172.16.10.1/24`, "LAN: simulated site subnet" | arista | create the interface and its address in NetBox |
| Vlan120 gateway | `10.120.0.254/24` | `10.120.0.1/24` | arista | update the address in NetBox |
| Ethernet2 description | `TRUNK: VLANs 110,120,130` | `TRUNK: to peer switch` | NetBox (the documented standard) | set the description on arista |

`just check-netbox` checks the first three. The fourth is there so the
agent has to ask, rather than assume the device always wins; either answer
is fine. Everything else in NetBox matches arista: the site `lab`, the
device and its platform, Management0, Ethernet1, Loopback0, VLANs 110 and
120, and the other addresses. nokia isn't in NetBox: attendees build it in
Scenario 2.

</details>

### Scenario 4: skills

<!-- TODO: placeholder; the skills feature is still being built. -->

Coming soon.

### Scenario 5: choose your own adventure, layer 2

The second link between the devices, arista's `Ethernet2` to nokia's
`ethernet-1/2`, is a layer 2 trunk. arista already carries several VLANs on
it, each with a gateway address. nokia's end is at factory defaults.

**The goal:** nokia reaches arista's gateway in every VLAN, and arista
learns nokia's MAC address in each one. arista needs no changes.

There are no prompts to copy this time: work it out with `stcli` in your own
words. Scenario 2's flow works here too: start fresh with `/new`, test the
link and find out why it fails, see what arista expects (NetBox documents
the VLANs too), review the nokia config before applying it, then test again.
The first ping in each VLAN may lose a packet while ARP resolves.

**5.1** When you think it's working, check from a terminal outside `stcli`. It ends
with **LAYER 2 IS UP**:

```sh
just check-l2
```

Stuck? Ask a facilitator; the reference below has hints.

### Start over

**D.1** Wipe nokia back to blank in seconds, leaving arista alone, then start again
from Scenario 2 (this also clears any layer 2 config):

```sh
just reset-nokia
```

**D.2** Or redeploy both devices from scratch:

```sh
just lab-up
```

**D.3** If the lab is stuck, tear everything down and start it again. NetBox keeps
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

## E. Connect to the network

Other ways to connect, beyond the workshop's steps.

**E.1** Put both devices in one session, so one agent can work across them. Ask
`stcli` in plain language (the easiest way):

```
Can you please connect to oldprotocol@172.20.23.3 and oldprotocol@172.20.23.2?
```

**E.2** It asks before each connection; press **Enter** to confirm each one, then
type the password, `newbrain`. Or add devices yourself with `/add`, one per
line, which skips the confirmation:

```
/add oldprotocol@172.20.23.3
/add oldprotocol@172.20.23.2
```

`stcli oldprotocol@172.20.23.3 oldprotocol@172.20.23.2` is not the same thing: it opens each device in its own
tab, and every tab is a separate session with its own agent.

Every connection uses the lab login, `oldprotocol` / `newbrain`:
`oldprotocol@172.20.23.3` is arista, `oldprotocol@172.20.23.2` is nokia.

For a device's native CLI outside `stcli`, run `just lab-cli arista` or
`just lab-cli nokia`.

## F. Use stcli

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

## G. NetBox

NetBox is the lab's source of truth (see Scenario 3). `just lab-up` starts
it on port 8000, with NetBox Labs' read-only MCP server beside it on port
8001. `stcli` connects to NetBox itself with `/netbox connect`. NetBox
starts seeded with arista as documented, drift included (see Scenario 3).
It keeps what you change, even across a `just lab-down`; `just
reset-netbox` puts it back as seeded. To start just NetBox and the MCP
server without the lab, run `just netbox-up`.

- **Open it:** the recipe prints the URL. In a Codespace, that's the
  forwarded port 8000 (Ports tab → NetBox).
- **Log in:** `oldprotocol` / `newbrain`, the same as the devices.
- **API token:** `Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000`.
- **MCP server:** `http://localhost:8001/mcp` (streamable HTTP, no
  authentication). It reads NetBox with the admin token above. Port 8001
  stays private in a Codespace.
- **Share it:** the recipe makes port 8000 public when the Codespace allows
  it. Otherwise, in the Ports tab, right-click port 8000 and pick **Port
  Visibility → Public**. Anyone with the URL can then log in with the
  password above, so keep it to this disposable lab.

`just netbox-down` stops NetBox and the MCP server and deletes NetBox's
data; the next `just lab-up` seeds it again.

## H. Finish

Delete the Codespace from GitHub's Codespaces page when finished to remove
its stored resources. Codespaces usage counts against your GitHub allowance.
