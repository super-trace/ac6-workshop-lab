# Topology diagram

`routing-topology.png` is the README's diagram: nokia and arista, the BGP
link and VLAN trunk between them, and their management IPs. Its generator
reads addresses, AS numbers, VLANs, and gateways from `lab/configs/nokia.cfg`
and management IPs from `lab/topology.clab.yml`; arista starts blank, so its
side comes from nokia's neighbor settings. Update the layout and labels in
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
