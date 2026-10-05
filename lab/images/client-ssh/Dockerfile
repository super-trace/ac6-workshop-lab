# A minimal Linux client with sshd — every node in this lab is an stcli
# target, and plain network-multitool-style images don't ship an SSH
# server. Alpine for the same reason as frr-ssh: small, fast to boot,
# apk not apt.
FROM alpine:3.20

RUN apk add --no-cache openssh iproute2 iputils bind-tools busybox-extras mtr \
    && ssh-keygen -A \
    && echo 'root:admin' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && mkdir -p -m 700 /root/.ssh

# The pubkey itself is bind-mounted in from lab/ac6-workshop-key.pub (see
# topology.clab.yml) to a staging path, not straight to authorized_keys —
# see docker-start.sh for why.
COPY docker-start.sh /usr/local/bin/docker-start.sh
RUN chmod +x /usr/local/bin/docker-start.sh

CMD ["/usr/local/bin/docker-start.sh"]
