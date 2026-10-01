#!/bin/bash
set -e

# sshd with no -D self-daemonizes (forks to background, exits this process'
# child) — standard OpenSSH behavior, not something we have to arrange.
/usr/sbin/sshd

# Hand off to FRR's own startup as the foreground process tini supervises —
# exec, not a backgrounded call, so this container's PID 1 (under tini)
# stays watchfrr, same as the stock frrouting/frr image.
exec /usr/lib/frr/docker-start
