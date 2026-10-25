#!/bin/bash

# Copyright (c) 2026 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Do ACLI login, but only if there are credentials present. Otherwise just
# continue without a warning.

if [ $(id -u) -eq 0 -o -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    exec "$@"
fi

ACLI_TOKEN_ENTRY="atlassian/token"
ACLI_SITE_ENTRY="atlassian/site"
ACLI_EMAIL_ENTRY="atlassian/email"

if [ ! -f "$HOME/.password-store/$ACLI_TOKEN_ENTRY.gpg" ]; then
    exec "$@"
fi

# If we have the token, these are required as well
acli_site=$(pass show $ACLI_SITE_ENTRY 2> /dev/null | head -n 1 || true)
acli_email=$(pass show $ACLI_EMAIL_ENTRY 2> /dev/null | head -n 1 || true)
if [ -z "$acli_site" -o -z "$acli_email" ]; then
    echo "WARNING: The site and email are required to authenticate ACLI!" >&2
    exec "$@"
fi

if ! pass show $ACLI_TOKEN_ENTRY 2> /dev/null | head -n 1 | tr -d '\n' \
    | timeout 30 acli jira auth login --site "$acli_site" --email "$acli_email" --token > /dev/null; then
    echo "WARNING: Failed to login to Jira for ACLI!" >&2
    exec "$@"
fi

exec "$@"
