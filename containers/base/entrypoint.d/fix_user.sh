#!/bin/bash

# Copyright (c) 2024 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# NOTE This should run BEFORE `login_shim.sh` the login shim.

# If the user UID and GID does not match the host user UID and GID, then we need
# to correct that once in the entry point. Of course, there is no way to know
# the host user UID and GID inside the container, so those must be supplied as
# environment variables to the container. If those environment variables aren't
# set, then this entry point doesn't do anything.

if [ -z "${FIXED_DEV_USER:-}" -o -z "${FIXED_DEV_USER_UID:-}" ]; then
    exec "$@"
fi

if [ $(id -u) -ne 0 ]; then
    echo "ERROR: Fixing the user at runtime requires root!" >&2
    exit 1
fi

if [ -z "${DEV_USER:-}" -o -z "${DEV_USER_UID:-}" -o -z "${DEV_USER_GID:-}" \
     -o -z "${DEV_USER_HOME:-}" -o -z "${VOLS_DIR:-}" ]; then
    echo "ERROR: Critical environment variables are not defined!" >&2
    exit 1
fi

# Save the old user values (but don't export them)
OLD_DEV_USER=$DEV_USER
OLD_DEV_USER_UID=$DEV_USER_UID
OLD_DEV_USER_GID=$DEV_USER_GID
OLD_DEV_USER_HOME=$DEV_USER_HOME

# We need to override the environment variables set within the container
export DEV_USER DEV_USER_UID DEV_USER_GID DEV_USER_FULLNAME DEV_USER_HOME DEV_USER_SHELL
DEV_USER=$FIXED_DEV_USER
DEV_USER_UID=$FIXED_DEV_USER_UID
DEV_USER_GID=${FIXED_DEV_USER_GID:-$FIXED_DEV_USER_UID}
DEV_USER_FULLNAME=${FIXED_DEV_USER_FULLNAME:-$FIXED_DEV_USER}
DEV_USER_HOME=${FIXED_DEV_USER_HOME:-"/home/$FIXED_DEV_USER"}
DEV_USER_SHELL=${FIXED_DEV_USER_SHELL:-"/bin/bash"}

# Update user info, move home, and update ownership. We use the --non-unique
# flag here because we have no control over the user's host system and they
# might be using IDs that conflict with what's in the container. In particular,
# on macOS the staff group (GID 20) conflicts with the dialout group (GID 20).
groupmod --new-name $DEV_USER --gid $DEV_USER_GID --non-unique $OLD_DEV_USER
usermod --non-unique --login $DEV_USER --uid $DEV_USER_UID --gid $DEV_USER_GID \
    --comment "$DEV_USER_FULLNAME,,," --home $DEV_USER_HOME --shell $DEV_USER_SHELL $OLD_DEV_USER

# Make the home directory and move files into it. This is can be easy or
# complicated, depending on if it already exists because of bind mounts. Bind
# mounted files cannot be moved, so they must be done in the fixed user home
# ahead of time. But then we cannot move the old home to the new home, because
# the directory already exists.
if [ $DEV_USER_HOME != $OLD_DEV_USER_HOME ]; then
    if [ ! -d $DEV_USER_HOME ]; then
        mv $OLD_DEV_USER_HOME $DEV_USER_HOME
    else
        (cd $OLD_DEV_USER_HOME && tar c .) | (cd $DEV_USER_HOME && tar xf -)
        rm -rf $OLD_DEV_USER_HOME
    fi
fi

# Update ownership if necessary
if [ $DEV_USER_UID -ne $OLD_DEV_USER_UID -o $DEV_USER_GID -ne $OLD_DEV_USER_GID ]; then
    if [ $DEV_USER_UID -ne $OLD_DEV_USER_UID ]; then
        rm -rf /run/user/$OLD_DEV_USER_UID
        # The new directory may already exists because of bind mounts
        [ ! -d "/run/user/" ] && mkdir -m 755 /run/user
        [ ! -d "/run/user/$DEV_USER_UID" ] && mkdir -m 700 /run/user/$DEV_USER_UID
    fi
    chown -R $DEV_USER_UID:$DEV_USER_GID $DEV_USER_HOME
    chown $DEV_USER_UID:$DEV_USER_GID /run/user/$DEV_USER_UID
    for vol in $(find $VOLS_DIR -mindepth 1 -maxdepth 1 -type d); do
        if [ $(stat -c '%u:%g' $vol) = "$DEV_USER_UID:$DEV_USER_GID" ]; then
            continue
        fi
        chown -R $DEV_USER_UID:$DEV_USER_GID $vol
    done
fi

# Update sudoers file
sed -i "s;$OLD_DEV_USER;$DEV_USER;" /etc/sudoers

# Update necessary environment variables
PATH=$(echo $PATH | sed "s;$OLD_DEV_USER_HOME;$DEV_USER_HOME;g")

# Switch to the new home directory
cd $DEV_USER_HOME

exec gosu $DEV_USER_UID:$DEV_USER_GID "$@"
