#!/bin/bash

# Copyright (c) 2024 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SUDO=$([ $(id -u) -ne 0 ] && echo 'sudo' || echo '')

if [ -z "${VOLS_DIR:-}" -o -z "${DEV_USER_UID:-}" -o -z "${DEV_USER_GID:-}" ]; then
    echo "ERROR: Critical environment variables are not defined!" >&2
    exit 1
fi

for vol in $(find $VOLS_DIR -mindepth 1 -maxdepth 1 -type d); do
    if [ $(stat -c '%u:%g' $vol) = "$DEV_USER_UID:$DEV_USER_GID" ]; then
        continue
    fi
    $SUDO chown -R $DEV_USER_UID:$DEV_USER_GID $vol
done

exec "$@"
