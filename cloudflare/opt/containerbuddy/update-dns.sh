#!/bin/bash

usage() {
    echo 'Usage ./update-dns.sh [SERVICE] [RECORD] [TTL]'
    echo
    echo 'Updates DNS records on Cloudflare.'
    echo
    echo 'Required environment variables:'
    echo 'CF_ROOT_DOMAIN  domain associated with Cloudflare zone'
    echo 'CF_API_KEY      API key generated from Cloudflare "My Account" page'
    echo 'CF_AUTH_EMAIL   email address associated with your Cloudflare user account'
    echo 'CONSUL          hostname or IP of Consul server (will use address of linked consul if available)'
    echo
    echo 'Required parameters (or environment variables):'
    echo 'SERVICE         name of service to query from Consul'
    echo 'RECORD          DNS record name to update (ex. mycompany.example.com)'
    echo 'TTL             DNS TTL of the record (in seconds)'
}
missingParam() {
    echo "Missing required parameter."
}

CF_API=https://api.cloudflare.com/client/v4

SERVICE=${1-${SERVICE:-}}
RECORD=${2:-${RECORD:-}}
TTL=${3:-${TTL:-}}
CONSUL=${CONSUL:-${CONSUL_PORT_8500_TCP_ADDR:-}} # allows links to work

: ${CF_ROOT_DOMAIN?"$(missingParam)$(usage)"}
: ${CF_API_KEY?"$(missingParam)$(usage)"}
: ${CF_AUTH_EMAIL?"$(missingParam)$(usage)"}
: ${SERVICE?"$(missingParam)$(usage)"}
: ${RECORD?"$(missingParam)$(usage)"}
: ${TTL?"$(missingParam)$(usage)"}
: ${CONSUL?"$(missingParam)$(usage)"}

# get all the healthy Nginx nodes and get a comma-deliminated value for the A-record
VALUE=$(curl -s ${CONSUL}:8500/v1/health/service/${SERVICE}?passing | jq -r 'map(.Node.Address)|join(",")')
echo ${VALUE}
if [ -f /tmp/${SERVICE} ]
then
    OLD_VALUE=$(</tmp/${SERVICE})
    if [ "$VALUE" == "$OLD_VALUE" ]
    then
        echo "$(date -u "+%Y-%m-%dT%H:%M:%SZ") ${SERVICE} unchanged"
        echo ${VALUE} > /tmp/${SERVICE}
        exit
    fi
fi
echo ${VALUE} > /tmp/${SERVICE}
echo "$(date -u "+%Y-%m-%dT%H:%M:%SZ") ${SERVICE} updated: ${VALUE}"

# https://api.cloudflare.com/#zone-list-zones
ZONE_ID=$(curl --fail -sX GET "${CF_API}/zones/?name=${CF_ROOT_DOMAIN}" \
     -H "X-Auth-Key:${CF_API_KEY}" \
     -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
     -H "Content-Type: application/json" | jq -r .result[0].id)
echo DNS zone ID: ${ZONE_ID}

# https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records
REC_ID=$(curl -sX GET "${CF_API}/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD}&page=1&per_page=1&order=type&direction=desc&match=all" \
     -H "X-Auth-Key:${CF_API_KEY}" \
     -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
     -H "Content-Type: application/json" | jq -r .result[0].id)
echo DNS record ID: ${REC_ID}

# https://api.cloudflare.com/#dns-records-for-a-zone-update-dns-record
curl -X PUT "${CF_API}/zones/${ZONE_ID}/dns_records/${REC_ID}" \
     -H "X-Auth-Key:${CF_API_KEY}" \
     -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
     -H "Content-Type: application/json" \
     --data "$(printf '{"id":"%s","type":"A","name":"%s","content":"%s","ttl":%s}' $REC_ID $RECORD $VALUE $TTL)"
