#!/bin/bash

set -ex

# Graceful shutdown handler
shutdown_handler() {
	echo "Shutting down gracefully..."

	# Stop warp-svc if running
	if pgrep -x "warp-svc" >/dev/null; then
		echo "Stopping warp-svc..."
		pkill -TERM warp-svc
		sleep 2
	fi

	# Stop dbus-daemon if running
	if pgrep -x "dbus-daemon" >/dev/null; then
		echo "Stopping dbus-daemon..."
		pkill -TERM dbus-daemon
		sleep 1
	fi

	exit 0
}

# Trap SIGTERM and SIGINT signals
trap shutdown_handler SIGTERM SIGINT

ls -al /dev/net/tun

if ! pgrep -x "dbus-daemon" >/dev/null; then
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

if [[ ! -f /var/lib/cloudflare-warp/settings.json ]]; then
	cp /etc/default/cloudflare-warp-settings.json /var/lib/cloudflare-warp/settings.json
fi

/bin/sleep 10 # wait for network stack to settle
ip addr show
ip route show

# Run warp-svc in the background and wait for it
/usr/bin/warp-svc &
WARP_PID=$!

# Wait for warp-svc process
wait $WARP_PID
