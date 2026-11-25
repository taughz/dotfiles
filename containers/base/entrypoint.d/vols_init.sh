#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# This should never happen, but check anyway
if [ -z "${VOLS_INIT_DIR:-}" ]; then
    echo "ERROR: Essential volume variable is not defined!" >&2
    exit 1
fi

is_empty_dir() {
    find "$1" -maxdepth 0 -type d -empty | grep -q .
}

# Volumes are discovered automatically from their environment variables. They
# are optionally initialized if a matching tarball is found.
for vol in $(printenv | sed -n 's;^VOL_[A-Z0-9_]*_DIR=;;p' | sort); do
    tarball=$VOLS_INIT_DIR/$(basename $vol).tar.gz
    if [ ! -f $tarball ] || ! is_empty_dir $vol; then
        continue
    fi
    echo "Initializing volume: $vol"
    tar -C $vol --extract -f $tarball
done

exec "$@"
