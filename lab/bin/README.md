# `stcli-linux-amd64`

A placeholder, not the long-term distribution mechanism: `stcli` doesn't
ship public release binaries yet, so this is a prebuilt, committed one —
installed into a Codespace automatically by `just install-stcli` (called
from `lab-setup`, guarded to only act when `$CODESPACES` is set — see the
justfile). Once `stcli` has real GitHub Releases, this file and the
install step that copies it should be replaced with a `curl`-the-release
download instead.

Built with:

```sh
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w" -o lab/bin/stcli-linux-amd64 .
```

from the [`super-trace/stcli`](https://github.com/super-trace/stcli) repo.
Pure Go, no CGO, so this cross-compiles cleanly from any host.

**Built from `main` at commit `0801fb4b85c7` on 2026-10-06.** This includes
[PR #15](https://github.com/super-trace/stcli/pull/15), which merges the
ssh-agent and `IdentityFile` key sources into one `publickey` auth attempt.
Without that fix, an unrelated key in the ssh-agent can exhaust the
`publickey` method before this lab's own key is offered.
