# Bundled stcli for Codespaces

> **Keep in step with the backend:** this binary speaks protocol 3.0 (stcli #94,
> stcli-be #51, spec `ce4ce0f`). A protocol bump on either side breaks it with
> errors such as `decode POST /v1/sessions response`; rebuild from `main` and
> update the commit, date and SHA-256 below.

`stcli-linux-amd64` is a static Linux x86-64 executable. `just lab-setup`
installs it automatically inside Codespaces via `scripts/install-stcli.sh`. It is
committed temporarily so Codespaces can run without downloading a release.
Replace this copy step with a release download when distribution is public.

Built from a clean `main` checkout at commit
`0d24de747d136679799ef2283a1fcee97dc699ef` on **2026-11-02**.
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

SHA-256: `8c9df1d031bd1c700809b650c3b1a21757d8c9e360f8cc81cf804c4732bddfd5`
