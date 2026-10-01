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

A 2-spine/2-leaf fabric: `isp1` (upstream) → `leaf1` → `spine1`/`spine2` →
`leaf2` → `host1` (customer LAN), with `leaf1` and `leaf2` full-meshed to
both spines for redundancy.

![AC6 workshop lab topology](lab/topology.clab.png)

This image is generated, not hand-drawn — `just lab-diagram` turns the real
`topology.clab.yml` into it via containerlab's own `graph --drawio` (through
the [clab-io-draw](https://github.com/srl-labs/clab-io-draw) project, which
supplies the router/switch/host icons) and
[rlespinasse/drawio-desktop-headless](https://github.com/rlespinasse/docker-drawio-desktop-headless)
to render a static PNG, since GitHub doesn't render `.drawio` natively. Run
it after any topology change — nothing keeps this image in sync
automatically. The source `lab/topology.clab.drawio` is also committed and
editable at [app.diagrams.net](https://app.diagrams.net) if you want to
touch it up by hand. Each node's position in the diagram comes from
`labels.graph-level`/`graph-icon` in `topology.clab.yml`, not from
containerlab itself — worth knowing if a node ever lands somewhere odd after
adding one.

For a quick, icon-free structural sanity check instead (does the real
topology still match what's documented, with no Docker image pulls beyond
what's already needed to run the lab), use `just lab-graph` — wraps
containerlab's `graph --dot`, needs `graphviz` locally
(`brew install graphviz`).

### Node roles

| Node | Role | Kind | stcli target? | Mgmt SSH port |
|---|---|---|---|---|
| `leaf1` | primary device attendees connect to; eBGP to `isp1` (AS 65010) | SR Linux | **yes** | 2401 |
| `leaf2` | second device; customer LAN to `host1` | SR Linux | **yes** | 2402 |
| `spine1`, `spine2` | fabric transit, pure OSPF, no BGP | SR Linux | no — `sr_cli` only | — |
| `isp1` | "the internet" — upstream eBGP peer, AS 65020 | FRRouting | no — `vtysh` only | — |
| `host1` | customer LAN traffic source/sink | plain Linux | no — shell only | — |

Both SR Linux credentials are `admin` / `NokiaSrl1!` (factory default).

`host1`'s subnet (`192.168.100.0/24`) is originated into OSPF by `leaf2` and
redistributed into BGP by `leaf1` via an **explicit allow-list**
(`routing-policy prefix-set advertised`), not a broad match-everything
policy — specifically so Scenario 1 can break *one* prefix's advertisement
with a single config line, not the whole BGP session. The route reaches
`leaf1` by crossing the fabric via OSPF (ECMP across both spines when
healthy), not via a static default route — unlike the old 4-node version of
this lab, there's no single "straight-line" path left to hang a static
route off of.

## Running it

**Prerequisites:** Docker (or OrbStack on macOS), `just`, and `sshpass`
(macOS: `brew install sshpass`) for `scripts/verify.sh`'s manual SSH check
only — not needed to actually use the lab with `stcli`.

```sh
just lab-setup   # pulls clab, srlinux, frr, network-multitool — all free/public
just lab-up      # deploys, then confirms every SR Linux node came up clean (see quirks below)
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

stcli leaf1
stcli leaf2
```

One device per stcli session — attendees open a second terminal tab for
`leaf2` when a scenario needs it (the OSPF fix, for instance, touches
`leaf1`, not `leaf2`).

## Scenarios

| # | Name | Pace | Break | Fix |
|---|---|---|---|---|
| 1 | BGP: a prefix stops being advertised | guided | `just break bgp` | `just fix bgp` |
| 2 | MTU: breaks some traffic, not all of it | self-serve | `just break mtu` | `just fix mtu` |
| 3 | OSPF: adjacency stuck at Two-Way | menu | `just break ospf` | `just fix ospf` |

### 1. BGP: a prefix stops being advertised (guided)

Removes `192.168.100.0/24` from `leaf1`'s export allow-list.

**Symptom:** `isp1`'s BGP table loses `192.168.100.0/24` (check with
`just lab-cli isp1` → `show ip bgp`); `10.0.0.2/32` (`leaf2`'s loopback)
stays advertised, since this is a single allow-list entry, not a
whole-policy or whole-session break. Diagnosable and fixable entirely from
`leaf1`.

### 2. MTU: breaks some traffic, not all of it (self-serve)

Raises `host1`'s own interface MTU to 9500, above what the WAN link
(`leaf2`'s `ethernet-1/1`, fixed at SR Linux's 1500 floor) can carry — "the
customer's device has jumbo frames misconfigured."

**Symptom:** `ping -s 200` succeeds, `ping -s 3000` silently vanishes — no
ICMP error, nothing wrong-looking in any routing table or adjacency on
either router. That's the point: the fault lives entirely on the customer's
own device, so there's nothing router-side to "discover" except by actually
testing different packet sizes end to end.

### 3. OSPF: a fabric link stuck at Two-Way (menu)

Removes the `interface-type point-to-point` override on `leaf1`'s side of
the `leaf1`↔`spine1` link — one of `leaf1`'s two fabric uplinks.

**Symptom:** that one adjacency never reaches Full; `show network-instance
default protocols ospf neighbor` on `leaf1` shows `ethernet-1/2.0` stuck at
`two-way` while `ethernet-1/3.0` (to `spine2`) stays `full`. SR Linux treats
the link as broadcast-type (needing DR/BDR election) without the override,
and on a true point-to-point veth with no real election outcome, it just
never finishes. Hit by accident during development, kept on purpose — it's
a classic, very real OSPF gotcha with zero error messages anywhere.

End-to-end reachability (`host1` → `isp1`) **survives this one** — traffic
just shifts entirely onto the `spine2` path. That's deliberate: in a
2-spine fabric, losing one path shouldn't be visible from a ping test, only
from actually checking both adjacencies. A good prompt for attendees to
notice this isn't "nothing is broken."

## Known SR Linux / containerlab quirks

Found and worked around while building this — documented here so the next
person debugging a "why did this just break" moment doesn't start from zero.

**Config checkpoints persist across `lab-down`/`lab-up`.** Containerlab
saves each SR Linux node's applied config to `lab/clab-ac6-workshop/<node>/`
and reuses it on redeploy instead of re-reading `startup-config` — by
design, so manual CLI changes survive a redeploy. If you've edited a
`configs/*.cfg` file, `just lab-down && just lab-up` **will not** pick up
the change; you need `rm -rf lab/clab-ac6-workshop` first.

**An SR Linux node's startup-config intermittently, silently failed to
apply — sometimes partially.** Confirmed repeatable at points during
development, independent of file content (isolated via a binary search:
identical lines succeeded reliably split across two smaller commits, failed
unpredictably as one big one), and independent of host memory pressure
(still happened on a freshly-freed machine). On the old 4-node version of
this lab it only ever hit `core1` (now `leaf2`), never `edge1` (now
`leaf1`) despite comparable config size; on the fabric version it also hit
`leaf1`, but only the *second half* of the file (BGP + routing-policy) —
interfaces and OSPF came up fine. Root cause not fully pinned down. Rather
than keep refining a detector for every way this can partially fail,
`just lab-up` now runs `scripts/heal-fabric.sh` after every deploy, which
unconditionally re-applies every SR Linux node's config in two commits —
`set` commands are idempotent, so reapplying something already correct is a
no-op, not an error.

**SR Linux's physical interface `mtu` and its logical subinterface's
`ip-mtu` are independent settings.** Raising only the physical interface's
`mtu` doesn't raise the MTU actually used for IP forwarding — you need both.
Changing `ip-mtu` live additionally left the subinterface stuck
`oper-state: down` in testing. This is why the MTU scenario lives on
`host1` (plain Linux, one reliable `ip link set mtu` call) instead of on
`leaf2`'s SR Linux interface — not worth the fragility when the same
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
