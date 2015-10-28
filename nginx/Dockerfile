# a minimal Nginx container including containerbuddy and a simple virtulhost config
FROM nginx:latest

# install curl
RUN apt-get update && \
    apt-get install -y \
    curl && \
    rm -rf /var/lib/apt/lists/*

# add containerbuddy and all our configuration
ADD opt/containerbuddy /opt/containerbuddy/
ADD etc/nginx/conf.d /etc/nginx/conf.d/
