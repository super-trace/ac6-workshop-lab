# AC6 workshop lab

A six-node network lab for troubleshooting with `stcli`, running entirely
in GitHub Codespaces: four routers speaking eBGP and two Linux clients. Each
site has one router, SR Linux at JFK (`sw-jfk`) and Arista cEOS at IAD
(`sw-iad`), joined by two WAN routers, cEOS `rtr-phl` and SR Linux `rtr-ewr`.

For local Docker, follow [the local setup guide](README-docker-local.md).

> **Public launch:** This repository and `super-trace/stcli-releases` will both
> become public. At launch, update both READMEs, remove private-access requirements
> from the local-install instructions, and test downloads without GitHub login.

![Routing topology](lab/diagrams/routing-topology.png)

## 1. Create a Codespace

Open this repository on GitHub and select **Code → Codespaces → Create
codespace on main**. The repository requires a **4-core / 16 GB RAM**
machine, so smaller machine types aren't offered.

Wait for automatic setup to finish. It installs the lab images, `just`,
`stcli`, and SSH configuration. The **GitHub Codespaces** terminal that opens
first shows only a pointer to the creation log; to watch setup live, click
**+** in the terminal panel (or pick the **bash** terminal in the list). That
terminal follows setup step by step and says when it's done.

## 2. Start and verify

In the Codespace terminal:

```sh
just lab-up
just verify
```

Expect every BGP session to be Established and end-to-end client pings
to succeed. Check the output for SSH failures.

## 3. Sign in

```sh
stcli login
```

Open the verification link in your computer's browser (the one-time code is
already filled in) and wait for **Signed in.** in the Codespace terminal. Credentials are
saved in the Codespace and refreshed automatically.

## 4. Connect to the network

Put every device in one session, so one agent can work across the whole
network. Start `stcli` on one device:

```sh
stcli sw-jfk
```

Then, inside `stcli`, add the rest. `/add` joins a device to this session
without asking, one device per line:

```
/add sw-iad
/add rtr-phl
/add rtr-ewr
/add client-jfk
/add client-iad
```

A session holds up to 8 devices, so all six fit, and the tab title lists
them: `sw-jfk, sw-iad +4`.

Or let the agent do it: run `stcli` with no device and ask it to "connect to
sw-jfk, sw-iad, rtr-phl, rtr-ewr, client-jfk and client-iad in this session".
It asks before each connection; press **Enter** to confirm each one.

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
| Hidden path | `just break path` | IAD reaches JFK's clients over one path |
| BGP | `just break bgp` | JFK's client subnet disappears from the WAN |
| MTU | `just break mtu` | Small pings work, larger transfers fail |
| WAN | `just break wan` | Traffic still flows, redundancy doesn't |

Describe the symptom, not the cause, and let the agent walk the network.

## 7. NetBox

```sh
just netbox-up
```

This starts a NetBox on port 8000, separate from the lab. The first start
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
