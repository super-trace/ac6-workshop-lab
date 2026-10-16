# AC6 workshop lab

An eight-node network lab for troubleshooting with `stcli`, running entirely
in GitHub Codespaces. JFK uses SR Linux; IAD uses Arista cEOS. The WAN
routers are cEOS (`rtr-phl`) and SR Linux (`rtr-ewr`); both clients use Linux.

For local Docker, follow [the local setup guide](README-docker-local.md).

> **Public launch:** This repository and `super-trace/stcli-releases` will both
> become public. At launch, update both READMEs, remove private-access requirements
> from the local-install instructions, and test downloads without GitHub login.

![Routing topology](lab/diagrams/routing-topology.png)

## 1. Create a Codespace

Open this repository on GitHub and select **Code → Codespaces → New with
options**. Choose the **4-core / 16 GB RAM** machine and create the Codespace.
Use this machine size for the workshop lab.

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

In the **Codespace terminal**, sign in and connect:

```sh
stcli login --headless
stcli spine-jfk
```

Open the verification link printed by `stcli` in your computer's browser and
enter the one-time code. Complete sign-in, then wait for **Signed in.** in the
Codespace terminal before connecting. Credentials are saved in the Codespace
and refreshed automatically.

In an existing Codespace, update the bundled binary first:

```sh
git pull
just install-stcli
stcli --version
```

Choose any node: `spine-jfk`, `leaf-jfk`, `client-jfk`, `spine-iad`,
`leaf-iad`, `client-iad`, `rtr-phl`, or `rtr-ewr`.
For a native device CLI, use `just lab-cli rtr-phl`.

## 4. Finish

```sh
just lab-down
```

Delete the Codespace from GitHub's Codespaces page when finished to remove
its stored resources. Codespaces usage counts against your GitHub allowance.
