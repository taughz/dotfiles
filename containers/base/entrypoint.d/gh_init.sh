#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Do GitHub CLI login, but only if there are credentials present. Otherwise just
# continue without a warning.

if [ $(id -u) -eq 0 -o -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    exec "$@"
fi

has_bus_name() {
    dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus.NameHasOwner string:"$1" 2> /dev/null | grep -q 'boolean true'
}

GH_TOKEN_ENTRY="github/token"

if [ ! -f "$HOME/.password-store/$GH_TOKEN_ENTRY.gpg" ]; then
    echo "WARNING: No GitHub token in the password store, GitHub CLI is not authenticated!" >&2
    exec "$@"
fi

# Without a keyring, the GitHub CLI would store the token in plain text
if ! has_bus_name org.freedesktop.secrets; then
    echo "WARNING: No keyring, GitHub CLI is not authenticated!" >&2
    exec "$@"
fi

if ! pass show $GH_TOKEN_ENTRY 2> /dev/null | head -n 1 \
    | timeout 30 gh auth login --hostname github.com --with-token &> /dev/null; then
    echo "WARNING: Failed to login to GitHub CLI!" >&2
fi

exec "$@"
