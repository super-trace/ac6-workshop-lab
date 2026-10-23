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
`c94b8645d430e448cd57383ced60cdf80a7f0075` on **2026-10-16**.
Includes headless device login (`stcli login --headless`) and `stcli --version`.
The build embeds its source revision; `vcs.modified` must be `false`.

Run from the CLI source directory, with `WORKSHOP_DIR` set to the workshop path:

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' \
  -o "$WORKSHOP_DIR/lab/bin/stcli-linux-amd64" .
```

Check the binary with `file` and `go version -m`; run `stcli --version` and
`stcli login --help` on Linux to confirm the revision and headless flag.

SHA-256: `18419530650f85a5de195be6c08eb2ea9d2efe03c86341b9a192bffca12cc2d4`
