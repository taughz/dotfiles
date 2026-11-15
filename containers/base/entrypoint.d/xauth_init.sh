#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# The host X11 cookie is mounted read-only, so copy it into place. Then tools in
# the container, like Xpra, can add cookies for their own displays.

if [ $(id -u) -eq 0 ]; then
    exec "$@"
fi

HOST_XAUTHORITY="$HOME/.host/Xauthority"

if [ -f $HOST_XAUTHORITY ]; then
    install -m 600 $HOST_XAUTHORITY $HOME/.Xauthority
fi

exec "$@"
