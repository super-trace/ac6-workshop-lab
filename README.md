# AC6 workshop lab — "Old Protocol, New Brain"

The containerlab environment for the AC6 workshop spec
(`../../specs/conferences/ac6-workshop-submission.md`): every attendee gets
their own copy of this lab, connects to it with `stcli`, and troubleshoots a
BGP fault (guided) and an MTU fault (self-serve), with a small menu of extra
faults for the "choose your own" segment.

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
host1 (customer LAN, 192.168.100.0/24)
  |
core1 (SR Linux) --- OSPF, MTU scenario ---  edge1 (SR Linux) --- eBGP --- isp1 (FRRouting, AS 65020)
```

| Node | Role | Kind | stcli target? | Mgmt SSH port |
|---|---|---|---|---|
| edge1 | primary device attendees connect to | SR Linux | yes | 2401 |
| core1 | second device, OSPF + MTU scenario | SR Linux | yes | 2402 |
| isp1 | "the internet" — upstream eBGP peer | FRRouting | no (docker exec only) | — |
| host1 | customer LAN traffic source | Linux | no (docker exec only) | — |

AS 65010 (edge1/core1 side) eBGP to AS 65020 (isp1). OSPF area 0.0.0.0
between edge1 and core1. `host1`'s subnet (192.168.100.0/24) is originated
into OSPF by core1 and redistributed into BGP by edge1 via an explicit
allow-list (`routing-policy prefix-set advertised`) — not a broad
match-everything policy, specifically so the BGP scenario can break *one*
prefix's advertisement with a single config line, not the whole session.

## Running it

```sh
just lab-setup   # pulls clab, srlinux, frr, network-multitool — all free/public
just lab-up      # deploys, then applies the MTU scenario's healthy baseline
just verify
```

`just lab-up` runs `scripts/fix-mtu.sh` as a separate step after the lab
settles, not via containerlab's own startup-config or `exec:` mechanisms —
doing it either of those ways raced with SR Linux's own boot-time config
application and intermittently corrupted core1's entire config (confirmed
during development, independent of what the MTU line itself said). If
`just verify` ever shows `network-instance default` missing from a node,
that's the same failure mode — a straight `just lab-down && just lab-up`
clears it.

**A real finding from building this, not a hypothetical:** that corruption
got dramatically worse under host memory pressure. If `just lab-up` or
`just verify` are flaky, check `docker stats` and whatever else is running
on the same machine before assuming the lab itself is broken — this is a
small, light lab (2 SRL + 1 FRR + 1 plain Linux container), but SR Linux's
management process genuinely needs headroom to initialize cleanly.

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
`core1` when a scenario needs it (the MTU fix, for instance, touches core1,
not edge1).

## Scenarios

### 1. BGP: a prefix stops being advertised (guided)

```sh
just break bgp   # removes 192.168.100.0/24 from edge1's export allow-list
just fix bgp     # restores it
```

Symptom: `isp1`'s BGP table loses `192.168.100.0/24` (check with
`just lab-cli isp1` → `show ip bgp`); `10.0.0.2/32` (core1's loopback) stays
advertised, since this is a single allow-list entry, not a whole-policy or
whole-session break. Diagnosable and fixable entirely from `edge1`.

### 2. MTU: breaks some traffic, not all of it (self-serve)

```sh
just break mtu   # core1's host1-facing interface drops to the 1500 floor
just fix mtu     # back to jumbo (9000), matching host1's interface
```

Symptom: `ping -s 200` succeeds, `ping -s 3000` silently vanishes — no ICMP
error, nothing wrong-looking in any routing table or adjacency. That's the
point: this is an L2-level frame-size drop, not a router-generated PMTUD
response, so there's nothing to "discover" except by actually testing
different packet sizes.

### 3. Menu (choose your own)

```sh
just break ospf  # edge1<->core1 OSPF settles at Two-Way, never Full
just fix ospf     # restores the point-to-point network-type override
```

Symptom: adjacency never reaches Full; `show network-instance default
protocols ospf neighbor` shows `two-way` indefinitely. This is SR Linux
treating the link as broadcast-type (needing DR/BDR election) once the
explicit `interface-type point-to-point` override is removed — on a true
point-to-point veth with no election outcome, it just never finishes. Hit
by accident during development, kept on purpose: it's a classic, very real
OSPF gotcha with zero error messages anywhere.

## Codespaces

`.devcontainer/` brings up Docker-in-Docker and installs `just` — nothing
proprietary needed (unlike `stcli-3node-lab`), so there's no licensed binary
to fetch from a release asset. Forward ports 2401/2402 to run `stcli`
locally against a Codespace-hosted lab.
