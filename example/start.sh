#!/bin/bash

COMPOSE_CFG=
PREFIX=tritoncloudflare

while getopts "f:p:" optchar; do
    case "${optchar}" in
        f) COMPOSE_CFG=" -f ${OPTARG}" ;;
        p) PREFIX=${OPTARG} ;;
    esac
done
shift $(expr $OPTIND - 1 )

COMPOSE="docker-compose -p ${PREFIX}${COMPOSE_CFG:-}"
CONFIG_FILE=${COMPOSE_CFG:-docker-compose.yml}

echo "Starting example application"
echo "project prefix:      $PREFIX"
echo "docker-compose file: $CONFIG_FILE"

echo 'Pulling latest container versions'
${COMPOSE} pull

echo 'Starting Consul.'
${COMPOSE} up -d consul

# get network info from consul and poll it for liveness
if [ -z "${COMPOSE_CFG}" ]; then
    CONSUL_IP=$(sdc-listmachines --name ${PREFIX}_consul_1 | json -a ips.1)
else
    CONSUL_IP=${CONSUL_IP:-$(docker-machine ip default)}
fi

echo 'Opening consul console'
open http://${CONSUL_IP}:8500/ui

echo 'Starting Nginx and Cloudflare-watcher'
${COMPOSE} up -d

# get network info from Nginx and poll it for liveness
if [ -z "${COMPOSE_CFG}" ]; then
    NGINX_IP=$(sdc-listmachines --name ${PREFIX}_nginx_1 | json -a ips.1)
    NGINX_PORT=
else
    NGINX_IP=${NGINX_IP:-$(docker-machine ip default)}
    NGINX_PORT=":$(docker inspect ${PREFIX}_nginx_1 | json -a NetworkSettings.Ports."80/tcp".0.HostPort)"
fi

echo 'Opening web page...'
open http://${NGINX_IP}${NGINX_PORT}/

echo 'Opening web page...'

echo 'Opening web page...'
open http://${NGINX_IP}${NGINX_PORT}/

CF_ROOT_DOMAIN=$(grep CF_ROOT_DOMAIN ./.env | cut -d'=' -f2)
open https://www.cloudflare.com/a/dns/${CF_ROOT_DOMAIN}

echo 'Try scaling up nginx nodes!'
echo "${COMPOSE} scale nginx=3"
