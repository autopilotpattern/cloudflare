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
writeLog() {
    echo $(date -u "+%Y-%m-%dT%H:%M:%SZ") $@
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


# get all the healthy nodes for our service and assign to an array for our A-records
getFromConsul() {
    CURRENT=( $(curl -s ${CONSUL}:8500/v1/health/service/${SERVICE}?passing | jq -r '[.[].Service.Address]|sort|.[]') )
    : ${CURRENT?"No Consul records found."}
}


# https://api.cloudflare.com/#zone-list-zones
getZone() {
    ZONE_ID=$(curl --fail -sX GET "${CF_API}/zones/?name=${CF_ROOT_DOMAIN}" \
                   -H "X-Auth-Key:${CF_API_KEY}" \
                   -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
                   -H "Content-Type: application/json" | jq -r .result[0].id)
    : ${ZONE_ID?"No zone found."}
    writeLog "DNS zone ID:" ${ZONE_ID}
}


# https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records
getRecords() {
    RECORDS=$(curl -sX GET "${CF_API}/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD}&page=1&per_page=20&order=type&direction=desc&match=all" \
                  -H "X-Auth-Key:${CF_API_KEY}" \
                  -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
                  -H "Content-Type: application/json")
    : ${RECORDS?"No records found."}
    writeLog "DNS record IDs:" $(echo ${RECORDS} | jq -r '.result[].id')
}


compareRecords() {
    # we need the ID of old records in order to delete them but bash doesn't
    # support multi-dimensional arrays so we'll just use two w/ the same indexes
    OLD=( $(echo $RECORDS | jq -r '[.result[].content]|sort|.[]') )
    OLD_IDS=( $(echo $RECORDS | jq -r '[.result[].id]|sort|.[]') )

    writeLog old=${OLD[*]}
    writeLog current=${CURRENT[*]}

    # if we only have one record and have none to remove, we just want
    # to update it
    if [[ ${#CURRENT[*]} == 1 ]]; then
        if [[ ${#OLD[*]} == 1 ]]; then
            updateRecord ${OLD_IDS[0]} ${CURRENT}
            return 0
        fi
    fi

    # add new records before removing the old ones so that we can do a
    # rolling deploy
    for new in ${CURRENT[*]}
    do
        if ! contains OLD $new; then
            addRecord $new
        fi
    done

    # remove any stale records (exists in old but not in new)
    for ((i=0;i < ${#OLD[*]};i++)) {
            local old=${OLD[i]}
            if ! contains CURRENT $old; then
                deleteRecord ${OLD_IDS[i]} $old
            fi
         }
}


# utility to check if array contains a string value
contains() {
    local array="$1[@]"
    local search=$2
    local found=1
    for element in "${!array}"; do
        if [[ $element == $search ]]; then
            found=0
            break
        fi
    done
    return $found
}

# https://api.cloudflare.com/#dns-records-for-a-zone-update-dns-record
updateRecord() {
    local id=$1
    local value=$2
    writeLog "updateRecord:" ${id}, ${value}
    curl -sX PUT "${CF_API}/zones/${ZONE_ID}/dns_records/${id}" \
         -H "X-Auth-Key:${CF_API_KEY}" \
         -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
         -H "Content-Type: application/json" \
         --data "$(printf '{"id":"%s","type":"A","name":"%s","content":"%s","ttl":%s}' ${id} $RECORD $value $TTL)"
}


# https://api.cloudflare.com/#dns-records-for-a-zone-create-dns-record
addRecord(){
    local value=$1
    writeLog "addRecord:" ${value}
    curl -sX POST "${CF_API}/zones/${ZONE_ID}/dns_records" \
         -H "X-Auth-Key:${CF_API_KEY}" \
         -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
         -H "Content-Type: application/json" \
         --data "$(printf '{"type":"A","name":"%s","content":"%s","ttl":%s}' $REC_ID $RECORD $value $TTL)"
}


# https://api.cloudflare.com/#dns-records-for-a-zone-delete-dns-record
deleteRecord() {
    local id=$1
    local value=$2
    writeLog "deleteRecord:" ${id} ${value}
    curl -sX DELETE "${CF_API}/zones/${ZONE_ID}/dns_records/${id}" \
         -H "X-Auth-Key:${CF_API_KEY}" \
         -H "X-Auth-Email:${CF_AUTH_EMAIL}" \
         -H "Content-Type: application/json"
}


run() {
    getFromConsul
    getZone
    getRecords
    compareRecords
}

# `. update-dns.sh --source` will import all functions without executing
# the `run` function, enabling standalone testing of each function
if [ "$1" != "--source" ]; then
    run "${@}"
fi
