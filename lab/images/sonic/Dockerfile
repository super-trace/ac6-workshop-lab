# The lab's SONiC image: SONiC's official virtual switch (docker-sonic-vs,
# Apache-2.0) plus what a workshop device needs. SONiC's own builds are
# published only as a download from its Azure pipeline, so
# scripts/sonic-image.sh loads that file as docker-sonic-vs:<branch> and
# builds this on top. We publish the result on ghcr so attendees can
# `docker pull` it.
ARG BASE=docker-sonic-vs:202511
FROM ${BASE}

# The lab login, oldprotocol / newbrain, as on every lab device. SONiC's
# `config` commands need root, so oldprotocol gets passwordless sudo, as
# SONiC's own admin user does on a real switch. The shared lab key lets the
# lab scripts log in without the password (lab/ssh_config).
COPY ac6-workshop-key.pub /tmp/ac6-workshop-key.pub
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash -G sudo oldprotocol \
    && echo 'oldprotocol:newbrain' | chpasswd \
    && echo 'root:newbrain' | chpasswd \
    && echo 'oldprotocol ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/oldprotocol \
    && chmod 440 /etc/sudoers.d/oldprotocol \
    && install -d -m 700 -o oldprotocol -g oldprotocol /home/oldprotocol/.ssh \
    && install -m 600 -o oldprotocol -g oldprotocol /tmp/ac6-workshop-key.pub /home/oldprotocol/.ssh/authorized_keys \
    && rm /tmp/ac6-workshop-key.pub

# docker-sonic-vs ships sshd but never starts it. Start it with the other
# services, with host keys made fresh on every deploy.
RUN printf '%s\n' '' \
        '[program:sshd]' \
        'command=/bin/bash -c "mkdir -p /run/sshd && ssh-keygen -A && exec /usr/sbin/sshd -D -e"' \
        'priority=2' \
        'autostart=true' \
        'autorestart=true' \
        'stdout_logfile=syslog' \
        'stderr_logfile=syslog' \
        >>/etc/supervisor/conf.d/supervisord.conf \
    && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# docker-sonic-vs leaves bgpd stopped (SONiC's tests start it on demand), so
# a blank switch couldn't run BGP at all. Start it last, with the others.
RUN printf '\n%s\n' '# ac6 workshop: run BGP like a real switch does.' 'supervisorctl start bgpd' >>/usr/bin/start.sh
