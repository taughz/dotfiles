#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

if [ -z "${ENTRYPOINT_DIR:-}" ]; then
    echo "ERROR: Critical environment variables are not defined!" >&2
    exit 1
fi

if [ ! -d $ENTRYPOINT_DIR ]; then
    echo "ERROR: The entry point directory does not exist!" >&2
    exit 1
fi

# Get the list of all entry points to be run together
readonly -a ENTRYPOINTS=($(find $ENTRYPOINT_DIR -name '*.sh' -type f | LC_ALL=C sort))

# Exec the chain of entry points. For this to work, each entry point must end
# with `exec "$@"` to invoke the next entry point in the chain.
exec "${ENTRYPOINTS[@]}" "$@"
