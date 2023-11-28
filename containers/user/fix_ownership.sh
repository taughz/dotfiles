#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -e

if [ $(id -u) -eq 0 ]; then
    echo "ERROR: This script should NOT be run as root!" >&2
    exit 1
fi

if [ -z "$VOLS_DIR" -o -z "$DEV_USER_UID" -o -z "$DEV_USER_GID" ]; then
    echo "ERROR: Critical environment variables are not defined!" >&2
    exit 1
fi

for vol in $(find $VOLS_DIR -mindepth 1 -maxdepth 1 -type d); do
    if [ $(stat -c '%u:%g' $vol) = "$DEV_USER_UID:$DEV_USER_GID" ]; then
        continue
    fi
    sudo chown -R $DEV_USER_UID:$DEV_USER_GID $vol
done

exit 0
