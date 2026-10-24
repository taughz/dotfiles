#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Start a single D-Bus session bus for the container, so that everything in the
# container can share it. Root doesn't get a bus.

unset DBUS_SESSION_BUS_ADDRESS

if [ $(id -u) -eq 0 ]; then
    exec "$@"
fi

export XDG_RUNTIME_DIR
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

# Any existing socket is stale from a previous run, and the daemon replaces it
bus_address="unix:path=$XDG_RUNTIME_DIR/bus"
if dbus-daemon --session --address="$bus_address" --fork; then
    export DBUS_SESSION_BUS_ADDRESS
    DBUS_SESSION_BUS_ADDRESS=$bus_address
else
    echo "WARNING: Failed to start the D-Bus session bus!" >&2
fi

exec "$@"
