#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# The container never has private keys. Instead it gets a copy of the host's
# public keyring, and uses the host's restricted ("extra") agent socket, which
# can sign and decrypt but cannot export or modify keys. The image config sets
# `no-autostart`, so GPG fails rather than starting a local agent.

if [ $(id -u) -eq 0 ]; then
    exec "$@"
fi

HOST_GNUPG_DIR="$HOME/.host/gnupg"

[ -d $HOME/.gnupg ] || mkdir -m 700 $HOME/.gnupg

for file in pubring.kbx trustdb.gpg; do
    if [ -f $HOST_GNUPG_DIR/$file ]; then
        install -m 600 $HOST_GNUPG_DIR/$file $HOME/.gnupg/$file
    fi
done

if [ ! -f $HOME/.gnupg/pubring.kbx ]; then
    echo "WARNING: No public keyring from the host, GPG will not work!" >&2
fi

agent_socket=$(gpgconf --list-dirs agent-socket 2> /dev/null || true)
if [ -z "$agent_socket" -o ! -S "$agent_socket" ]; then
    echo "WARNING: No GPG agent socket from the host, GPG will not work!" >&2
fi

exec "$@"
