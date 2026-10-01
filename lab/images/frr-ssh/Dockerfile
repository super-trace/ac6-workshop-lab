# FRR + sshd, so the WAN routers (rtr-phl, rtr-ewr) can be stcli targets
# like every other node in this lab. The stock frrouting/frr image has no
# SSH server at all. Alpine-based (confirmed via /etc/os-release), so apk,
# not apt.
FROM frrouting/frr:latest

RUN apk add --no-cache openssh \
    && ssh-keygen -A \
    && echo 'root:admin' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

COPY docker-start-with-sshd.sh /usr/local/bin/docker-start-with-sshd.sh
RUN chmod +x /usr/local/bin/docker-start-with-sshd.sh

CMD ["/usr/local/bin/docker-start-with-sshd.sh"]
