# AC6 workshop lab

A two-device network lab for working with `stcli`, running entirely in
GitHub Codespaces: one Nokia SR Linux router that's already configured, one
Arista cEOS switch that starts blank, and two links between them for you to
bring up.

For local Docker, follow [the local setup guide](README-docker-local.md).

```
  ┌────────────────────┐   e1-1 ──── Ethernet1    ┌────────────────────┐
  │ nokia              │ ──────────────────────── │ arista             │
  │ Nokia SR Linux     │     layer 3: eBGP        │ Arista cEOS        │
  │ configured         │                          │ blank              │
  │                    │ ──────────────────────── │                    │
  └────────────────────┘   e1-2 ──── Ethernet2    └────────────────────┘
                           layer 2: VLAN trunk
```

## 1. Create a Codespace

Open this repository on GitHub and select **Code → Codespaces → Create
codespace on main**. The repository requires a **4-core / 16 GB RAM**
machine, so smaller machine types aren't offered.

Wait for automatic setup to finish. It installs the lab images, `just`, and
SSH configuration. The **GitHub Codespaces** terminal that opens
first shows only a pointer to the creation log; to watch setup live, click
**+** in the terminal panel (or pick the **bash** terminal in the list). That
terminal follows setup step by step and says when it's done.

## 2. Start and verify

In the Codespace terminal:

```sh
just lab-up
just verify
```

`lab-up` takes about 2 minutes. `verify` checks the starting point: nokia
configured, arista blank, both links up, and SSH to both. It ends with **LAB
IS VERIFIED**, or **LAB VERIFICATION FAILED** with each failed check printed
in red above it.

## 3. Install stcli and sign in

```sh
curl -fsSL https://raw.githubusercontent.com/super-trace/stcli-releases/main/install.sh | bash
stcli login
```

The installer puts `stcli` in `~/.local/bin`, which Codespace terminals
already have on their PATH. Until `stcli-releases` is public, the `curl`
download fails with a 404; install through your GitHub login instead:
`gh api repos/super-trace/stcli-releases/contents/install.sh --jq .content | base64 -d | bash`.

Open the verification link in your computer's browser (the one-time code is
already filled in) and wait for **Signed in.** in the Codespace terminal.
Credentials are saved in the Codespace and refreshed automatically.

## 4. Connect to the network

Put both devices in one session, so one agent can work across them. Start
`stcli`, then ask it in plain language (the easiest way):

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

For a device's native CLI outside `stcli`, run `just lab-cli nokia` or
`just lab-cli arista`.

## 5. Use stcli

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

## 6. Workshop exercises

Work through these in order, in one `stcli` session, typing each prompt as
written. Every step builds on the answers before it, so don't open a new tab
partway through.

### Explore the Nokia

Start a session on the Nokia with `stcli nokia`, then type:

- Show me the config that controls the username and password on this box.
- Show me routing on this device.
- Show me the configuration snippets behind the routing you just diagnosed.

The BGP peer toward arista shows as down: arista isn't configured yet.

### Bring up BGP

Stay in the same session and type:

- Generate a configuration snippet to configure BGP on a peer to this device, written for Nokia SR Linux.
- Convert that snippet to Arista cEOS.
- `/add arista`
- Configure arista using the cEOS snippet you converted earlier.
- Verify that BGP is up between nokia and arista.

`/add arista` brings arista into this session, so the agent still has both
snippets. When the change stops at **Approve this command?**, check that it
names **arista** before you approve it.

In a terminal outside `stcli`, `just check-bgp` confirms the result: it ends
with **BGP IS UP** once the session is Established and arista has learned
nokia's prefixes.

### Bring up layer 2

nokia's `ethernet-1/2` is a trunk carrying several VLANs, each with a gateway
address on nokia. arista's `Ethernet2` is still at factory defaults. In the
same session, type:

- nokia's ethernet-1/2 is a trunk with multiple VLANs. Figure out the trunking and VLANs, and configure arista so the two can talk over layer 2.
- Verify that arista can reach nokia's gateway in every VLAN.

`just check-l2` confirms the result: it ends with **LAYER 2 IS UP** once
arista reaches nokia's gateway in every VLAN. A new VLAN on arista spends
about 30 seconds in spanning-tree listening and learning before it forwards,
so give it a moment.

### Start over

`just reset-arista` wipes arista back to blank in seconds and leaves nokia
alone; start again from **Bring up BGP**. `just lab-up` redeploys both devices from
scratch.

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
