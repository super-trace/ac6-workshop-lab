#!/usr/bin/env python3
"""Render the routing diagram. Requires Pillow: python3 -m pip install pillow."""
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SCALE = 2
im = Image.new("RGB", (1600 * SCALE, 960 * SCALE), "#f7f9fc")
d = ImageDraw.Draw(im)
INK, MUTED = "#172b45", "#52677e"
EBGP, LAN, JFK, IAD = "#d16b25", "#77899b", "#197e83", "#6a51ad"

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
text(70,104,"Two sites · two WAN paths · six devices",23,MUTED,anchor="lm")
box((50,160,515,720),"#eef6f6")
box((1085,160,1550,720),"#f0f2fa")
text(280,198,"JFK  /  AS 65010",27,JFK,True)
text(1320,198,"IAD  /  AS 65030",27,IAD,True)
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

for x,site in [(280,"jfk"),(1320,"iad")]:
    line([(x,430),(x,570)],LAN)
    subnet="192.168.11" if site=="jfk" else "192.168.31"
    pill(x,500,f"{subnet}.0/24",LAN)
    box((x-160,570,x+160,670),"#ffffff","#ccd6e3")
    text(x,597,f"client-{site}",26,bold=True)
    text(x,631,f"{subnet}.10  ·  gateway .1",18,MUTED)
    router(x,370,f"sw-{site}","SR Linux" if site=="jfk" else "Arista cEOS")

router(800,250,"rtr-phl","Arista cEOS")
router(800,530,"rtr-ewr","SR Linux")
box((565,615,1035,780),"#ffffff","#dce3ed")
text(800,648,"How routes flow",24,bold=True)
for y,label in [(690,"Every router is its own AS; eBGP on every link."),
                (722,"Each site originates its loopback and client LAN."),
                (754,"The WAN routers carry both, so IAD sees two paths.")]:
    text(800,y,label,19,MUTED)

for x,color,label in [(470,EBGP,"eBGP WAN"),(880,LAN,"Client LAN")]:
    line([(x,840),(x+65,840)],color)
    text(x+82,840,label,22,INK,anchor="lm")
text(800,900,"Lines show physical links; each BGP session runs over its directly connected /31. Management network omitted.",19,MUTED)
out=ROOT/"lab/diagrams/routing-topology.png"
out.parent.mkdir(parents=True,exist_ok=True)
im.save(out)
print(out)
