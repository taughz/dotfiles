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

# Entry points from the host are merged into the sequence by file name
ENTRYPOINT_DIRS=($ENTRYPOINT_DIR)
if [ -d "${HOST_ENTRYPOINT_DIR:-}" ]; then
    ENTRYPOINT_DIRS+=($HOST_ENTRYPOINT_DIR)
fi

# Get the list of all entry points to be run together, ordered by file name
ENTRYPOINT_ENTS=$(find "${ENTRYPOINT_DIRS[@]}" -name '*.sh' -type f -printf '%f\t%p\n')
ENTRYPOINTS=($(printf '%s\n' "$ENTRYPOINT_ENTS" | LC_ALL=C sort | cut -f 2))

# Sanity check that all entry points are executable
for entrypoint in "${ENTRYPOINTS[@]}"; do
    if [ ! -x $entrypoint ]; then
        echo "ERROR: Entry point is not executable: $entrypoint" >&2
        exit 1
    fi
done

# Exec the chain of entry points. For this to work, each entry point must end
# with `exec "$@"` to invoke the next entry point in the chain.
exec "${ENTRYPOINTS[@]}" "$@"
