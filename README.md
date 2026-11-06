# AC6 workshop lab

A two-device network lab for working with `stcli`, running entirely in
GitHub Codespaces: one Nokia SR Linux router that's already configured, one
Arista cEOS switch that starts blank, and two links between them for you to
bring up.

For local Docker, follow [the local setup guide](README-docker-local.md).

```
      mgmt 172.20.23.2                                   mgmt 172.20.23.3
  ┌──────────────────────┐                           ┌──────────────────────┐
  │ nokia                │ e1-1          Ethernet1   │ arista               │
  │ Nokia SR Linux       │ ───────────────────────── │ Arista cEOS          │
  │ configured           │ 10.0.0.0/31   10.0.0.1/31 │ blank                │
  │                      │     layer 3: eBGP         │                      │
  │                      │                           │                      │
  │                      │ e1-2          Ethernet2   │                      │
  │                      │ ───────────────────────── │                      │
  └──────────────────────┘    layer 2: VLAN trunk    └──────────────────────┘
```

nokia's end of the BGP link is configured; arista's `10.0.0.1/31` is the
address the workshop gives it, since arista starts with no addresses on
either link. Connect to each device by its management IP.

## 1. Create a Codespace

Open this repository on GitHub and select **Code → Codespaces → Create
codespace on main**. The repository requires a **4-core / 16 GB RAM**
machine, so smaller machine types aren't offered.

Wait for automatic setup to finish. It installs the lab images, `just`, and
SSH configuration. The **GitHub Codespaces** terminal that opens
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

Start the lab (about 2 minutes):

```sh
just lab-up
```

Then check it:

```sh
just lab-verify
```

`lab-verify` checks the starting point: nokia
configured, arista blank, both links up, and SSH to both. It ends with **LAB
IS VERIFIED**, or **LAB VERIFICATION FAILED** with each failed check printed
in red above it.

## 4. Workshop exercises

Work through these in order, in one `stcli` session. Copy each prompt into
`stcli` as written. Every step builds on the answers before it, so don't open
a new tab partway through.

### Scenario 1: single device, basic queries and web search

**Explore the Nokia.** Start `stcli`:

```sh
stcli
```

The first time, it signs you in: open the verification link in your
computer's browser (the one-time code is already filled in) and wait for
**Signed in.** in the Codespace terminal. Credentials are saved in the
Codespace and refreshed automatically.

Connect to nokia by its management IP:

```
connect 172.20.23.2
```

Find the login config:

```
show me the config that controls the username and password on this box
```

Run a command directly on nokia, without the agent. Note the software
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

Audit the device:

```
Do a full security audit and give me a TLDR of what to focus on.
```

Then ask it whatever you want; be curious.

### Scenario 2: two devices, BGP

Stay in the same session, still connected only to nokia. nokia has a BGP
peer configured at `10.0.0.1`, but nothing in its config says what that peer
is.

Ping the peer across the BGP link. This should fail: the peer's end of the
link has no IP address yet. A good answer explains why rather than only
reporting the failure.

```
Ping the BGP peer at 10.0.0.1.
```

Generate the config for the other end. With only nokia in the session, the
agent should write it for Nokia SR Linux:

```
Generate a configuration snippet to configure BGP on a peer to this device.
```

The peer is actually an Arista. Convert the snippet:

```
Do it for Arista cEOS.
```

Connect to the Arista by its management IP, so both devices are in one
session:

```
/add 172.20.23.3
```

Apply the config. When the change stops at **Approve this command?**, check
that it names the Arista before you approve it:

```
Apply the Arista cEOS config to the device you just added.
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
IS UP** once the session is Established and arista has learned nokia's
prefixes:

```sh
just check-bgp
```

### Scenario 3: layer 2

Stay in the same session, with both devices connected. The second link,
nokia `ethernet-1/2` to the Arista's `Ethernet2`, is a layer 2 link: nokia
already treats it as a trunk carrying several VLANs, each with a gateway
address on nokia. The Arista's end is still at factory defaults.

Test the link. This should fail: the Arista isn't carrying any of nokia's
VLANs yet. A good answer works out which VLANs and gateways nokia has, tries
to reach them, and explains why it can't.

```
Test layer 2 connectivity between nokia's ethernet-1/2 and the Arista's Ethernet2.
```

Generate the config for both ends: nokia's existing trunk as the reference,
and the Arista side to match it, with an address in each VLAN so the Arista
can reach nokia's gateways:

```
Show me nokia's trunk and VLAN configuration on ethernet-1/2, then generate the matching Arista cEOS configuration for Ethernet2, with an address in each VLAN.
```

Apply it. When the change stops at **Approve this command?**, check that it
names the Arista before you approve it; nokia needs no changes:

```
Apply the Arista cEOS layer 2 config to the Arista.
```

Test again. A new VLAN spends about 30 seconds in spanning-tree listening and
learning before it forwards, so the first pings may fail; a good answer waits
and retries rather than changing more config:

```
Test layer 2 connectivity between the two devices again.
```

Confirm every VLAN is up, from both ends:

```
Confirm the Arista can reach nokia's gateway in every VLAN, and that nokia has learned the Arista's MAC address in each one.
```

Have the agent walk through it:

```
Explain what you did.
```

In a terminal outside `stcli`, this confirms the result. It ends with
**LAYER 2 IS UP** once the Arista reaches nokia's gateway in every VLAN:

```sh
just check-l2
```

### Start over

Wipe arista back to blank in seconds, leaving nokia alone, then start again
from Scenario 2:

```sh
just reset-arista
```

Or redeploy both devices from scratch:

```sh
just lab-up
```

<details>
<summary>Facilitator reference: what nokia has configured</summary>

| | nokia | arista (target) |
| --- | --- | --- |
| BGP link | `ethernet-1/1`, `10.0.0.0/31`, AS 65001 | `Ethernet1`, `10.0.0.1/31`, AS 65002 |
| Advertised by nokia | `10.255.0.1/32` (system0), `172.16.10.0/24` (lo0) | |
| Trunk | `ethernet-1/2`, VLANs 110 DATA, 120 VOICE, 130 CAMERAS | `Ethernet2`, trunk allowing 110, 120, 130 |
| VLAN gateways | `irb0.110/120/130`: `10.110.0.1/24`, `10.120.0.1/24`, `10.130.0.1/24` | an address in each VLAN, such as `10.110.0.2/24` |

arista starts with `no ip routing`: BGP still comes up, but arista doesn't
install the learned routes until `ip routing` is configured. `just check-l2`
pings from arista, so arista needs an address in each VLAN. On EOS, enter
`vlan 110` at the top level of config mode: typed under `router bgp`, it
opens an EVPN VLAN instead.

</details>

## 5. Connect to the network

Other ways to connect, beyond the workshop's steps.

Put both devices in one session, so one agent can work across them. Ask
`stcli` in plain language (the easiest way):

```
Can you please connect to nokia and arista?
```

It asks before each connection; press **Enter** to confirm each one. Or add
devices yourself with `/add`, one per line, which skips the confirmation:

```
/add nokia
/add arista
```

`stcli nokia arista` is not the same thing: it opens each device in its own
tab, and every tab is a separate session with its own agent.

Each device also answers on its management IP: `connect 172.20.23.2` for
nokia, `connect 172.20.23.3` for arista.

For a device's native CLI outside `stcli`, run `just lab-cli nokia` or
`just lab-cli arista`.

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
- **Tabs are separate sessions.** `/new <device>` opens one. Switch with
  `/switch`, `ctrl+←/→` or `alt+1..9`; a background tab shows `!` when it is
  waiting for your approval.

## 7. NetBox

```sh
just netbox-up
```

NetBox is where device data exported with `stcli` will land; that export
feature is still being built. This starts a NetBox on port 8000, separate
from the lab. The first start
takes two to three minutes. NetBox starts empty: no sites, device types or
devices.

- **Open it:** the recipe prints the URL. In a Codespace, that's the
  forwarded port 8000 (Ports tab → NetBox).
- **Log in:** `admin` / `ac6-workshop`.
- **API token:** `Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000`.
- **Share it:** the recipe makes port 8000 public when the Codespace allows
  it. Otherwise, in the Ports tab, right-click port 8000 and pick **Port
  Visibility → Public**. Anyone with the URL can then log in with the
  password above, so keep it to this disposable lab.

`just netbox-down` stops NetBox and deletes its data.

## 8. Finish

```sh
just netbox-down   # if you started NetBox
just lab-down
```

Delete the Codespace from GitHub's Codespaces page when finished to remove
its stored resources. Codespaces usage counts against your GitHub allowance.
