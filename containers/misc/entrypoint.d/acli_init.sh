#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# ACLI keeps its credential in a Secret Service keyring on the session bus. The
# keyring only lives in the container, so start it and log in once at startup
# (if there is a token). Failures only warn, so the container still starts.

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" -o -z "${ATLASSIAN_API_KEY:-}" ]; then
    exec "$@"
fi

if [ -z "${ACLI_SITE:-}" -o -z "${ACLI_EMAIL:-}" ]; then
    echo "WARNING: ACLI_SITE and ACLI_EMAIL are required to authenticate ACLI!" >&2
    exec "$@"
fi

# The keyring is created fresh in the container and only holds the ACLI
# credential, but gnome-keyring refuses to create one without a password. This
# password guards nothing, so it is not a secret.
if ! printf %s "container-local-keyring-not-a-secret" \
    | gnome-keyring-daemon --unlock --components=secrets --daemonize &> /dev/null; then
    echo "WARNING: Failed to create keyring for ACLI!" >&2
    exec "$@"
fi

if ! printf %s "$ATLASSIAN_API_KEY" \
    | timeout 30 acli jira auth login --site "$ACLI_SITE" --email "$ACLI_EMAIL" --token > /dev/null; then
    echo "WARNING: Failed to login to Jira for ACLI!" >&2
    exec "$@"
fi

exec "$@"
