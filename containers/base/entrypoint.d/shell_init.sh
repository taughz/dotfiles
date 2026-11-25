#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# This should never happen, but check anyway
if [ -z "${VOL_SHELL_DIR:-}" ]; then
    echo "ERROR: Essential shell variable is not defined!" >&2
    exit 1
fi

# Always create the symlink in the home directory
ln -s $VOL_SHELL_DIR/bash/bash_history $HOME/.bash_history

exec "$@"
