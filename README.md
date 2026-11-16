# Old Protocol New Brain | AC6 workshop lab

Slides: [supertrace.ai/ac6-deck](http://supertrace.ai/ac6-deck)

A two-device network lab for working with `stcli`, running entirely in
GitHub Codespaces: one Nokia SR Linux router that's already configured, one
SONiC switch that starts blank, and two links between them for you to bring
up.

For local Docker, follow [the local setup guide](README-docker-local.md).

## A. Create a Codespace

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/super-trace/ac6-workshop-lab?quickstart=1&geo=UsWest) <img src="images/arrow.svg" alt="" width="140">

Open the link above:
<https://codespaces.new/super-trace/ac6-workshop-lab?quickstart=1&geo=UsWest>.

It creates your Codespace from a prebuilt image, or reopens the one you
already have. The repository requires a **4-core / 16 GB RAM** machine, so
smaller machine types aren't offered.

✅ **You should see:** VS Code in your browser, with a terminal, in about a minute.

While it starts, here's the lab you'll work with:

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

- nokia's end of the BGP link is configured.
- sonic's `10.0.0.1/31` is the address the workshop gives it, since sonic
  starts with no addresses on either link.
- Connect to each device by its management IP.
- The credentials for nokia, sonic and NetBox are `oldprotocol:newbrain`.

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

## B. Install stcli

#### B.1

Once your Codespace is ready, install `stcli`, the same way as on
[cli.supertrace.ai](https://cli.supertrace.ai):

**In the terminal:**

```sh
curl -fsSL https://cli.supertrace.ai/install.sh | sh
```

✅ **You should see:** **ACTION REQUIRED: load stcli into your PATH**. That's the next step.

#### B.2

Reload your shell settings, so this terminal finds `stcli`:

**In the terminal:**

```sh
source ~/.bashrc
```

✅ **You should see:** no output. That's normal.

## C. Start and verify

#### C.1

Start the lab. It takes about 3 minutes, and also starts NetBox and readies
GitHub's MCP server, both for Scenario 3:

**In the terminal:**

```sh
just lab-up
```

✅ **You should see:** **Next: just lab-verify** at the end. Two yellow **WARN** lines about
nokia's hosts file are harmless.

> [!TIP]
> You can reset your lab at any time with `just lab-reset`. It tears both
> devices down and starts them again from scratch (the same as `just lab-down`
> then `just lab-up`). NetBox keeps its data. For smaller resets, see
> [E. Reset the lab](#e-reset-the-lab).

#### C.2

Check the lab:

**In the terminal:**

```sh
just lab-verify
```

✅ **You should see:** **LAB IS VERIFIED**, then an **Open NetBox** address. Open it in a
browser tab, ready for Scenario 3.

If it says **LAB VERIFICATION FAILED**, the failed checks are in red above
it; see [G. Troubleshooting](#g-troubleshooting).

`lab-verify` checks the starting point: nokia configured, sonic blank, both
links up, SSH to both, and NetBox and GitHub's MCP server answering.

#### C.3

Start `stcli` and sign in:

**In the terminal:**

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

✅ **You should see:** **Signed in.**, then `stcli`'s prompt. Leave it open: every box from
now on goes **in `stcli`**.

## D. Workshop exercises

Work through these in order, in one `stcli`. Copy each prompt into
`stcli` as written. Each scenario starts with `/clear`, which clears the
conversation but keeps your devices connected, so one scenario's answers
don't steer the next. Your skill and anything you ask `stcli` to remember
carry across, because they belong to your account, not the conversation.

A ping or other long-running command can be stopped with **Esc**.

Each scenario ends with `/feedback`: tell us what worked and what didn't, in
a sentence. We read every one.

---

### Scenario 1: one device, talk to your network

You'll connect to nokia, ask it questions in plain language, run commands
yourself, and teach `stcli` your team's standard.

#### D.1.1

Connect to nokia by its management IP, as the lab user:

**In `stcli`:**

```
connect oldprotocol@172.20.23.2
```

When it asks for the password, type **`newbrain`**.

✅ **You should see:** **platform set to Nokia SR Linux**.

#### D.1.2

Check that the AI agent never saw your password:

**In `stcli`:**

```
What password did I use to log in to nokia?
```

✅ **Expect something like:** "I don't know your password; it never reaches me."

`stcli` typed it to nokia from this machine: device credentials never leave
your Codespace.

#### D.1.3

Ask nokia about itself:

**In `stcli`:**

```
show me the config that controls the username and password on this box
```

✅ **Expect something like:** the `system aaa` config, with the `oldprotocol` user.

#### D.1.4

See what left the Codespace: open
[cli.supertrace.ai/app/usage](https://cli.supertrace.ai/app/usage), go to
**Sessions**, and open this session.

✅ **You should see:** the command and its output, with each password hash as `[redacted]`.

#### D.1.5

Run a command yourself, without the agent:

**In `stcli`:**

```
!show version
```

Then list nokia's interfaces and whether they're up:

**In `stcli`:**

```
!show interface brief
```

✅ **Expect something like:** `nokia`, `v25.3.2`; then `ethernet-1/1` and `ethernet-1/2` **up**.

#### D.1.6

Read the routing table:

**In `stcli`:**

```
Show me routing on this device.
```

✅ **Expect something like:** a list of routes, and BGP peer `10.0.0.1` **not Established**.
That's expected: sonic isn't configured yet.

#### D.1.7

Pull the config behind the routing:

**In `stcli`:**

```
Show me the configuration snippets behind the routing you just diagnosed.
```

✅ **Expect something like:** BGP in AS 65001, neighbor `10.0.0.1` in AS 65002.

#### D.1.8

Check nokia against the [team standards](#team-standards) your boss just
sent round. Copy the whole block, standard included, and paste it as one
message; the line breaks stay in the input until you press **Enter**:

**In `stcli`:**

```
My boss just added some team standards for interface descriptions:

Interface descriptions follow ROLE: detail, except VLAN gateways (below).
- Roles: BGP, TRUNK, LOOPBACK, LAN.
- A BGP link names its peer's AS: "BGP: eBGP peer AS65002".
- A trunk lists its VLANs: "TRUNK: VLANs 110,120,130".
- A loopback names its job: "LOOPBACK: router-id 10.255.0.1".
- A VLAN gateway reads "VLAN <id> <NAME> gateway": "VLAN 110 DATA gateway".
- Describe physical ports, loopbacks and VLAN gateways; other subinterfaces need none.
- A port with nothing connected has no description. Management ports are exempt.

Can you check my nokia and see if I'm in line? Show me a table of anything that isn't.
```

✅ **Expect something like:** one problem: `ethernet-1/2` reads `TRUNK: to peer switch`, but a
trunk should list its VLANs.

#### D.1.9

Fix it:

**In `stcli`:**

```
Fix the nokia.
```

✅ **Expect something like:** an approval dialog. Approve it, and `ethernet-1/2` reads `TRUNK:
VLANs 110,120,130`.

#### D.1.10

Before you move on, ask how to undo that:

**In `stcli`:**

```
How would I revert that if I needed to?
```

✅ **Expect something like:** commands that set the description back to `TRUNK: to peer switch`.

#### D.1.11

Tell `stcli` once to show rollback commands with every change; it remembers
across sessions:

**In `stcli`:**

```
From now on, whenever you propose a config change, include the commands to roll it back.
```

✅ **Expect something like:** "Saved to memory." It's listed on the dashboard's
[**Memory** page](https://cli.supertrace.ai/app/memory).

#### D.1.12

Save the standards as a skill, straight from this conversation, so every
device gets them:

**In `stcli`:**

```
Also, remember those standards as a skill called interface-standards. Use it whenever I configure, audit or document interfaces on any device, or compare a device with NetBox.
```

✅ **Expect something like:** a draft of the skill. Read it, then press `y` to save it.

It carries across `/clear`, and you can edit it on the dashboard's
[**Skills** page](https://cli.supertrace.ai/app/skills).

#### D.1.13

See your skill library:

**In `stcli`:**

```
/skills
```

✅ **You should see:** `interface-standards` in the list. Pick it to read it.

> [!TIP]
> **Memory or skill?** You've now made one of each.
>
> | | Memory (D.1.11) | Skill (D.1.12) |
> | --- | --- | --- |
> | What it is | A short fact or preference about you | A named playbook: instructions for a kind of task |
> | When it applies | Every conversation, always | When the task calls for it |
> | Size | A sentence | As long as the procedure needs |
> | Example | "Include rollback commands with every change" | Your team's interface standard |
> | Where to see it | [Memory page](https://cli.supertrace.ai/app/memory) | [Skills page](https://cli.supertrace.ai/app/skills) |
>
> Rule of thumb: if it's how *you* like to work, it's a memory. If it's how
> *a job* gets done, it's a skill.

#### D.1.14

Tell us how it went:

**In `stcli`:**

```
/feedback
```

For example: *"Turning our wiki standard into a skill took a minute."* or *"I
wanted ___ and it didn't."*

---

### Scenario 2: two devices, build, convert and apply

You'll build the config for nokia's BGP peer, convert it to another OS, add a
second device, and apply the change in one approval.

#### D.2.1

Start a fresh conversation:

**In `stcli`:**

```
/clear
```

✅ **You should see:** an empty conversation; nokia is still connected.

#### D.2.2

Ping the peer across the BGP link:

**In `stcli`:**

```
Ping the BGP peer at 10.0.0.1.
```

✅ **Expect something like:** the ping fails, because sonic's end of the link has no IP address
yet.

#### D.2.3

Generate the config for the other end:

**In `stcli`:**

```
Generate a configuration snippet to configure BGP on a peer to this device.
```

✅ **Expect something like:** an SR Linux snippet. With only nokia in the session, the agent
assumes the peer is the same kind of device.

#### D.2.4

The peer is actually a SONiC switch. Convert the snippet, and keep a copy:

**In `stcli`:**

```
Do it for SONiC and save it to sonic-bgp.conf. The peer's port is Ethernet0, and its router ID is 10.255.0.2 on Loopback0, which it advertises.
```

✅ **Expect something like:** a dialog showing the whole file. Approve it, then open
`sonic-bgp.conf` in the Codespace's file explorer.

#### D.2.5

Add the SONiC switch to the session, by name this time, the way you'd type
`ssh sonic`:

**In `stcli`:**

```
/add sonic
```

✅ **You should see:** **platform set to SONiC**, with no password asked.

In D.1.1 you typed an IP and a password. This time `stcli` read your
`~/.ssh/config`, the same file `ssh` does: the lab's entry for `sonic` names
its address, user and SSH key, so if `ssh sonic` works in your terminal, it
works in `stcli`. Your own aliases, keys and jump hosts carry over the same
way.

<details>
<summary>What <code>sonic</code> means in the lab's SSH config</summary>

```
Host sonic
    HostName 127.0.0.1
    Port 2402
    User oldprotocol
    IdentityFile ~/.ssh/ac6-workshop-key
```

`127.0.0.1:2402` is the Codespace's forwarded port to sonic's SSH. `just
lab-up` installs this in `~/.ssh/config` for you. On your own machine, it's
the same shape with your device's address and your key.

</details>

#### D.2.6

Apply the config you saved in D.2.4:

**In `stcli`:**

```
Apply sonic-bgp.conf to sonic, in order.
```

✅ **Expect something like:** **Approve batch** with every command in order. Check it names
**sonic**, then approve. Rollback commands follow the result.

#### D.2.7

Check the session:

**In `stcli`:**

```
Ping the BGP peer at 10.0.0.1 again, and verify that BGP is up.
```

✅ **Expect something like:** the ping succeeds, and BGP is **Established**.

#### D.2.8

Audit sonic's port descriptions; someone has been labelling them by hand:

**In `stcli`:**

```
Does sonic follow our interface standards? Show me a table of anything that doesn't.
```

You don't name the skill: the agent picks it up because the question is
about interface standards. It's the same standard you set on nokia, now on
a different vendor's switch.

✅ **Expect something like:** `Ethernet8` flagged (it names a BGP peer, but nothing is connected),
and maybe `Ethernet0` (`to nokia`). If it flags `Ethernet4`, leave it:
Scenario 4 configures it.

#### D.2.9

Fix them, and prove it:

**In `stcli`:**

```
Fix those, and check that sonic now follows our interface standards.
```

✅ **Expect something like:** an approval. Afterwards, `Ethernet0` reads `BGP: eBGP peer AS65001`
and `Ethernet8` has no description.

#### D.2.10

Everything you just did is on the record. Open the dashboard at
[cli.supertrace.ai/app](https://cli.supertrace.ai/app), go to **Usage →
Sessions**, and open this session.

✅ **You should see:** every command, the device it ran on, and who approved it.

#### D.2.11

Tell us how it went:

**In `stcli`:**

```
/feedback
```

For example: *"Converting the config to SONiC saved me real time."* or *"The
approvals felt ___."*

---

### Scenario 3: plug in the tools you already use

You'll give `stcli` the tools you already use: the web, GitHub over MCP, and
NetBox, your source of truth, which it reads and fixes.

#### D.3.1

Start a fresh conversation:

**In `stcli`:**

```
/clear
```

✅ **You should see:** an empty conversation; both devices are still connected.

#### D.3.2

Start with the biggest tool there is, the web. Check both devices' software
for anything you should patch:

**In `stcli`:**

```
Search the web for any recent patches or security advisories for the software versions on nokia and sonic that I should be aware of.
```

✅ **Expect something like:** a short list of advisories for SR Linux `v25.3.2` and SONiC
`202511`, with links.

#### D.3.3

Plug GitHub in. MCP is how `stcli` uses tools beyond your devices, and
GitHub runs an MCP server. `just lab-up` already set it up for you, signed in
with your Codespace's GitHub account, so there's no token to paste:

**In `stcli`:**

```
/mcp add github http://localhost:8002/mcp/readonly
```

✅ **Expect something like:** `github` added.

#### D.3.4

Check it's there:

**In `stcli`:**

```
/mcp list
```

✅ **You should see:** `github` in the list.

#### D.3.5

Ask GitHub why FRR, the routing daemon sonic runs, exchanges no eBGP routes
until a policy allows them:

**In `stcli`:**

```
Search the FRRouting/frr GitHub issues for ebgp-requires-policy. Why does eBGP exchange no routes until a policy allows them?
```

✅ **Expect something like:** a confirm dialog before each GitHub call (press `y`), then an answer
citing the issues it read.

#### D.3.6

Now NetBox, the lab's source of truth. Like every real NetBox, it has
drifted from the network; the agent will find where and fix it.

First, open the NetBox tab from C.2 and log in as `oldprotocol:newbrain`.
Look at **Devices → nokia**, and keep the tab open to watch it change.

<details>
<summary>Lost the NetBox tab?</summary>

Use the **Open NetBox** address `just lab-verify` printed. Or, in the
Codespace's **Ports** tab, hover over port **8000 (NetBox)** and click the
globe icon (**Open in Browser**).

</details>

Then connect `stcli` to NetBox:

**In `stcli`:**

```
/netbox connect http://localhost:8000
```

When it asks for the API token, paste the lab's token:

```
nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000
```

✅ **Expect something like:** connected to NetBox.

The token stays in the Codespace, like your SSH password: `stcli` never
sends it to the agent.

#### D.3.7

Ask what NetBox knows. Reads from NetBox run without asking you:

**In `stcli`:**

```
What does NetBox document about our network? List every site, device, interface, IP address and VLAN. Is anything we're connected to missing?
```

✅ **Expect something like:** the site `lab` and nokia, and "sonic isn't in NetBox."

#### D.3.8

Compare NetBox with the real device:

**In `stcli`:**

```
Compare nokia's running configuration with NetBox and show me every difference.
```

✅ **Expect something like:** a table of differences, and "Which side is right?"

#### D.3.9

Here the device is the source of truth, so NetBox is what's stale. Tell it:

**In `stcli`:**

```
nokia is right on every difference. Update NetBox to match, but keep NetBox's interface layout: put addresses on the interfaces NetBox already has, and leave out ports with nothing connected.
```

✅ **Expect something like:** **Apply these changes to NetBox?**, with each field as `current →
new`. Press `y` to apply.

One of the changes is your own work: the `ethernet-1/2` description you
fixed in Scenario 1. nokia follows the standard now, and NetBox still has
the old text, so NetBox changes.

#### D.3.10

Now document sonic, from the switch itself:

**In `stcli`:**

```
Now add sonic to NetBox the way it's configured right now: the device, its connected interfaces and their IP addresses.
```

✅ **Expect something like:** two approvals, then sonic under **Devices** when you reload the
NetBox tab.

Each change is in NetBox's **Operations → Change Log**, with the agent's
reason as its message.

#### D.3.11

One standard, two vendors, and your source of truth. Check them all at once:

**In `stcli`:**

```
Check nokia, sonic and NetBox against our interface standards, and fix anything that doesn't follow them.
```

✅ **Expect something like:** little left to fix. If it asks about sonic's `Ethernet4`, leave it.

#### D.3.12

Have the agent walk through it:

**In `stcli`:**

```
Explain what you changed in NetBox and why.
```

✅ **Expect something like:** a short list of each change and why.

#### D.3.13

Finish with a big one: audit the security of both devices. It takes a few
minutes:

**In `stcli`:**

```
Do a full security audit across both devices, give me a TLDR of what to focus on, and save the full report to security-audit.md.
```

✅ **Expect something like:** a short TLDR, and `security-audit.md` in the file explorer.

#### D.3.14

Tell us how it went:

**In `stcli`:**

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
| lo1 | missing | `172.16.10.1/24`, "LOOPBACK: simulated site subnet 172.16.10.0/24" | nokia | create the interface and its address in NetBox |
| VLAN 120 gateway (`ethernet-1/2.120`) | `10.120.0.254/24` | `10.120.0.1/24` | nokia | update the address in NetBox |
| ethernet-1/2 description | `TRUNK: to peer switch` | `TRUNK: VLANs 110,120,130` (fixed in D.1.9) | nokia | update the description in NetBox |

`just check-netbox` checks all four. The fourth only shows up if attendees
fixed nokia in D.1.9; NetBox is seeded with nokia's original, off-standard
description. Anyone who skipped D.1.9 sees no difference there, and the
check fails until nokia and NetBox both read `TRUNK: VLANs 110,120,130`.
Everything else in NetBox matches nokia: the site `lab`, the device and its
platform, mgmt0, ethernet-1/1, lo0, the VLAN 110 and 130 subinterfaces,
VLANs 110 and 120, and the other addresses. sonic isn't in NetBox:
attendees add it in D.3.10. The seed has what that needs ready: a SONiC
manufacturer, device type and platform, and a `switch` role.

</details>

<details>
<summary>Facilitator reference: NetBox</summary>

- **API token:** `Authorization: Bearer nbt_ac6workshop0.ac6workshopnetboxapitoken000000000000000`.
- **Share it:** `just lab-up` makes port 8000 public when the Codespace
  allows it. Otherwise, in the Ports tab, right-click port 8000 and pick
  **Port Visibility → Public**. Anyone with the URL can then log in with the
  lab login, so keep it to this disposable lab.
- **Without the devices:** `just netbox-up` starts NetBox and the GitHub
  MCP proxy on their own.
- **Delete its data:** `just netbox-down` stops NetBox and deletes what's in
  it; the next `just lab-up` seeds it again. (`just lab-reset-netbox` does
  both in one step.)

</details>

---

### Scenario 4: choose your own adventure, layer 2

Done early? The second link between the devices, nokia's `ethernet-1/2` to
sonic's `Ethernet4`, is a layer 2 trunk. nokia already carries several
VLANs on it, each with a gateway address. sonic's end is at factory
defaults.

**The goal:** sonic reaches nokia's gateway in every VLAN, and nokia learns
sonic's address in each one. sonic needs an address in each VLAN, such as
`.2`. nokia needs no changes.

There are no prompts to copy this time: work it out with `stcli` in your own
words. Scenario 2's flow works here too: start fresh with `/clear`, test the
link and find out why it fails, see what nokia expects (NetBox documents
the VLANs too), review the sonic config before applying it, then test again.
The first ping in each VLAN may lose a packet while ARP resolves. Your
skill still applies: sonic's `Ethernet4` should end up described the way
the standard describes a trunk.

#### D.4.1

When you think it's working, have `stcli` prove it:

**In `stcli`:**

```
From sonic, ping nokia's gateway in every VLAN on the trunk, and show me the ARP entries nokia learned for sonic.
```

✅ **Expect something like:** replies from `10.110.0.1`, `10.120.0.1` and `10.130.0.1`, and an
ARP entry for sonic in each VLAN.

Stuck? Ask a facilitator; the reference in
[E. Reset the lab](#e-reset-the-lab) has hints.

#### D.4.2

Tell us how it went:

**In `stcli`:**

```
/feedback
```

## E. Reset the lab

These run in a terminal outside `stcli`, for facilitators or anyone who
wants to go again.

#### E.1

Reset the whole lab: both devices are torn down and redeployed from scratch
(about 3 minutes). NetBox keeps its data:

**In the terminal:**

```sh
just lab-reset
```

#### E.2

`lab-reset` is the two commands below in one step. `lab-down` stops both
devices and NetBox; nothing works again until `lab-up`:

**In the terminal:**

```sh
just lab-down
just lab-up
```

#### E.3

Or reset one part in seconds, leaving the rest alone. Your skills and
memories aren't touched; they live in your account, not on a device.

Put nokia back to its starting config, removing anything added since:

**In the terminal:**

```sh
just lab-reset-nokia
```

Wipe sonic back to blank, then start again from Scenario 2 (this also
clears any layer 2 config and puts back the off-standard descriptions):

**In the terminal:**

```sh
just lab-reset-sonic
```

Put NetBox back as it was seeded, drift included, to run Scenario 3 again:

**In the terminal:**

```sh
just lab-reset-netbox
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

## F. How to use stcli

Everything here works in any session, beyond the workshop's steps.

- **Ask in plain language:** "is BGP up between nokia and sonic?" One agent
  works across every device in the session, and each command it runs is
  labelled with the device it ran on.
- **Approvals.** Read-only commands run straight away. Anything that changes
  a device stops at **Approval needed**, with the device named beside
  the command; a change of several commands asks once, as **Approve batch**.
  Destructive commands always ask on their own, with a typed confirmation
  phrase.
- **Run a command yourself:** `!oldprotocol@sonic show ip bgp summary`. With
  several devices in the session, name the device first; a bare `!` lists
  the names.
- **One `stcli`, one session.** For a second session, run a second `stcli` in
  another terminal.

### Commands

Type `/help` in `stcli` for the same list, plus the keyboard shortcuts.

| Command | What it does |
| --- | --- |
| `/help` (`/h`) | Lists every command and key. |
| `/new [device]` (`/n`) | Starts a brand-new session with no devices, and connects to `device` if you give one. |
| `/clear` | Starts a fresh conversation; the connected devices stay. |
| `/add <device>` | Adds a device to this session, without asking first. |
| `/connect [device]` (`/c`) | Connects a device to this session, or reconnects one that dropped. |
| `/disconnect [name]` | Closes one device's connection; `/connect` brings it back. |
| `/sessions` | Picks a past session to resume. |
| `/skills` | Lists your skills; shows or deletes one. |
| `/mcp` | Lists, adds or removes MCP servers, such as GitHub's. |
| `/netbox` | Connects, shows or disconnects NetBox. |
| `/copy` | Copies the agent's last reply. |
| `/usage` (`/credits`) | Shows your remaining credits, and your spend and tokens over 30 days. |
| `/config [key=value]` | Opens the settings, or changes one. |
| `/feedback <message>` | Sends feedback about `stcli` to the Supertrace team. |
| `/quit` (`/q`) | Leaves `stcli`. |

### Connect to devices

#### F.1

Put both devices in one session, so one agent can work across them. Ask
`stcli` in plain language (the easiest way):

**In `stcli`:**

```
Can you please connect to oldprotocol@172.20.23.2 and oldprotocol@172.20.23.3?
```

#### F.2

It asks before each connection; press **Enter** to confirm each one, then
type the password, `newbrain`. Or add devices yourself with `/add`, one per
line, which skips the confirmation:

**In `stcli`:**

```
/add oldprotocol@172.20.23.2
/add oldprotocol@172.20.23.3
```

`stcli oldprotocol@172.20.23.2 oldprotocol@172.20.23.3`, in the terminal,
does the same: both devices join one session.

Every connection uses the lab login, `oldprotocol:newbrain`:
`oldprotocol@172.20.23.2` is nokia, `oldprotocol@172.20.23.3` is sonic.

For a device's native CLI outside `stcli`, run `just lab-cli nokia` or
`just lab-cli sonic` in the terminal.

The two devices feel different once you're in:

- **nokia (SR Linux)** opens its own CLI. Changes go into a candidate
  configuration and take effect on `commit now`.
- **sonic (SONiC)** opens a Linux shell (bash on Debian), like a real
  SONiC switch. `show ...` reads; `sudo config ...` changes interfaces,
  addresses and VLANs, live as soon as it runs; routing is FRR, through
  `vtysh` (`vtysh -c "show ip bgp summary"`). Ports are `Ethernet0`,
  `Ethernet4` and so on, and `sudo config save -y` keeps changes across a
  restart of the switch.

## G. Troubleshooting

All of these run in the terminal, outside `stcli`.

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
  them; see "Facilitator reference: what nokia has configured" under
  [E. Reset the lab](#e-reset-the-lab).
- **Anything else stuck.** `just lab-reset` (`lab-down`, then `lab-up`)
  rebuilds both devices from scratch; NetBox keeps its data.

## H. Finish

Delete the Codespace from GitHub's Codespaces page when finished to remove
its stored resources. Codespaces usage counts against your GitHub allowance.
