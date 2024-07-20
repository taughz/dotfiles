#!/bin/bash

# Copyright (c) 2024 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

if [ -z "${OLD_DEV_USER_HOME:-}" -o -z "${DEV_USER_HOME:-}" ]; then
    echo "ERROR: Critical environment variables are not defined!" >&2
    exit 1
fi

# Fix the path, replacing the old HOME directory
PATH="$(echo $PATH | sed "s;$OLD_DEV_USER_HOME;$DEV_USER_HOME;g")"

exec "$@"
