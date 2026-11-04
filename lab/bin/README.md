# Bundled stcli for Codespaces

> **Keep in step with the backend:** this binary speaks protocol 3.0, pinned at
> spec `795f138` (stcli #104), the same spec as stcli-be `main`. A protocol
> bump on either side breaks it with errors such as `decode POST /v1/sessions
> response`; rebuild from `main` and update the commit, date and SHA-256 below.

`stcli-linux-amd64` is a static Linux x86-64 executable. `just lab-setup`
installs it automatically inside Codespaces via `scripts/install-stcli.sh`. It is
committed temporarily so Codespaces can run without downloading a release.
Replace this copy step with a release download when distribution is public.

Built on **2026-11-04** from commit `146ea4564ed8685742c1bf84fd9a7dff2734cb67`
(`main` at #108) plus Alex's uncommitted `ui-improvements` change, which
recolors inline code in agent replies (bold pale cyan on a gray chip instead
of glamour's red). `stcli --version` therefore prints `146ea45-dirty`, and
this exact binary can't be rebuilt from a commit until that change is
committed. Includes multi-device sessions (#101), the session picker listing
every device (#110), and confirming a session the agent names (#107).
Includes device login (`stcli login`, which works headless; the `--headless`
flag was removed in stcli #87) and `stcli --version`.
The build embeds its source revision; `vcs.modified` should be `false` (the
current bundle is the uncommitted-change exception above). Build from
a plain clone, not a `git worktree`: the worktree build here carried no VCS
stamp, so `stcli --version` printed `unknown`.

Run from the CLI source directory, with `WORKSHOP_DIR` set to the workshop path:

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' \
  -o "$WORKSHOP_DIR/lab/bin/stcli-linux-amd64" .
```

Check the binary with `file` and `go version -m`; run `stcli --version` and
`stcli login --help` on Linux to confirm the revision and login flags.

SHA-256: `efafc88d1457b12e73f41565948a595c6e4c9f3ed1068559a8fde4c94197260b`
