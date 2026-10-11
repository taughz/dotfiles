#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Start a single D-Bus session bus for the container, so that everything in the
# container (shells, Xpra, etc) can share it. The bus uses the standard socket
# path, `$XDG_RUNTIME_DIR/bus`. Root has no runtime directory, so root gets no
# bus. If an address was passed into the container, just use that instead.

if [ $(id -u) -eq 0 -o -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
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
