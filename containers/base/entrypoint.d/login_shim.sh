#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# When we do a typical login, it sets the environment variables such as HOME,
# USER, LOGNAME, SHELL, TERM, etc. Docker is nice enough to set HOME for us, but
# for whatever reason it does not set USER, LOGNAME, SHELL, and TERM. So we are
# going to do that now!

# See also: https://unix.stackexchange.com/a/76356

export USER LOGNAME SHELL TERM
USER=${USER:-$(id -u --name)}
LOGNAME=${LOGNAME:-$(id -u --name)}
SHELL=${SHELL:-$(getent passwd $(id -u) | cut -d : -f 7)}
TERM=${TERM:-dumb}

# XDG user directories
export XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}

# Don't give root a runtime directory
if [ $(id -u) -ne 0 ]; then
    export XDG_RUNTIME_DIR
    XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
fi

# XDG system directories
export XDG_DATA_DIRS XDG_CONFIG_DIRS
XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-/etc/xdg}

exec "$@"
