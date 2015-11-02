# a minimal Nginx container including containerbuddy and a simple virtualhost config
FROM nginx:latest

# install curl
RUN apt-get update && \
    apt-get install -y \
    curl && \
    rm -rf /var/lib/apt/lists/*

# add containerbuddy and all our configuration
COPY opt/containerbuddy /opt/containerbuddy/
COPY etc/nginx/conf.d /etc/nginx/conf.d/
