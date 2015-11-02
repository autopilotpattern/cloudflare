FROM debian:jessie

# install curl and jq
RUN apt-get update && \
    apt-get install -y \
    curl \
    jq && \
    rm -rf /var/lib/apt/lists/*

# add containerbuddy and configuration
COPY opt/containerbuddy /opt/containerbuddy/
