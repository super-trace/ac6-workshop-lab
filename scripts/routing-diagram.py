#!/usr/bin/env python3
"""Render the routing diagram. Requires Pillow: python3 -m pip install pillow."""
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SCALE = 2
im = Image.new("RGB", (1600 * SCALE, 1120 * SCALE), "#f7f9fc")
d = ImageDraw.Draw(im)
INK, MUTED = "#172b45", "#52677e"
EBGP, OSPF, IBGP, LAN = "#d16b25", "#197e83", "#6a51ad", "#77899b"

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
    points = [(x*SCALE, y*SCALE) for x,y in points]
    for (x1,y1),(x2,y2) in zip(points, points[1:]):
        if not dashed:
            d.line((x1,y1,x2,y2), fill=color, width=width*SCALE)
        else:
            length=((x2-x1)**2+(y2-y1)**2)**0.5
            for pos in range(0, int(length), 22*SCALE):
                end=min(pos+12*SCALE,length)
                d.line((x1+(x2-x1)*pos/length,y1+(y2-y1)*pos/length,
                        x1+(x2-x1)*end/length,y1+(y2-y1)*end/length),
                       fill=color,width=width*SCALE)

def pill(x,y,label,color,size=18):
    f=font(size)
    w=d.textlength(label,font=f)/SCALE+26
    box((x-w/2,y-19,x+w/2,y+19),"#f7f9fc",radius=8)
    text(x,y,label,size,color)

def config(node):
    suffix = ".cfg"
    return (ROOT/"lab/configs"/(node+suffix)).read_text()

def router(x,y,node,kind):
    cfg=config(node)
    asn=re.search(r"(?:autonomous-system|router bgp) (\d+)",cfg)[1]
    rid=re.search(r"router-id ([\d.]+)",cfg)[1]
    box((x-160,y-60,x+160,y+60),"#ffffff","#ccd6e3")
    text(x,y-24,node,27,bold=True)
    text(x,y+12,f"{kind}  ·  AS {asn}",20,MUTED)
    text(x,y+40,f"Router ID {rid}",18,MUTED)

text(70,60,"AC6 workshop routing topology",38,bold=True,anchor="lm")
text(70,104,"Two sites · two WAN paths · eight devices",23,MUTED,anchor="lm")
box((50,160,515,960),"#eef6f6")
box((1085,160,1550,960),"#f0f2fa")
text(280,198,"JFK  /  AS 65010",27,OSPF,True)
text(1320,198,"IAD  /  AS 65030",27,IBGP,True)
text(800,165,"WAN CORE",22,MUTED,True)

# Physical WAN links; BGP sessions use the directly connected /31s.
for points,label,x,y in [
    ([(440,350),(640,250)],"172.16.1.0/31",535,275),
    ([(440,390),(640,530)],"172.16.2.0/31",535,475),
    ([(960,250),(1160,350)],"172.16.3.0/31",1065,275),
    ([(960,530),(1160,390)],"172.16.4.0/31",1065,475),
]:
    line(points,EBGP)
    pill(x,y,label,EBGP)
line([(800,310),(800,470)],EBGP)
pill(800,365,"eBGP",EBGP)
pill(800,403,"172.16.5.0/31",EBGP)

for x,site,prefix in [(280,"jfk","10.10"),(1320,"iad","10.30")]:
    line([(x,430),(x,620)],OSPF)
    pill(x,483,"OSPF · area 0.0.0.0",OSPF)
    pill(x,520,f"{prefix}.1.0/31",OSPF)
    # iBGP is a logical loopback session over the OSPF link.
    side=x+190 if site=="jfk" else x-190
    line([(x+150 if site=="jfk" else x-150,400),(side,400),
          (side,650),(x+150 if site=="jfk" else x-150,650)],IBGP,dashed=True)
    pill(side,573,"iBGP",IBGP)
    line([(x,740),(x,825)],LAN)
    subnet="192.168.11" if site=="jfk" else "192.168.31"
    pill(x,780,f"{subnet}.0/24",LAN)
    box((x-160,825,x+160,925),"#ffffff","#ccd6e3")
    text(x,852,f"client-{site}",26,bold=True)
    text(x,886,f"{subnet}.10  ·  gateway .1",18,MUTED)
    router(x,370,f"spine-{site}","SR Linux")
    router(x,680,f"leaf-{site}","SR Linux")

router(800,250,"rtr-phl","Arista cEOS")
router(800,530,"rtr-ewr","Arista cEOS")
box((565,660,1035,895),"#ffffff","#dce3ed")
text(800,695,"How routes flow",24,bold=True)
for y,label in [(741,"OSPF carries site links + loopbacks."),
                (779,"iBGP peers between site loopbacks."),
                (817,"Spines set next-hop-self to leaves."),
                (855,"eBGP carries site prefixes over WAN.")]:
    text(800,y,label,19,MUTED)

for x,color,label,dash in [(95,OSPF,"OSPF underlay",False),
                           (485,IBGP,"iBGP overlay",True),
                           (860,EBGP,"eBGP WAN",False),
                           (1205,LAN,"Client LAN",False)]:
    line([(x,1020),(x+65,1020)],color,dashed=dash)
    text(x+82,1020,label,22,INK,anchor="lm")
text(800,1080,"Solid lines show physical links. Dashed iBGP sessions run over OSPF. Management network omitted.",19,MUTED)
out=ROOT/"lab/diagrams/routing-topology.png"
out.parent.mkdir(parents=True,exist_ok=True)
im.save(out)
print(out)
