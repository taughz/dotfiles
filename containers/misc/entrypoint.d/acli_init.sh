#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Do ACLI login, but only if there are credentials present. Otherwise just
# continue without a warning.

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" -o -z "${ATLASSIAN_API_KEY:-}" ]; then
    exec "$@"
fi

if [ -z "${ACLI_SITE:-}" -o -z "${ACLI_EMAIL:-}" ]; then
    echo "WARNING: ACLI_SITE and ACLI_EMAIL are required to authenticate ACLI!" >&2
    exec "$@"
fi

if ! printf %s "$ATLASSIAN_API_KEY" \
    | timeout 30 acli jira auth login --site "$ACLI_SITE" --email "$ACLI_EMAIL" --token > /dev/null; then
    echo "WARNING: Failed to login to Jira for ACLI!" >&2
    exec "$@"
fi

exec "$@"
