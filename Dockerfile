FROM alpine:latest

ENV CB_RELEASE=1.0.0
ENV CB=containerbuddy-1.0.0.tar.gz
WORKDIR /opt/containerbuddy

# install jq
RUN apk update ; apk add jq ; rm -rf /var/cache/apk/*

# get containerbuddy release
ADD https://github.com/joyent/containerbuddy/releases/download/$CB_RELEASE/$CB /opt/containerbuddy
RUN gunzip $CB \
&& tar xf containerbuddy-1.0.0.tar \
&& rm containerbuddy-1.0.0.tar

# add containerbuddy and configuration
COPY cloudflare.json /opt/containerbuddy
COPY update-dns.sh /opt/containerbuddy
