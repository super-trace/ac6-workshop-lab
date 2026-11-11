FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Codespaces build hosts have intermittently failed to resolve *.ubuntu.com
# ("Could not resolve 'archive.ubuntu.com'") while every other domain works,
# which fails the docker-in-docker feature's apt-get and drops the Codespace
# into recovery mode. Point apt at two mirrors on other domains instead; apt
# treats one failing source as a warning and installs from the other.
RUN sed -i \
        -e 's#http://archive.ubuntu.com/ubuntu/\?#http://mirror.math.princeton.edu/pub/ubuntu/ http://ftp.osuosl.org/pub/ubuntu/#' \
        -e 's#http://security.ubuntu.com/ubuntu/\?#http://mirror.math.princeton.edu/pub/ubuntu/ http://ftp.osuosl.org/pub/ubuntu/#' \
        /etc/apt/sources.list.d/ubuntu.sources \
    && grep '^URIs' /etc/apt/sources.list.d/ubuntu.sources
