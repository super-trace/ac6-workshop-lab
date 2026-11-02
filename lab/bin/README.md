# Bundled stcli for Codespaces

> **TODO before the workshop:** this binary predates multi-device sessions
> (protocol 3.0, device tabs, `-i` inventory picker) and cannot talk to a 3.0
> backend. Replace it with the 3.0 release build, and update the commit, date
> and SHA-256 below.

`stcli-linux-amd64` is a static Linux x86-64 executable. `just lab-setup`
installs it automatically inside Codespaces via `just install-stcli`. It is
committed temporarily so Codespaces can run without downloading a release.
Replace this copy step with a release download when distribution is public.

Built from a clean `main` checkout at commit
`c8f473e1f33ce2ccbcde8f0a1f6a436640a839f2` on **2026-11-02**.
Includes device login (`stcli login`, which works headless; the `--headless`
flag was removed in stcli #87) and `stcli --version`.
The build embeds its source revision; `vcs.modified` must be `false`. Build from
a plain clone, not a `git worktree`: the worktree build here carried no VCS
stamp, so `stcli --version` printed `unknown`.

Run from the CLI source directory, with `WORKSHOP_DIR` set to the workshop path:

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' \
  -o "$WORKSHOP_DIR/lab/bin/stcli-linux-amd64" .
```

Check the binary with `file` and `go version -m`; run `stcli --version` and
`stcli login --help` on Linux to confirm the revision and login flags.

SHA-256: `e5cd65d68a9e24ac5e9059bacce0fbe3b7ccce7bb18c6000be3a6d62eb142b69`
