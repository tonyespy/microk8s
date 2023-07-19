#!/bin/bash

servicefile=/var/snap/avahi/common/etc/avahi/services/microk8s.service
tokenfile=/var/snap/microk8s/current/credentials/cluster-tokens.txt
interval=5
while sleep $interval; do
    if [ -z "$(avahi.browse -rtp --ignore-local _microk8s-cluster._tcp)" ]; then
        interval=60
        # if the service doesn't exist, we'll publish it
        # this token could be pre-shared and perhaps modified with the current time
        token=0aaaaabbbbbcccccdddddeeeeefffff0
        # if the token doesn't exist, create it and advertise it
        if ! grep -q $token $tokenfile; then
            url=$(microk8s add-node --token $token --token-ttl -1 --format short | awk '{print $3; exit}')
            cat <<EOF > $servicefile
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_microk8s-cluster._tcp</type>
    <port>25000</port>
    <txt-record>$url</txt-record>
  </service>
</service-group>
EOF     
        fi
    else
        url=$(avahi.browse -rtp --ignore-local _microk8s-cluster._tcp | awk -F';' '/^=/{print $NF; exit}' 2>/dev/null | tr -d '"')
        if [ -n "$url" ]; then
            microk8s join $url
            if [ "$?" -eq 0 ]; then
                echo Clustered
                exit
            fi
        fi
    fi
done