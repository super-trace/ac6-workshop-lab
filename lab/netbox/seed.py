# The lab's skeleton in NetBox: sites, manufacturers, device types, platforms
# and device roles, which NetBox needs before it accepts a device. No devices,
# interfaces or IPs: those come from the stcli export. Runs in NetBox's
# Django shell (scripts/netbox-up.sh pipes it in); safe to re-run, since it
# only creates what's missing. Slugs match lab/inventory's sites, platforms
# and roles.
from dcim.models import DeviceRole, DeviceType, Manufacturer, Platform, Site

SITES = [
    ("JFK", "jfk", "JFK site: sw-jfk and client-jfk"),
    ("IAD", "iad", "IAD site: sw-iad and client-iad"),
    ("WAN", "wan", "WAN routers rtr-phl and rtr-ewr"),
]
MANUFACTURERS = [("Nokia", "nokia"), ("Arista", "arista"), ("Linux", "linux")]
# (manufacturer slug, model, slug)
DEVICE_TYPES = [
    ("nokia", "SR Linux", "srlinux"),
    ("arista", "cEOS-lab", "ceos-lab"),
    ("linux", "Linux client", "linux-client"),
]
# (manufacturer slug, name, slug)
PLATFORMS = [
    ("nokia", "Nokia SR Linux", "nokia_srlinux"),
    ("arista", "Arista EOS", "arista_ceos"),
    ("linux", "Linux", "linux"),
]
# (name, slug, color)
ROLES = [
    ("Switch", "switch", "2196f3"),
    ("WAN router", "wan", "9c27b0"),
    ("Client", "client", "4caf50"),
]

created = []


def ensure(cls, slug, **fields):
    obj, new = cls.objects.get_or_create(slug=slug, defaults=fields)
    if new:
        created.append(f"{cls._meta.verbose_name} {obj}")
    return obj


for name, slug, description in SITES:
    ensure(Site, slug, name=name, description=description)
makers = {slug: ensure(Manufacturer, slug, name=name) for name, slug in MANUFACTURERS}
for maker, model, slug in DEVICE_TYPES:
    ensure(DeviceType, slug, manufacturer=makers[maker], model=model)
for maker, name, slug in PLATFORMS:
    ensure(Platform, slug, manufacturer=makers[maker], name=name)
for name, slug, color in ROLES:
    ensure(DeviceRole, slug, name=name, color=color)

print(f"Seeded {len(created)} new objects" + (": " + ", ".join(created) if created else " (all present)"))
