# AC6 workshop lab

An eight-node network lab for troubleshooting with `stcli`, running entirely
in GitHub Codespaces. JFK uses SR Linux; IAD uses Arista cEOS. The WAN
routers are cEOS (`rtr-phl`) and SR Linux (`rtr-ewr`); both clients use Linux.

![Routing topology](lab/diagrams/routing-topology.png)

## 1. Create a Codespace

Open this repository on GitHub and select **Code → Codespaces → New with
options**. Choose **4 cores / 16 GB RAM** and create the Codespace.

Wait for automatic setup to finish. It installs the lab images, `just`,
`stcli`, and SSH configuration.

## 2. Start and verify

In the Codespace terminal:

```sh
just lab-up
just verify
```

Expect OSPF neighbors to be Full, all WAN BGP peers to be Established,
and end-to-end client pings to succeed. Check the output for SSH failures.

## 3. Connect

On your computer, with `gh`, `stcli`, and `jq` installed, get the login
helper and sign in through your browser:

```sh
gh repo clone super-trace/ac6-workshop-lab
cd ac6-workshop-lab
./scripts/login-token.sh
```

Copy the access token it prints. In the Codespace terminal:

```sh
read -rsp 'Paste access token: ' STCLI_TOKEN; echo
export STCLI_TOKEN
stcli spine-jfk
```

Choose any node: `spine-jfk`, `leaf-jfk`, `client-jfk`, `spine-iad`,
`leaf-iad`, `client-iad`, `rtr-phl`, or `rtr-ewr`.
The token lasts for this shell; run the helper again when it expires.
For a native device CLI, use `just lab-cli rtr-phl`.

## 4. Finish

```sh
just lab-down
```

Delete the Codespace from GitHub's Codespaces page when finished to remove
its stored resources. Codespaces usage counts against your GitHub allowance.
