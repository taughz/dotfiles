#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -e

# When we do a typical login, it sets the environment variables such as HOME,
# USER, LOGNAME, SHELL, TERM, etc. Docker is nice enough to set HOME for us, but
# for whatever reason it does not set USER, LOGNAME, SHELL, and TERM. So we are
# going to do that now!

# See also: https://unix.stackexchange.com/a/76356

export USER=${USER:-$(id -u --name)}
export LOGNAME=${LOGNAME:-$(id -u --name)}
export SHELL=${SHELL:-$(getent passwd $(id -u) | cut -d : -f 7)}
export TERM=${TERM:-dumb}

exec "$@"
