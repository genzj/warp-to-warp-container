#!/bin/bash

set -ex

# create a tun device
# mkdir -p /dev/net
# mknod /dev/net/tun c 10 200
# chmod 666 /dev/net/tun
ls -al /dev/net/tun

if ! pgrep -x "dbus-daemon" > /dev/null
then
    rm -f /run/dbus/pid
    mkdir -p "/var/run/dbus"
    # export DBUS_SESSION_BUS_ADDRESS=$(dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address | cut -d, -f1)

    # or:
    dbus-daemon --config-file=/usr/share/dbus-1/system.conf
    # and put in Dockerfile:
    # ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/var/run/dbus/system_bus_socket"
else
    echo "dbus-daemon already running"
fi

if [[ ! -f /var/lib/cloudflare-warp/settings.json ]] ; then
    cp /etc/default/cloudflare-warp-settings.json /var/lib/cloudflare-warp/settings.json
fi

/bin/sleep 10  # wait for network stack to settle
ip addr show
ip route show
/usr/bin/warp-svc
