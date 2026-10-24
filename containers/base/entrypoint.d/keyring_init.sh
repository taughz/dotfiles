#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Start GNOME Keyring on the session bus. This will be used by some tools to
# store credentials, such as GitHub and Atlassian CLIs.

if [ $(id -u) -eq 0 -o -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    exec "$@"
fi

# We don't really need a password, but we need to provide one anyway, so we use
# a throwaway one that doesn't matter.
if ! printf %s "container-local-keyring-not-a-secret" \
    | gnome-keyring-daemon --unlock --components=secrets --daemonize &> /dev/null; then
    echo "WARNING: Failed to create the keyring!" >&2
fi

exec "$@"
