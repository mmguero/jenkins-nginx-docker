# options: latest, custom (default=latest)
ARG BUILDER_TAG=latest
# options: valid version from "$ apt-cache madison docker-ce"
ARG CUSTOM_VERSION=5:20.10.5~3-0~debian-buster
ARG COMPOSE_VERSION=1.29.0
ARG VBOX_VERSION=6.1
ARG VBOX_EXTPACK_ACCEPT_KEY=33d7284dc4a0ece381196fda3cfe2ed0e1e8e7ed7f27b9a9ebc4ee22e24bd23c

FROM jenkins/jenkins:lts AS base
MAINTAINER Michael J. Stealey <michael.j.stealey@gmail.com>

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false

# set default user attributes
ENV UID_JENKINS=1000
ENV GID_JENKINS=1000

# add ability to run docker from within jenkins (docker in docker)
USER root
RUN apt-get update && apt-get -y install \
    sudo \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | \
        gpg --dearmor -o /usr/share/keyrings/vbox-archive-keyring.gpg \
    && echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/vbox-archive-keyring.gpg] \
    http://download.virtualbox.org/virtualbox/debian \
    $(lsb_release -cs) contrib" | tee /etc/apt/sources.list.d/virtualbox.list > /dev/null

FROM base as build-version-latest
ARG VBOX_VERSION
ARG VBOX_EXTPACK_ACCEPT_KEY
RUN apt-get update && apt-get -y install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    && apt-get -y --no-install-recommends install \
     virtualbox-${VBOX_VERSION} \
    && cd /tmp \
    && curl -fsSLJO "$(curl -fsL "https://www.virtualbox.org/wiki/Downloads" | grep -oP "https://.*?vbox-extpack" | sort -V | head -n 1)" \
    && VBoxManage extpack install --accept-license=${VBOX_EXTPACK_ACCEPT_KEY} --replace *.vbox-extpack \
    && curl -o /tmp/vagrant.deb "https://releases.hashicorp.com$(curl -fsL "https://releases.hashicorp.com$(curl -fsL "https://releases.hashicorp.com/vagrant" | grep 'href="/vagrant/' | head -n 1 | grep -o '".*"' | tr -d '"' )" | grep "x86_64\.deb" | head -n 1 | grep -o 'href=".*"' | sed 's/href=//' | tr -d '"')" \
    && dpkg -i /tmp/vagrant.deb \
    && rm -f /tmp/vagrant.deb

FROM base as build-version-custom
# set docker version (match the host version) and set java opts
ARG CUSTOM_VERSION
ARG COMPOSE_VERSION
RUN apt-get update && apt-get -y install \
    docker-ce=${CUSTOM_VERSION} \
    docker-ce-cli=${CUSTOM_VERSION} \
    containerd.io && \
    curl -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose && \
    chmod 755 /usr/bin/docker-compose

FROM build-version-${BUILDER_TAG} as final

# add entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh

# normally user would be set to jenkins, but this is handled by the docker-entrypoint script on startup
#USER jenkins

ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint.sh"]
