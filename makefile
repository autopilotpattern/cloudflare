MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail
.DEFAULT_GOAL := build

.PHONY: clean build ship

CB=containerbuddy-0.0.1-alpha

clean:
	rm -r build/

build: .env nginx/opt/containerbuddy/containerbuddy cloudflare/opt/containerbuddy/containerbuddy
	docker-compose -f docker-compose-local.yml build

ship:
	docker tag tritoncloudflare_nginx 0x74696d/triton-cloudflare-demo-nginx
	docker tag tritoncloudflare_cloudflare 0x74696d/triton-cloudflare


#------------------------------------
# get latest build of containerbuddy and copy to Docker build contexts

.env:
	@echo 'CF_API_KEY=<cloudflare API key>' > .env
	@echo 'CF_AUTH_EMAIL=<cloudflare email address' >> .env
	@echo 'CF_ROOT_DOMAIN=<domain associated with DNS zone>' >> .env
	@echo 'SERVICE=<service to poll in Consul for changes' >> .env
	@echo 'RECORD=<domain to update in Cloudflare>' >> .env
	@echo 'TTL=<DNS TTL of the domain to update (defaults to 600)>' >> .env
	@echo 'CONSUL=<hostname/ip of Consul (default to link if available)>' >> .env
	@echo 'Edit the .env file to include the credentials you need.'
	exit 1

build/containerbuddy:
	mkdir -p build
	curl -Lo build/${CB}.tar.gz \
		https://github.com/joyent/containerbuddy/releases/download/0.0.1-alpha/${CB}.tar.gz
	tar -xf build/${CB}.tar.gz

nginx/opt/containerbuddy/containerbuddy: build/containerbuddy
	cp build/containerbuddy nginx/opt/containerbuddy/containerbuddy

cloudflare/opt/containerbuddy/containerbuddy: build/containerbuddy
	cp build/containerbuddy cloudflare/opt/containerbuddy/containerbuddy
