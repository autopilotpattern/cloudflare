FROM debian:jessie

# install curl and jq
RUN apt-get update && \
    apt-get install -y \
    curl \
    jq && \
    rm -rf /var/lib/apt/lists/*

# get containerbuddy release
RUN export CB=containerbuddy-0.0.1-alpha &&\
    mkdir -p /opt/containerbuddy && \
    curl -Lo /tmp/${CB}.tar.gz \
    https://github.com/joyent/containerbuddy/releases/download/0.0.1-alpha/${CB}.tar.gz && \
	tar -xf /tmp/${CB}.tar.gz && \
    mv /build/containerbuddy /opt/containerbuddy/

# add containerbuddy and configuration
COPY cloudflare.json /opt/containerbuddy/
COPY update-dns.sh /opt/containerbuddy/
