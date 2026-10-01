# AC6 workshop lab — "Old Protocol, New Brain"

The containerlab environment for the AC6 workshop spec
(`../../specs/conferences/ac6-workshop-submission.md`): every attendee gets
their own copy of this lab, connects to it with `stcli`, and troubleshoots a
BGP fault (guided) and an MTU fault (self-serve), with a small menu of extra
faults for the "choose your own" segment.

## Contents

- [Why SR Linux + FRRouting](#why-sr-linux--frrouting-not-junoscrpd-or-aristaceos)
- [Topology](#topology)
- [Running it](#running-it)
- [Connecting with stcli](#connecting-with-stcli)
- [Scenarios](#scenarios)
- [Known SR Linux / containerlab quirks](#known-sr-linux--containerlab-quirks)
- [Codespaces](#codespaces)

## Why SR Linux + FRRouting, not Junos/cRPD or Arista/cEOS

This has to work for an unknown number of strangers spinning up their own
environment with no sales process and no account beyond a free one on
`ssh.supertrace.ai`. That ruled out the platforms used in this org's other
labs:

- **Juniper cRPD** needs a license to run BGP or ISIS at all — confirmed
  directly (`Idle (LicenseFailure)`, zero packets exchanged) while building
  the sibling `stcli-3node-lab` repo. Not something a workshop attendee can
  get themselves.
- **Arista cEOS** needs a licensed tar file from Arista's site, imported
  locally per machine. Same problem, worse at scale.

**SR Linux** is a genuinely native container, pullable from a public
registry with no account. **FRRouting** is Apache-2.0, plays the "upstream
ISP" (`isp1`) for the BGP scenario. Both are free, both are fast to boot, and
neither needs anything attendees don't already have.

## Topology

```
  isp1 — FRRouting, AS 65020 ("the internet")              not an stcli target
  lo 203.0.113.1, originates 198.51.100.0/24                docker exec / vtysh only
       │
       │   eBGP — AS 65010 ↔ AS 65020
       │   203.0.113.0/31
       ▼
  edge1 — SR Linux, AS 65010                                stcli target #1
  lo 10.0.0.1 — Scenario 1 (BGP) lives here                  ssh -p 2401, admin/NokiaSrl1!
       │
       │   OSPF area 0.0.0.0
       │   10.1.1.0/31
       ▼
  core1 — SR Linux, AS 65010                                stcli target #2
  lo 10.0.0.2 — Scenario 3 (OSPF) lives here                 ssh -p 2402, admin/NokiaSrl1!
       │
       │   customer LAN
       │   192.168.100.0/24
       ▼
  host1 — plain Linux                                       not an stcli target
  192.168.100.10 — Scenario 2 (MTU) lives here                docker exec only
```

| Node | Role | Kind | stcli target? | Mgmt SSH port |
|---|---|---|---|---|
| `edge1` | primary device attendees connect to; eBGP to `isp1` | SR Linux | **yes** | 2401 |
| `core1` | second device; OSPF to `edge1`, customer LAN to `host1` | SR Linux | **yes** | 2402 |
| `isp1` | "the internet" — upstream eBGP peer, AS 65020 | FRRouting | no — `vtysh` only | — |
| `host1` | customer LAN traffic source/sink | plain Linux | no — shell only | — |

`host1`'s subnet (`192.168.100.0/24`) is originated into OSPF by `core1` and
redistributed into BGP by `edge1` via an **explicit allow-list**
(`routing-policy prefix-set advertised`), not a broad match-everything
policy — specifically so Scenario 1 can break *one* prefix's advertisement
with a single config line, not the whole BGP session.

## Running it

**Prerequisites:** Docker (or OrbStack on macOS), `just`, and `sshpass`
(macOS: `brew install sshpass`) for `scripts/verify.sh`'s manual SSH check
only — not needed to actually use the lab with `stcli`.

```sh
just lab-setup   # pulls clab, srlinux, frr, network-multitool — all free/public
just lab-up      # deploys, then confirms core1 came up clean (see quirks below)
just verify
```

Tear down and start clean with `just lab-down && rm -rf lab/clab-ac6-workshop
&& just lab-up` any time something looks wrong — see the quirks section below
for why the `rm -rf` matters.

`just lab-cli <node>` drops into the native CLI (`sr_cli` / `vtysh` / `sh`)
for direct troubleshooting, independent of stcli. Default credentials:
`admin` / `NokiaSrl1!` on both SR Linux nodes (factory default, never
overridden).

## Connecting with stcli

```sh
stcli login   # one-time, real backend — nothing to stand up locally

# add to ~/.ssh/config:
Include /path/to/this/repo/lab/ssh_config

stcli edge1
stcli core1
```

One device per stcli session — attendees open a second terminal tab for
`core1` when a scenario needs it (the OSPF fix, for instance, touches
`core1`, not `edge1`).

## Scenarios

| # | Name | Pace | Break | Fix |
|---|---|---|---|---|
| 1 | BGP: a prefix stops being advertised | guided | `just break bgp` | `just fix bgp` |
| 2 | MTU: breaks some traffic, not all of it | self-serve | `just break mtu` | `just fix mtu` |
| 3 | OSPF: adjacency stuck at Two-Way | menu | `just break ospf` | `just fix ospf` |

### 1. BGP: a prefix stops being advertised (guided)

Removes `192.168.100.0/24` from `edge1`'s export allow-list.

**Symptom:** `isp1`'s BGP table loses `192.168.100.0/24` (check with
`just lab-cli isp1` → `show ip bgp`); `10.0.0.2/32` (`core1`'s loopback)
stays advertised, since this is a single allow-list entry, not a
whole-policy or whole-session break. Diagnosable and fixable entirely from
`edge1`.

### 2. MTU: breaks some traffic, not all of it (self-serve)

Raises `host1`'s own interface MTU to 9500, above what the WAN link
(`core1`'s `ethernet-1/2`, fixed at SR Linux's 1500 floor) can carry — "the
customer's device has jumbo frames misconfigured."

**Symptom:** `ping -s 200` succeeds, `ping -s 3000` silently vanishes — no
ICMP error, nothing wrong-looking in any routing table or adjacency on
either router. That's the point: the fault lives entirely on the customer's
own device, so there's nothing router-side to "discover" except by actually
testing different packet sizes end to end.

### 3. OSPF: adjacency stuck at Two-Way (menu)

Removes the `interface-type point-to-point` override on `edge1`'s side of
the `edge1`↔`core1` link.

**Symptom:** the adjacency never reaches Full; `show network-instance
default protocols ospf neighbor` shows `two-way` indefinitely. SR Linux
treats the link as broadcast-type (needing DR/BDR election) without the
override, and on a true point-to-point veth with no real election outcome,
it just never finishes. Hit by accident during development, kept on purpose
— it's a classic, very real OSPF gotcha with zero error messages anywhere.

## Known SR Linux / containerlab quirks

Found and worked around while building this — documented here so the next
person debugging a "why did this just break" moment doesn't start from zero.

**Config checkpoints persist across `lab-down`/`lab-up`.** Containerlab
saves each SR Linux node's applied config to `lab/clab-ac6-workshop/<node>/`
and reuses it on redeploy instead of re-reading `startup-config` — by
design, so manual CLI changes survive a redeploy. If you've edited a
`configs/*.cfg` file, `just lab-down && just lab-up` **will not** pick up
the change; you need `rm -rf lab/clab-ac6-workshop` first.

**`core1`'s startup-config intermittently, silently failed to apply** —
confirmed repeatable at points during development, independent of file
content (isolated via a binary search: identical lines succeeded reliably
split across two smaller commits, failed unpredictably as one big one), and
independent of host memory pressure (still happened on a freshly-freed
machine). `edge1`'s comparably-sized startup-config never showed this.
Root cause not fully pinned down. `just lab-up` now runs
`scripts/heal-core1.sh` after every deploy, which detects the symptom
(`network-instance default` missing) and re-applies in two commits if
needed — a fast no-op the common case, when nothing's wrong.

**SR Linux's physical interface `mtu` and its logical subinterface's
`ip-mtu` are independent settings.** Raising only the physical interface's
`mtu` doesn't raise the MTU actually used for IP forwarding — you need both.
Changing `ip-mtu` live additionally left the subinterface stuck
`oper-state: down` in testing. This is why the MTU scenario lives on
`host1` (plain Linux, one reliable `ip link set mtu` call) instead of on
`core1`'s SR Linux interface — not worth the fragility when the same
mismatch is trivially reproducible from the other end of the link.

**FRR's RFC 8212 enforcement silently discards all routes on a "naked" eBGP
session.** `bgp ebgp-requires-policy` is on by default; without an explicit
route-map in both directions, FRR accepts the session but drops every
route, in both directions, with no error — `isp1`'s `frr.conf` disables it
explicitly (`no bgp ebgp-requires-policy`).

**SR Linux's OSPF `match protocol` value is `ospfv2`, not `ospf`** in
routing-policy statements — an easy typo that fails the whole startup-config
commit with a (for once, actually helpful) parsing error.

## Codespaces

`.devcontainer/` brings up Docker-in-Docker and installs `just` — nothing
proprietary needed (unlike `stcli-3node-lab`), so there's no licensed binary
to fetch from a release asset. Forward ports 2401/2402 to run `stcli`
locally against a Codespace-hosted lab.
