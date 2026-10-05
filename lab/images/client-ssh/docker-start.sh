#!/bin/sh
set -e

# The pubkey is bind-mounted read-only to a staging path, not straight to
# authorized_keys: OpenSSH's StrictModes (on by default) refuses a key file
# writable by anyone but its owner, and a bind-mounted file inherits
# whatever ownership/permissions it has crossing into this container's
# user namespace — confirmed to come across as root:root 644 locally but
# 1000:1000 666 through a Codespace's nested Docker-in-Docker, which
# StrictModes rejects. Copying it in lets this container set its own
# ownership and permissions regardless of what the mount looked like.
cp /tmp/ac6-workshop-key.pub /root/.ssh/authorized_keys
chown root:root /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

exec /usr/sbin/sshd -D
