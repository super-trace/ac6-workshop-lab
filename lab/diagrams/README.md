# Routing diagram

`routing-topology.png` shows the site underlays, iBGP sessions, WAN peers,
and client subnets. Its generator reads router IDs and AS numbers from
`lab/configs`. Update the layout and link labels in
`scripts/routing-diagram.py` when changing the topology.

From the workshop repository folder:

```sh
python3 -m venv /tmp/ac6-diagram-venv
/tmp/ac6-diagram-venv/bin/pip install pillow
/tmp/ac6-diagram-venv/bin/python scripts/routing-diagram.py
```

Inspect the generated image before committing. The physical-link diagram
has a separate generator: `just lab-diagram` produces
`lab/topology.clab.png` and its editable `.drawio` source.
