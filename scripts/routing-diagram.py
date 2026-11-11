#!/usr/bin/env python3
"""Render lab/diagrams/routing-topology.png. Requires Pillow: python3 -m pip install pillow.

Addresses, AS numbers, and VLANs come from lab/configs/nokia.cfg and
lab/topology.clab.yml; arista starts blank, so its side is read from nokia's
neighbor settings.
"""
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SCALE = 2
W, H = 1700, 880
CX = W // 2
im = Image.new("RGB", (W * SCALE, H * SCALE), "#f7f9fc")
d = ImageDraw.Draw(im)
INK, MUTED = "#172b45", "#52677e"
EBGP, TRUNK, MGMT = "#d16b25", "#6a51ad", "#8a9bb0"
DONE, TODO = "#197e83", "#b7791f"

def font(size, bold=False):
    choices = (["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"] if bold else
               ["/System/Library/Fonts/Supplemental/Arial.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"])
    for path in choices:
        if Path(path).exists():
            return ImageFont.truetype(path, size * SCALE)
    return ImageFont.load_default(size=size * SCALE)

def text(x, y, value, size=22, color=INK, bold=False, anchor="mm"):
    d.text((x*SCALE, y*SCALE), value, font=font(size, bold), fill=color, anchor=anchor)

def box(bounds, fill, outline=None, radius=18):
    d.rounded_rectangle(tuple(v*SCALE for v in bounds), radius*SCALE,
                        fill=fill, outline=outline, width=2*SCALE)

def line(points, color, width=4, dashed=False):
    points = [(x*SCALE, y*SCALE) for x, y in points]
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        if not dashed:
            d.line((x1, y1, x2, y2), fill=color, width=width*SCALE)
            continue
        length = ((x2-x1)**2 + (y2-y1)**2) ** 0.5
        for pos in range(0, int(length), 18*SCALE):
            end = min(pos + 10*SCALE, length)
            d.line((x1+(x2-x1)*pos/length, y1+(y2-y1)*pos/length,
                    x1+(x2-x1)*end/length, y1+(y2-y1)*end/length),
                   fill=color, width=width*SCALE)

def pill(x, y, label, color, size=18, fill="#f7f9fc", bold=False):
    w = d.textlength(label, font=font(size, bold))/SCALE + 26
    box((x-w/2, y-18, x+w/2, y+18), fill, radius=8)
    text(x, y, label, size, color, bold)

def chip(x, y, label, color):
    w = d.textlength(label, font=font(15, True))/SCALE + 24
    box((x-w/2, y-15, x+w/2, y+15), "#ffffff", color, radius=15)
    text(x, y, label, 15, color, True)

# ---------------------------------------------------------------- values --
nokia = (ROOT/"lab/configs/nokia.cfg").read_text()
topo = (ROOT/"lab/topology.clab.yml").read_text()

def find(pattern, source=nokia):
    return re.search(pattern, source, re.M)[1]

mgmt_subnet = find(r"ipv4-subnet: ([\d./]+)", topo)
mgmt = dict(re.findall(r"^    (\w+):\n(?:      .*\n)*?      mgmt-ipv4: ([\d.]+)", topo, re.M))
local_as = find(r"bgp autonomous-system (\d+)")
router_id = find(r"bgp router-id ([\d.]+)")
peer_ip, peer_as = re.search(r"bgp neighbor ([\d.]+) peer-as (\d+)", nokia).groups()
bgp_addr = find(r"ethernet-1/1 subinterface 0 ipv4 address ([\d./]+)")
prefix_len = bgp_addr.split("/")[1]
advertised = re.findall(r"prefix-set advertised prefix ([\d./]+)", nokia)
vlans = re.findall(r"ethernet-1/2 subinterface (\d+) description \"VLAN \d+ (\w+)\"", nokia)
gateways = re.findall(r"irb0 subinterface \d+ ipv4 address ([\d.]+)/\d+", nokia)

# ---------------------------------------------------------------- layout --
text(70, 60, "AC6 workshop topology", 38, bold=True, anchor="lm")
text(70, 104, "Two devices · two links · you configure the Arista side", 23, MUTED, anchor="lm")

# Management network along the top, dropping to each device.
NX, AX = 300, W-300         # device centres
TOP, BOTTOM = 290, 590      # device box edges
box((NX-120, 150, AX+120, 196), "#eef1f6", radius=12)
text(CX, 173, f"Management network  ·  {mgmt_subnet}  ·  connect to each device by its IP",
     18, MUTED, True)
for x, node in [(NX, "nokia"), (AX, "arista")]:
    line([(x, 196), (x, TOP)], MGMT, 3, dashed=True)
    pill(x, 243, f"mgmt {mgmt[node]}", INK, 18, bold=True)

def device(x, name, kind, status, color, rows):
    box((x-240, TOP, x+240, BOTTOM), "#ffffff", "#ccd6e3")
    text(x, TOP+42, name, 30, bold=True)
    text(x, TOP+80, kind, 20, MUTED)
    chip(x, TOP+120, status, color)
    for i, row in enumerate(rows):
        text(x, TOP+190+i*30, row, 17, MUTED)

device(NX, "nokia", f"Nokia SR Linux  ·  AS {local_as}", "CONFIGURED", DONE, [
    f"Router ID {router_id}",
    "Advertises " + "  ·  ".join(advertised),
    "VLAN gateways " + "  ·  ".join(gateways),
])
device(AX, "arista", f"Arista cEOS  ·  AS {peer_as} (target)", "STARTS BLANK", TODO, [
    "Ethernet1 and Ethernet2 at factory defaults",
    "no ip routing",
    "The workshop configures both links",
])

# The two links between the devices.
L, R = NX+240, AX-240
for y, color, left, right, title, detail in [
    (395, EBGP, f"e1-1  ·  {bgp_addr}", f"Ethernet1  ·  {peer_ip}/{prefix_len}",
     "Layer 3  ·  eBGP", f"AS {local_as}  ↔  AS {peer_as}"),
    (530, TRUNK, "e1-2", "Ethernet2",
     "Layer 2  ·  802.1Q trunk", "VLANs " + "  ·  ".join(f"{v} {n}" for v, n in vlans)),
]:
    line([(L, y), (R, y)], color, 5)
    text(L+14, y-32, left, 18, color, anchor="lm")
    text(R-14, y-32, right, 18, color, anchor="rm")
    pill(CX, y, title, color, 19, bold=True)
    text(CX, y+34, detail, 17, MUTED)

# What the exercises do with each link.
box((CX-470, 650, CX+470, 776), "#ffffff", "#dce3ed")
text(CX, 680, "What you build", 23, bold=True)
text(CX, 716, f"Scenario 2: bring up eBGP on Ethernet1; arista learns {' and '.join(advertised)}.", 18, MUTED)
text(CX, 748, "Scenario 3: match nokia's trunk on Ethernet2; arista reaches every VLAN gateway.", 18, MUTED)

for x, color, label, dashed in [(CX-470, EBGP, "BGP link", False), (CX-150, TRUNK, "VLAN trunk", False),
                                (CX+170, MGMT, "Management", True)]:
    line([(x, 830), (x+65, 830)], color, 4, dashed)
    text(x+82, 830, label, 20, INK, anchor="lm")

out = ROOT/"lab/diagrams/routing-topology.png"
out.parent.mkdir(parents=True, exist_ok=True)
im.save(out)
print(out)
