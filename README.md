# AC6 workshop lab

A six-node network lab for troubleshooting with `stcli`, running entirely
in GitHub Codespaces: four routers speaking eBGP and two Linux clients. Each
site has one router, SR Linux at JFK (`sw-jfk`) and Arista cEOS at IAD
(`sw-iad`), joined by two WAN routers, cEOS `rtr-phl` and SR Linux `rtr-ewr`.

For local Docker, follow [the local setup guide](README-docker-local.md).

![Routing topology](lab/diagrams/routing-topology.png)

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

`lab-up` takes about 2–5 minutes. `verify` ends with **LAB IS VERIFIED**; if
anything is unhealthy it ends with **LAB VERIFICATION FAILED** instead, with
each failed check printed in red above it.

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

Put every device in one session, so one agent can work across the whole
network. Start `stcli`, then ask it in plain language (the easiest way):

```
Can you please connect to sw-jfk sw-iad rtr-phl rtr-ewr client-jfk client-iad?
```

It asks before each connection; press **Enter** to confirm each one. Or add
devices yourself with `/add`, one per line, which skips the confirmation:

```
/add sw-jfk
```

A session holds up to 8 devices, so all six fit, and the tab title lists
them: `sw-jfk, sw-iad +4`.

`stcli sw-jfk sw-iad` is not the same thing: it opens each device in its own
tab, and every tab is a separate session with its own agent.

Devices: `sw-jfk`, `client-jfk`, `sw-iad`, `client-iad`, `rtr-phl`,
`rtr-ewr`. For a router's native CLI outside `stcli`, run
`just lab-cli rtr-phl`.

## 5. Use stcli

- **Ask in plain language:** "client-iad can't reach 192.168.11.0/24". One
  agent works across every device in the session, and each command it runs
  is labelled with the device it ran on.
- **Approvals.** Read-only commands run straight away. Anything that changes
  a device stops at **Approve this command?**, with the device named beside
  the command. Destructive commands also ask you to type a confirmation
  phrase.
- **Run a command yourself:** `!sw-iad show ip bgp summary`. With several
  devices in the session, name the device first; a bare `!` lists the names.
- **Manage devices:** `/disconnect rtr-ewr` closes one device;
  `/connect rtr-ewr` dials it again.
- **Tabs are separate sessions.** `/new <device>` opens one. Switch with
  `/switch`, `ctrl+←/→` or `alt+1..9`; a background tab shows `!` when it is
  waiting for your approval.

## 6. Troubleshooting scenarios

Break something, then ask `stcli` to find it. Each scenario has a matching
fix (`just fix <name>`) if you get stuck.

| Scenario | Break | What you'll notice |
| --- | --- | --- |
| BGP peer | `just break peer` | Everything still pings, but JFK has lost a WAN path |
| Missing prefix | `just break prefix` | client-jfk and client-iad can't reach each other |
| Route filter | `just break filter` | Everything still pings, but IAD reaches JFK over one path only |
| MTU | `just break mtu` | Small pings work, larger transfers fail |
| ICMP | `just break icmp` | client-jfk can't ping anything, yet traceroute works |

Describe the symptom, not the cause, and let the agent walk the network.

Fix one scenario before breaking the next, and run `just verify` after a fix
to confirm the network is healthy again. If things get tangled, `just lab-up`
redeploys every device from its original config.

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
