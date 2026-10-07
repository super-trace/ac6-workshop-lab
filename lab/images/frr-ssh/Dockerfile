# FRR + sshd, so the WAN routers (rtr-phl, rtr-ewr) can be stcli targets
# like every other node in this lab. Use the official multi-architecture
# Quay image (amd64 + arm64); the old Docker Hub latest is amd64-only.
FROM quay.io/frrouting/frr:10.7.1

RUN apk add --no-cache openssh \
    && ssh-keygen -A \
    && echo 'root:admin' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && mkdir -p -m 700 /root/.ssh \
    && printf 'service integrated-vtysh-config\n' > /etc/frr/vtysh.conf

# The pubkey itself is bind-mounted in from lab/ac6-workshop-key.pub (see
# topology.clab.yml) to a staging path, not straight to authorized_keys —
# see docker-start-with-sshd.sh for why.

COPY docker-start-with-sshd.sh /usr/local/bin/docker-start-with-sshd.sh
RUN chmod +x /usr/local/bin/docker-start-with-sshd.sh

CMD ["/usr/local/bin/docker-start-with-sshd.sh"]
