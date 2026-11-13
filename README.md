# AC6 workshop lab | Old Protocol New Brain

Slides: [supertrace.ai/ac6-deck](http://supertrace.ai/ac6-deck)

A two-device network lab for working with `stcli`, running entirely in
GitHub Codespaces: one Nokia SR Linux router that's already configured, one
SONiC switch that starts blank, and two links between them for you to bring
up.

For local Docker, follow [the local setup guide](README-docker-local.md).

## A. Create a Codespace

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/super-trace/ac6-workshop-lab?quickstart=1&geo=UsEast)

Open the link above:
<https://codespaces.new/super-trace/ac6-workshop-lab?quickstart=1&geo=UsEast>.
It creates your Codespace from a prebuilt image, or reopens the one you
already have. The repository requires a **4-core / 16 GB RAM** machine, so
smaller machine types aren't offered.

The Codespace opens in about a minute with the lab images, `just` and SSH
configuration already in place. While it starts, here's the lab you'll
work with:

```
      mgmt 172.20.23.2                                   mgmt 172.20.23.3
  ┌──────────────────────┐                           ┌──────────────────────┐
  │ nokia                │ e1-1           Ethernet0  │ sonic                │
  │ Nokia SR Linux       │ ───────────────────────── │ SONiC                │
  │ configured           │ 10.0.0.0/31   10.0.0.1/31 │ blank                │
  │                      │     layer 3: eBGP         │                      │
  │                      │                           │                      │
  │                      │ e1-2           Ethernet4  │                      │
  │                      │ ───────────────────────── │                      │
  └──────────────────────┘    layer 2: VLAN trunk    └──────────────────────┘
              │ documents nokia (drift included); sonic isn't in it yet
  ┌───────────┴─────────────────────────────────────────────────────────────┐
  │ netbox                              source of truth                     │
  │ NetBox 4.7 · UI and API on :8000                                        │
  └─────────────────────────────────────────────────────────────────────────┘
```

nokia's end of the BGP link is configured; sonic's `10.0.0.1/31` is the
address the workshop gives it, since sonic starts with no addresses on
either link. Connect to each device by its management IP.

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

You'll sign in the first time you run `stcli`, once the lab is up (C.3).

## C. Start and verify

**C.1** Start the lab (about 3 minutes). This also starts NetBox (see
[G. NetBox](#g-netbox)) and readies GitHub's MCP server for Scenario 3:

```sh
just lab-up
```

**C.2** Then check it:

```sh
just lab-verify
```

`lab-verify` checks the starting point: nokia
configured, sonic blank, both links up, SSH to both, and NetBox and
GitHub's MCP server answering. It ends with **LAB
IS VERIFIED**, or **LAB VERIFICATION FAILED** with each failed check printed
in red above it. The last line is NetBox's address, **Open NetBox**:
open it in a browser tab now, ready for Scenario 3.

**C.3** Start `stcli` and sign in:

```sh
stcli
```

The first time, it signs you in: open the verification link in your
computer's browser (the one-time code is already filled in). A new account
asks a few details first.

> [!TIP]
> In **Referral or promo code**, enter **`AUTOCON6`** for $6 of credit, on
> top of the $5 every new account starts with. Valid until 11.20.26, once per
> account.

Wait for **Signed in.** in the Codespace terminal. Credentials are saved in
the Codespace and refreshed automatically. Leave `stcli` open: Scenario 1
starts here.

## D. Workshop exercises

Work through these in order, in one `stcli` tab. Copy each prompt into
`stcli` as written. Each scenario starts with `/clear`, which clears the
conversation but keeps your devices connected, so one scenario's answers
don't steer the next. Your skill and anything you ask `stcli` to remember
carry across, because they belong to your account, not the conversation.

A ping or other long-running command can be stopped with **Esc**.

Each scenario ends with `/feedback`: tell us what worked and what didn't, in
a sentence. We read every one.

### Team standards

Every network team has conventions that live in a wiki or in people's
heads. This is the lab team's standard for interface descriptions. In
Scenario 1 you turn it into a `stcli` **skill**; from then on the agent
applies it on every device, in every scenario, without being reminded.

```
Interface descriptions follow ROLE: detail, except VLAN gateways (below).
- Roles: BGP, TRUNK, LOOPBACK, LAN.
- A BGP link names its peer's AS: "BGP: eBGP peer AS65002".
- A trunk lists its VLANs: "TRUNK: VLANs 110,120,130".
- A loopback names its job: "LOOPBACK: router-id 10.255.0.1".
- A VLAN gateway reads "VLAN <id> <NAME> gateway": "VLAN 110 DATA gateway".
- Describe physical ports, loopbacks and VLAN gateways; other subinterfaces need none.
- A port with nothing connected has no description. Management ports are exempt.
```

### Scenario 1: one device, talk to your network

You'll connect to nokia, ask it questions in plain language, run commands
yourself, and teach `stcli` your team's standard.

**D.1.1** Connect to nokia by its management IP, as the lab user:

```
connect oldprotocol@172.20.23.2
```

> [!NOTE]
> When `stcli` asks for the password, type **`newbrain`**. It's the same
> login on every device: user `oldprotocol`, password `newbrain`.

Once it connects, `stcli` works out what it's talking to by itself: watch for
**platform set to Nokia SR Linux**.

**D.1.2** Your password went straight to the device; the AI agent never saw it.
Check:

```
What password did I use to log in to nokia?
```

`stcli` typed it to nokia from this machine, so the agent can't know it.
Device credentials never leave your Codespace.

**D.1.3** Ask nokia about itself:

```
show me the config that controls the username and password on this box
```

**D.1.4** That config holds every user's password hash. See what left the
Codespace: open [cli.supertrace.ai/app/usage](https://cli.supertrace.ai/app/usage),
go to **Sessions**, and open this session. The command and its output are
there, but each password hash reads `[redacted]`: `stcli` strips them before
anything leaves your machine.

**D.1.5** Run a command yourself, without the agent. Note the software version:
you'll ask about it shortly:

```
!show version
```

**D.1.6** Read the routing table. The BGP peer shows as down, because nothing on the
other end is configured yet:

```
Show me routing on this device.
```

> [!WARNING]
> **TODO (Mahir), before Monday 11/16:** try this alternative memory against
> the one in D.1.7 (rollback commands) and keep the better one. If IOS wins,
> update D.1.7's prompt and the payoff notes in D.2.3 and D.2.7.
>
> ```
> I think in Cisco IOS. When you give me SR Linux or SONiC commands, add the IOS equivalent.
> ```

**D.1.7** Tell `stcli` how you work. It remembers across sessions:

```
Remember: when you propose a config change, always include the commands to roll it back.
```

It says what it saved. You'll see it pay off in Scenario 2 without asking
again; your memories are listed on the dashboard's
[**Memory** page](https://cli.supertrace.ai/app/memory).

**D.1.8** Check the firmware against the web:

```
Search the web for any recent patches on this firmware version that I should be aware of.
```

**D.1.9** Turn the [team standards](#team-standards) into a skill. Copy the
whole block, standard included, and paste it into `stcli` as one message;
the line breaks stay in the input until you press **Enter**:

```
Make a skill called interface-standards from our team's standard below. Use it whenever you configure, audit or document interfaces on any device, or compare a device with NetBox.

Interface descriptions follow ROLE: detail, except VLAN gateways (below).
- Roles: BGP, TRUNK, LOOPBACK, LAN.
- A BGP link names its peer's AS: "BGP: eBGP peer AS65002".
- A trunk lists its VLANs: "TRUNK: VLANs 110,120,130".
- A loopback names its job: "LOOPBACK: router-id 10.255.0.1".
- A VLAN gateway reads "VLAN <id> <NAME> gateway": "VLAN 110 DATA gateway".
- Describe physical ports, loopbacks and VLAN gateways; other subinterfaces need none.
- A port with nothing connected has no description. Management ports are exempt.
```

`stcli` shows the whole draft before anything is saved. Read it, then press
`y` to save it. It's yours from now on: it carries across `/clear`, and you
can see or edit it on the dashboard's
[**Skills** page](https://cli.supertrace.ai/app/skills).

**D.1.10** Audit nokia against the standard:

```
Does nokia follow our interface standards? Show me a table of anything that doesn't.
```

A good answer finds one problem: `ethernet-1/2` is described as `TRUNK: to
peer switch`, but a trunk should list its VLANs. Leave it for now; Scenario
3 fixes it.

**D.1.11** Tell us how it went:

```
/feedback
```

For example: *"Turning our wiki standard into a skill took a minute."* or *"I
wanted ___ and it didn't."*

### Scenario 2: two devices, build, convert and apply

You'll build the config for nokia's BGP peer, convert it to another OS, add a
second device, and apply the change one approval at a time.

**D.2.1** Start a fresh conversation. nokia stays connected:

```
/clear
```

nokia has a BGP peer configured at `10.0.0.1`, but nothing in its config
says what that peer is.

**D.2.2** Ping the peer across the BGP link. This should fail: the peer's end of the
link has no IP address yet. A good answer explains why rather than only
reporting the failure.

```
Ping the BGP peer at 10.0.0.1.
```

**D.2.3** Generate the config for the other end. With only nokia in the session, the
agent should write it for Nokia SR Linux:

```
Generate a configuration snippet to configure BGP on a peer to this device.
```

**D.2.4** The peer is actually a SONiC switch. Convert the snippet, and keep
a copy. The agent writes files on this machine, and asks first: the dialog
shows the whole file before it's written.

```
Do it for SONiC, and save it to sonic-bgp.conf.
```

Open `sonic-bgp.conf` in the Codespace's file explorer: it's ready for a
change ticket or a peer review.

**D.2.5** Add the SONiC switch to the session. This time use its name, `sonic`:
the lab's SSH config logs in to it with a key, so there's no password to
type:

```
/add oldprotocol@sonic
```

Watch for **platform set to SONiC**. Both devices are now in one session,
and each command shows which device it ran on.

**D.2.6** sonic has no configuration yet, but someone has been labelling its
ports. Audit them with your skill:

```
Does sonic follow our interface standards? Show me a table of anything that doesn't.
```

A good answer finds two problems: `Ethernet0` is described as `to nokia`,
with no role or peer AS, and `Ethernet8` describes a BGP peer although
nothing is connected to it. It may also flag `Ethernet4`, which is connected
but has no description: that's the layer 2 trunk, which Scenario 4
configures and describes, so leave it for now.

**D.2.7** Review the full change before anything runs:

```
Show me the complete SONiC config you would apply to the device you just added, including the description fixes. Don't apply anything yet.
```

The plan comes with the commands to roll it back, because you asked `stcli`
to remember that in Scenario 1.

**D.2.8** Apply it. Each command stops at **Approve this command?**; check that it
names sonic before you approve it. Expect a handful of approvals:

```
Apply that config to the SONiC switch, one command at a time, in order. Don't run anything in parallel.
```

**D.2.9** Ping again and check the session. The ping should now succeed, and BGP
should be Established:

```
Ping the BGP peer at 10.0.0.1 again, and verify that BGP is up.
```

**D.2.10** Everything you just did is on the record. Open the dashboard at
[cli.supertrace.ai/app](https://cli.supertrace.ai/app), go to **Usage →
Sessions**, and open this session: every command, which device it ran on,
and each approval with who gave it.

**D.2.11** Tell us how it went:

```
/feedback
```

For example: *"Converting the config to SONiC saved me real time."* or *"The
approvals felt ___."*

### Scenario 3: plug in the tools you already use

You'll give `stcli` two tools you already use: GitHub over MCP, and NetBox,
your source of truth, which it reads and fixes.

**D.3.1** Start a fresh conversation. Both devices stay connected:

```
/clear
```

**D.3.2** Plug GitHub in. MCP is how `stcli` uses tools beyond your devices, and
GitHub runs an MCP server. `just lab-up` already set it up for you, signed in
with your Codespace's GitHub account, so it's one command, with no token to
paste:

```
/mcp add github http://localhost:8002/mcp/readonly
```

**D.3.3** Check it's there:

```
/mcp list
```

**D.3.4** In Scenario 2, sonic's BGP session came up but showed `(Policy)`
before any routes arrived. That's FRR, the routing daemon sonic runs. Ask
GitHub about it:

```
Search the FRRouting/frr GitHub issues for ebgp-requires-policy. Why does eBGP exchange no routes until a policy allows them?
```

Each GitHub call stops at a confirm dialog first: press `y`. MCP tools never
run without asking.

**D.3.5** Now NetBox. It's the lab's source of truth: it documents what nokia
should look like. Like every real NetBox, it has drifted: in a few places it
no longer matches the network. The agent finds where NetBox and nokia
disagree, asks you which side is right, and fixes the side that's wrong.

First, open NetBox yourself, so you can watch it change: the NetBox tab
from C.2, or the **Open NetBox** address `just lab-verify` printed. Lost it?
In the Codespace's **Ports** tab, hover over port **8000 (NetBox)** and click
the globe icon (**Open in Browser**). Log in as `oldprotocol` / `newbrain`,
then look at **Devices → nokia** and its interfaces. Keep the tab open.

Then connect `stcli` to NetBox:

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
> The token stays in the Codespace, like your SSH password: `stcli` never sends
> it to the agent.

**D.3.6** Ask what NetBox knows. Reads from NetBox run without asking you:

```
What does NetBox document for nokia? List its interfaces, IP addresses and VLANs.
```

**D.3.7** Compare NetBox with the real device:

```
Compare nokia's running configuration with NetBox and show me every difference.
```

**D.3.8** A good answer is a table of discrepancies, and a question: for each one,
which side is right? It won't change either side until you answer. Decide
item by item. Where nokia is right, NetBox is stale:

```
For every difference where nokia is right, update NetBox to match.
```

The agent proposes one changeset. **Apply these changes to NetBox?** shows
every field it will change, `current → new`, with the reason for each.
Nothing is written until you press `y`.

Where NetBox is right, nokia has drifted. Have the agent fix nokia
instead; that's a device change, with its own approval. Your
`interface-standards` skill settles one of them: the `ethernet-1/2`
description you found in Scenario 1. NetBox lists the trunk's VLANs, as the
standard says, so NetBox is right and nokia changes:

```
Where our interface standards say which side is right, follow them, and fix nokia.
```

**D.3.9** Check the result in the NetBox tab you opened (reload it): each change
is in **Operations → Change Log**, with the agent's reason as its message.

**D.3.10** Have the agent walk through it:

```
Explain what you changed in NetBox and why.
```

**D.3.11** Finish with a big one: audit the security of both devices. It
takes a few minutes:

```
Do a full security audit across both devices, give me a TLDR of what to focus on, and save the full report to security-audit.md.
```

**D.3.12** Tell us how it went:

```
/feedback
```

For example: *"Fixing NetBox drift with a reviewed changeset is exactly what
I need."* or *"I'd want it to connect to ___ next."*

<details>
<summary>Facilitator reference: what NetBox gets wrong</summary>

| Object | NetBox says | nokia has | Right side | Fix |
| --- | --- | --- | --- | --- |
| VLAN 130 name | `SECURITY` | `CAMERAS` (in its gateway's description) | nokia | update the VLAN in NetBox |
| lo1 | missing | `172.16.10.1/24`, "LAN: simulated site subnet" | nokia | create the interface and its address in NetBox |
| VLAN 120 gateway (`ethernet-1/2.120`) | `10.120.0.254/24` | `10.120.0.1/24` | nokia | update the address in NetBox |
| ethernet-1/2 description | `TRUNK: VLANs 110,120,130` | `TRUNK: to peer switch` | NetBox (the team standard: a trunk lists its VLANs) | set the description on nokia |

`just check-netbox` checks the first three. The fourth is there so the
agent has to ask, rather than assume the device always wins; the
`interface-standards` skill from Scenario 1 answers it, but either answer
passes the check. Everything else in NetBox matches nokia: the site `lab`, the
device and its platform, mgmt0, ethernet-1/1, lo0, the VLAN 110 and 130
subinterfaces, VLANs 110 and 120, and the other addresses. sonic isn't in
NetBox: attendees build it in Scenario 2.

</details>

### Scenario 4: choose your own adventure, layer 2

Done early? The second link between the devices, nokia's `ethernet-1/2` to
sonic's `Ethernet4`, is a layer 2 trunk. nokia already carries several
VLANs on it, each with a gateway address. sonic's end is at factory
defaults.

**The goal:** sonic reaches nokia's gateway in every VLAN, and nokia learns
sonic's address in each one. nokia needs no changes.

There are no prompts to copy this time: work it out with `stcli` in your own
words. Scenario 2's flow works here too: start fresh with `/clear`, test the
link and find out why it fails, see what nokia expects (NetBox documents
the VLANs too), review the sonic config before applying it, then test again.
The first ping in each VLAN may lose a packet while ARP resolves. Your
skill still applies: sonic's `Ethernet4` should end up described the way
the standard describes a trunk.

**D.4.1** When you think it's working, have `stcli` prove it:

```
From sonic, ping nokia's gateway in every VLAN on the trunk, and show me the ARP entries nokia learned for sonic.
```

Stuck? Ask a facilitator; the reference below has hints.

**D.4.2** Tell us how it went: `/feedback`.

### Start over

These run in a terminal outside `stcli`, for facilitators or anyone who
wants to go again.


**D.5.1** Wipe sonic back to blank in seconds, leaving nokia alone, then start again
from Scenario 2 (this also clears any layer 2 config and puts back the
off-standard descriptions). Your skill isn't touched; it lives in your
account, not on a device:

```sh
just reset-sonic
```

**D.5.2** Put NetBox back as it was seeded, drift included, to run Scenario 3
again (seconds; the devices are untouched):

```sh
just reset-netbox
```

**D.5.3** Or redeploy both devices from scratch:

```sh
just lab-up
```

**D.5.4** If the lab is stuck, tear everything down and start it again. NetBox keeps
its data:

```sh
just lab-down
just lab-up
```

<details>
<summary>Facilitator reference: what nokia has configured</summary>

| | nokia | sonic (target) |
| --- | --- | --- |
| BGP link | `ethernet-1/1.0`, `10.0.0.0/31`, AS 65001 | `Ethernet0`, `10.0.0.1/31`, AS 65002 |
| Advertised by nokia | `10.255.0.1/32` (lo0), `172.16.10.0/24` (lo1) | |
| Trunk | `ethernet-1/2`, VLANs 110 DATA, 120 VOICE, 130 CAMERAS | `Ethernet4`, a tagged member of VLANs 110, 120 and 130 |
| VLAN gateways | `ethernet-1/2.110/120/130`: `10.110.0.1/24`, `10.120.0.1/24`, `10.130.0.1/24` | `Vlan110/120/130`, an address in each, such as `10.110.0.2/24` |

On SONiC, `show` commands run as is; `config` commands need `sudo`. Ports
are `Ethernet0`, `Ethernet4` and so on; `just lab-up` already turned the two
lab ports on. Interfaces, addresses and VLANs are `sudo config ...`
(`config interface ip add Ethernet0 10.0.0.1/31`, `config vlan add 110`,
`config vlan member add 110 Ethernet4`, `config interface ip add Vlan110
10.110.0.2/24`). BGP is FRR, configured through `vtysh`.

sonic starts with two descriptions that break the team standard, for
Scenario 2's audit: `Ethernet0` reads `to nokia` (should be `BGP: eBGP peer
AS65001`) and `Ethernet8`, with nothing connected, reads `BGP: eBGP peer
AS65003` (should have none). This SONiC has no `config interface
description`; `show interfaces description` reads them, and a description is
a CONFIG_DB field: `sudo sonic-db-cli CONFIG_DB HSET "PORT|Ethernet0"
description "BGP: eBGP peer AS65001"`. Clear one by setting it to `""`;
deleting the field leaves the old text in `show`.

FRR exchanges no eBGP routes until a policy allows them
(`bgp ebgp-requires-policy`): the session comes up and shows `(Policy)`,
but `just check-bgp` fails until sonic installs `172.16.10.0/24`. Either `no
bgp ebgp-requires-policy` under `router bgp 65002` or a route-map on the
neighbor fixes it.

</details>

## E. Connect to the network

Other ways to connect, beyond the workshop's steps.

**E.1** Put both devices in one session, so one agent can work across them. Ask
`stcli` in plain language (the easiest way):

```
Can you please connect to oldprotocol@172.20.23.2 and oldprotocol@172.20.23.3?
```

**E.2** It asks before each connection; press **Enter** to confirm each one, then
type the password, `newbrain`. Or add devices yourself with `/add`, one per
line, which skips the confirmation:

```
/add oldprotocol@172.20.23.2
/add oldprotocol@172.20.23.3
```

`stcli oldprotocol@172.20.23.2 oldprotocol@172.20.23.3` is not the same thing: it opens each device in its own
tab, and every tab is a separate session with its own agent.

Every connection uses the lab login, `oldprotocol` / `newbrain`:
`oldprotocol@172.20.23.2` is nokia, `oldprotocol@172.20.23.3` is sonic.

For a device's native CLI outside `stcli`, run `just lab-cli nokia` or
`just lab-cli sonic`.

The two devices feel different once you're in:

- **nokia (SR Linux)** opens its own CLI. Changes go into a candidate
  configuration and take effect on `commit now`.
- **sonic (SONiC)** opens a Linux shell (bash on Debian), like a real
  SONiC switch. `show ...` reads; `sudo config ...` changes interfaces,
  addresses and VLANs, live as soon as it runs; routing is FRR, through
  `vtysh` (`vtysh -c "show ip bgp summary"`). Ports are `Ethernet0`,
  `Ethernet4` and so on, and `sudo config save -y` keeps changes across a
  restart of the switch.

## F. Use stcli

- **Ask in plain language:** "is BGP up between nokia and sonic?" One agent
  works across every device in the session, and each command it runs is
  labelled with the device it ran on.
- **Approvals.** Read-only commands run straight away. Anything that changes
  a device stops at **Approve this command?**, with the device named beside
  the command. Destructive commands also ask you to type a confirmation
  phrase.
- **Run a command yourself:** `!sonic show ip bgp summary`. With several
  devices in the session, name the device first; a bare `!` lists the names.
- **Manage devices:** `/disconnect sonic` closes one device;
  `/connect sonic` dials it again.
- **Start fresh:** `/clear` clears the conversation and keeps the connected
  devices.
- **Tabs are separate sessions.** Switch with
  `/switch`, `ctrl+←/→` or `alt+1..9`; a background tab shows `!` when it is
  waiting for your approval.

## G. NetBox

NetBox is the lab's source of truth (see Scenario 3). `just lab-up` starts
it on port 8000, and `stcli` connects to it with `/netbox connect`. NetBox
starts seeded with nokia as documented, drift included (see Scenario 3).
It keeps what you change, even across a `just lab-down`; `just
reset-netbox` puts it back as seeded. To start NetBox and the GitHub MCP proxy
without the devices, run `just netbox-up`.

- **Open it:** the recipe prints the URL. In a Codespace, that's the
  forwarded port 8000 (Ports tab → NetBox).
- **Log in:** `oldprotocol` / `newbrain`, the same as the devices.
- **API token:** `Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000`.
- **Share it:** the recipe makes port 8000 public when the Codespace allows
  it. Otherwise, in the Ports tab, right-click port 8000 and pick **Port
  Visibility → Public**. Anyone with the URL can then log in with the
  password above, so keep it to this disposable lab.

`just netbox-down` stops NetBox and deletes NetBox's
data; the next `just lab-up` seeds it again.

## H. Troubleshooting

- **`just lab-up` stops to build the SONiC image.** That's expected when
  the image isn't in the Codespace and can't be pulled: it downloads SONiC's
  official virtual switch and adds the lab login on top, once, in about 3
  minutes. The next `just lab-up` starts straight away.
- **Your Codespace is older than the README.** Commands or devices here
  that your lab doesn't have (`just --list` shows recipes, `just lab-up`
  names both devices) mean it was created from an older version. Update it,
  then start the lab again:

  ```sh
  git pull
  just lab-up
  ```

  `just lab-up` refreshes the SSH aliases from the checkout each time, so a
  pull is all it needs.
- **`ssh nokia` or `ssh sonic` fails in `just lab-verify`.** Reinstall the
  SSH aliases and key, then check again:

  ```sh
  ./scripts/install-ssh.sh
  just lab-verify
  ```
- **The BGP session is Established but `just check-bgp` still fails.** On
  sonic, FRR shows `(Policy)` and exchanges no routes until a policy allows
  them; see "Facilitator reference: what nokia has configured" under Start
  over.
- **Anything else stuck.** `just lab-down`, then `just lab-up`, rebuilds
  both devices from scratch; NetBox keeps its data.

## I. Finish

Delete the Codespace from GitHub's Codespaces page when finished to remove
its stored resources. Codespaces usage counts against your GitHub allowance.
