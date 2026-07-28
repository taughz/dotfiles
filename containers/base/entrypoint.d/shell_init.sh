#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# This should never happen, but check anyway
if [ -z "${SHELL_CONFIG_DIR:-}" ]; then
    echo "ERROR: Essential shell variable is not defined!" >&2
    exit 1
fi

is_empty_dir() {
    find "$1" -maxdepth 0 -type d -empty | grep -q .
}

bash_config_dir=$SHELL_CONFIG_DIR/bash

if is_empty_dir $SHELL_CONFIG_DIR; then
    mkdir -m 700 $bash_config_dir
    touch $bash_config_dir/bash_history
fi

# Always create the symlink in the home directory
ln -s $bash_config_dir/bash_history $HOME/.bash_history

exec "$@"
