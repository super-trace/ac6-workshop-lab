"""Put sonic's CONFIG_DB back to the baseline `lab-ready.sh` saved.

Runs inside the sonic container (`docker exec -i ... python3 - < this`).
SONiC's own `config replace` would do this, but its YANG validation rejects
docker-sonic-vs's default config, and `config reload` needs systemd, which
the container doesn't have. So: diff CONFIG_DB against the baseline, delete
every key the workshop added (dependents first, so VLAN members and IP
addresses go before their VLANs and interfaces), and write back every key it
changed or removed.
"""

import json

from swsscommon.swsscommon import ConfigDBConnector

BASELINE = "/etc/sonic/ac6-baseline.json"

# Deleted first to last; anything not listed goes after these.
DELETE_ORDER = [
    "VLAN_MEMBER",
    "VLAN_SUB_INTERFACE",
    "VLAN_INTERFACE",
    "INTERFACE",
    "LOOPBACK_INTERFACE",
    "PORTCHANNEL_MEMBER",
    "PORTCHANNEL_INTERFACE",
    "STATIC_ROUTE",
    "BGP_NEIGHBOR",
    "VLAN",
    "PORTCHANNEL",
    "LOOPBACK",
]


def key_of(raw):
    """sonic-cfggen JSON keys are 'Vlan110|10.110.0.2/24'; the connector
    wants a tuple for multi-part keys."""
    parts = raw.split("|")
    return tuple(parts) if len(parts) > 1 else raw


def ip_last(raw):
    """Within a table, delete 'Vlan110|10.110.0.2/24' before 'Vlan110'."""
    return 0 if "|" in raw else 1


db = ConfigDBConnector()
db.connect()
base = json.load(open(BASELINE))
now = db.get_config()


def as_raw(key):
    return "|".join(key) if isinstance(key, tuple) else key


current = {t: {as_raw(k): v for k, v in rows.items()} for t, rows in now.items()}

tables = sorted(
    set(current) | set(base),
    key=lambda t: DELETE_ORDER.index(t) if t in DELETE_ORDER else len(DELETE_ORDER),
)

removed = restored = 0
for table in tables:
    extra = [k for k in current.get(table, {}) if k not in base.get(table, {})]
    for raw in sorted(extra, key=ip_last):
        db.set_entry(table, key_of(raw), None)
        removed += 1

for table in reversed(tables):
    for raw, fields in base.get(table, {}).items():
        if current.get(table, {}).get(raw) != fields:
            db.set_entry(table, key_of(raw), fields)
            restored += 1

print(f"sonic: CONFIG_DB reset ({removed} removed, {restored} restored).")
