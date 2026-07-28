#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# This should never happen, but check anyway
if [ -z "${EMACS_CONFIG_DIR:-}" -o -z "${EMACS_CONFIG_TARBALL:-}" \
     -o -z "${DOOM_CONFIG_DIR:-}" -o -z "${DOOM_CONFIG_TARBALL:-}" ]; then
    echo "ERROR: Essential Emacs variables are not defined!" >&2
    exit 1
fi

is_empty_dir() {
    find "$1" -maxdepth 0 -type d -empty | grep -q .
}

if is_empty_dir $EMACS_CONFIG_DIR; then
    echo "Initializing Emacs config: $EMACS_CONFIG_DIR"
    tar -C $EMACS_CONFIG_DIR --extract -f $EMACS_CONFIG_TARBALL
fi

if is_empty_dir $DOOM_CONFIG_DIR; then
    echo "Initializing Doom config: $DOOM_CONFIG_DIR"
    tar -C $DOOM_CONFIG_DIR --extract -f $DOOM_CONFIG_TARBALL
fi

exec "$@"
