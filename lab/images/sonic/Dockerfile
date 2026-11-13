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
# services, with host keys made fresh on every deploy. sshd refuses to start
# if /run/sshd is group- or world-writable, which it is when the image is
# built in a Codespace, so set its owner and mode rather than trust mkdir.
RUN printf '%s\n' '' \
        '[program:sshd]' \
        'command=/bin/bash -c "mkdir -p /run/sshd && chown root:root /run/sshd && chmod 0755 /run/sshd && ssh-keygen -A && exec /usr/sbin/sshd -D -e"' \
        'priority=2' \
        'autostart=true' \
        'autorestart=true' \
        'stdout_logfile=syslog' \
        'stderr_logfile=syslog' \
        >>/etc/supervisor/conf.d/supervisord.conf \
    && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# docker-sonic-vs leaves bgpd stopped (SONiC's tests start it on demand), so
# a blank switch couldn't run BGP at all. Start it right after zebra: start.sh
# runs under `bash -e` and stops at a later line that fails in this image
# (`supervisorctl start rebootbackend`), so anything appended at its end
# never runs.
RUN sed -i 's/^supervisorctl start zebra$/&\nsupervisorctl start bgpd/' /usr/bin/start.sh \
    && grep -A1 '^supervisorctl start zebra$' /usr/bin/start.sh | grep -q 'start bgpd'

# docker-sonic-vs ships a cut-down /etc/sonic/sonic_version.yml, and
# `show version` (the first thing anyone, or stcli's agent, runs to identify
# the box) crashes on the missing fields. Fill them in as a real switch has
# them: the build version and Debian release now, the kernel at boot.
RUN python3 - <<'PY'
import yaml
path = "/etc/sonic/sonic_version.yml"
v = yaml.safe_load(open(path))
if not v.get("build_version"):
    # `show version` adds the "SONiC." prefix itself.
    v["build_version"] = "{}.{}".format(v.get("branch", "unknown"), v.get("build_number", 0))
v.setdefault("debian_version", open("/etc/debian_version").read().strip())
v.setdefault("kernel_version", "unknown")
yaml.safe_dump(v, open(path, "w"), default_flow_style=False, sort_keys=False)
PY
RUN sed -i '1a sed -i "s/^kernel_version:.*/kernel_version: $(uname -r)/" /etc/sonic/sonic_version.yml' /usr/bin/start.sh

# SONiC's gNMI server, for the Grafana scenario: gnmic (lab/grafana/) streams
# sonic's counters and port states from it into Prometheus. docker-sonic-vs
# leaves it out; a real switch runs it in its own gnmi container. This is the
# same branch's sonic-gnmi package, which scripts/sonic-image.sh downloads from
# SONiC's pipeline and passes in as the `gnmi` build context. It serves the
# switch's Redis databases (COUNTERS_DB, APPL_DB, ...) on port 50051 without
# TLS or client auth, as SONiC's gnmi-native.sh does with TLS off: fine for a
# disposable lab on its own management network.
COPY --from=gnmi sonic-gnmi.deb /tmp/sonic-gnmi.deb
RUN apt-get update \
    && apt-get install -y --no-install-recommends /tmp/sonic-gnmi.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/sonic-gnmi.deb \
    && printf '%s\n' '' \
        '[program:gnmi]' \
        'command=/usr/sbin/telemetry -logtostderr --noTLS --port 50051 --allow_no_client_auth' \
        'priority=3' \
        'autostart=true' \
        'autorestart=true' \
        'startretries=100' \
        'stdout_logfile=syslog' \
        'stderr_logfile=syslog' \
        >>/etc/supervisor/conf.d/supervisord.conf

# Send sonic's syslog to the lab's Vector (lab/grafana/, 172.20.23.20), which
# stores it in Loki, beside nokia's. UDP, so a stopped Grafana stack never
# blocks the switch.
RUN printf '%s\n' \
        '# AC6 workshop: forward everything to Vector -> Loki (lab/grafana/).' \
        '*.* @172.20.23.20:1514;RSYSLOG_SyslogProtocol23Format' \
        >/etc/rsyslog.d/90-ac6-loki.conf
