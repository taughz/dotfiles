#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# The container to launch
readonly TARGET_CONTAINER="taughz-dev:latest"

# The names of the volumes
readonly EMACS_CONFIG_VOL="emacs-config"
readonly DOOM_CONFIG_VOL="doom-config"

# Usage: show_usage
#
# Prints help message for this script.
function show_usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-h | --help]

Run the Taughz development container.

    -z | --tz       Use the host timezone
    -h | --help     Display this help message
EOF
}

# Usage: get_from_env ENV VAR
#
# Get a variable from an environment, as produced by printenv or similar. The
# variables are expected to have the format 'VAR=VALUE'.
function get_from_env() {
    local env="$1"
    local var="$2"
    echo "$env" | grep "^$var=" | cut -d = -f 2
}

# Default options
use_tz=0

# Convert long options to short options, preserving order
for arg in "${@}"; do
    case "${arg}" in
        "--tz") set -- "${@}" "-z";;
        "--help") set -- "${@}" "-h";;
        *) set -- "${@}" "${arg}";;
    esac
    shift
done

# Parse short options using getopts
while getopts "zh" arg &>/dev/null; do
    case "${arg}" in
        "z") use_tz=1;;
        "h") show_usage; exit 0;;
        "?") show_usage; exit 1;;
    esac
done

# Shift positional arguments into place
shift $((${OPTIND} - 1))

# There are no positional arguments
if [ ${#} -gt 0 ]; then
    show_usage
    exit 1
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is required!" >&2
    exit 1
fi

# The variables from inside the container
readonly CONTAINER_ENV=$(docker run --rm $TARGET_CONTAINER printenv)
readonly DEV_USER_HOME=$(get_from_env "$CONTAINER_ENV" "DEV_USER_HOME")
readonly DEV_USER_UID=$(get_from_env "$CONTAINER_ENV" "DEV_USER_UID")
readonly EMACS_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "EMACS_CONFIG_DIR")
readonly DOOM_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "DOOM_CONFIG_DIR")

# Check for volumes, create them if necessary
declare -a vols=($EMACS_CONFIG_VOL $DOOM_CONFIG_VOL)
for vol in "${vols[@]}"; do
    if ! docker volume ls -q | grep -q $vol; then
        echo "Creating volume: $vol" >&2
        docker volume create $vol > /dev/null
    fi
done

readonly -a DISPLAY_FLAGS=(
    --env "DISPLAY=$DISPLAY"
    --mount "type=bind,src=$XAUTHORITY,dst=/root/.Xauthority,readonly"
)

readonly -a SSH_FLAGS=(
    --mount "type=bind,src=$HOME/.ssh,dst=$DEV_USER_HOME/.ssh"
)

readonly -a GPG_FLAGS=(
    --mount "type=bind,src=$HOME/.gnupg,dst=$DEV_USER_HOME/.gnupg"
    --mount "type=bind,src=/run/user/$(id -u)/gnupg,dst=/run/user/$DEV_USER_UID/gnupg,readonly"
)

readonly -a GIT_FLAGS=(
    --mount "type=bind,src=$HOME/.gitconfig,dst=$DEV_USER_HOME/.gitconfig"
)

readonly -a EMACS_FLAGS=(
    --mount "type=volume,src=$EMACS_CONFIG_VOL,dst=$EMACS_CONFIG_DIR"
    --mount "type=volume,src=$DOOM_CONFIG_VOL,dst=$DOOM_CONFIG_DIR"
)

readonly -a WORKSPACE_FLAGS=(
    --mount "type=bind,src=$HOME/Projects,dst=$DEV_USER_HOME/Projects"
)

declare -a tz_flags=()
if [ $use_tz -ne 0 ]; then
    tz_flags+=(--mount "type=bind,src=/etc/timezone,dst=/etc/timezone")
    tz_flags+=(--mount "type=bind,src=/etc/localtime,dst=/etc/localtime")
fi

docker run --rm --tty --interactive --network=host --env "TERM=$TERM" \
    "${DISPLAY_FLAGS[@]}" "${SSH_FLAGS[@]}" "${GPG_FLAGS[@]}" "${GIT_FLAGS[@]}" \
    "${EMACS_FLAGS[@]}" "${WORKSPACE_FLAGS[@]}" "${tz_flags[@]}" \
    "$TARGET_CONTAINER"

exit 0