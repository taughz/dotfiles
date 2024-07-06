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
readonly SHELL_CONFIG_VOL="shell-config"
readonly EMACS_CONFIG_VOL="emacs-config"
readonly DOOM_CONFIG_VOL="doom-config"

# The default projects directory
readonly DEFAULT_PROJECTS_DIR="$HOME/Projects"

# Usage: show_usage
#
# Prints help message for this script.
function show_usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-h | --help]

Run the Taughz development container.

    -p | --projects [DIR]   Bind mount projects directory
    -z | --tz               Use the host timezone
    -h | --help             Display this help message
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

# Usage: ensure_exists [f|d] MODE PATH
#
# Ensure that a file or directory exists. If it does not exist, create the file
# or directory with the given permissions.
function ensure_exists() {
    local fod="$1"
    local mode="$2"
    local path="$3"
    if [ -e "$path" ]; then
        return 0
    fi
    case "$fod" in
        "f" | "file") touch "$path";;
        "d" | "dir") mkdir -p "$path";;
        *) echo "ERROR: ensure_exists must specify 'f' or 'd'" >&2; return 1;;
    esac
    chmod "$mode" "$path"
}

# Default options
mount_projects=0
projects_dir=$DEFAULT_PROJECTS_DIR
use_tz=0

# Convert long options to short options, preserving order
for arg in "${@}"; do
    case "${arg}" in
        "--projects") set -- "${@}" "-p";;
        "--tz") set -- "${@}" "-z";;
        "--help") set -- "${@}" "-h";;
        *) set -- "${@}" "${arg}";;
    esac
    shift
done

# Parse short options using getopts
while getopts "pzh" arg &>/dev/null; do
    case "${arg}" in
        "p")
            mount_projects=1
            [ $OPTIND -le $# ] && next_opt=${!OPTIND} || next_opt="-"
            if ! printf "%s\n" "$next_opt" | grep -q "^-"; then
                projects_dir=$next_opt
                OPTIND=$((OPTIND + 1))
            fi;;
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

# Check projects directory
if [ $mount_projects -ne 0 -a ! -d "$projects_dir" ]; then
    echo "ERROR: Projecs directory must exist: $projects_dir" >&2
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
readonly SHELL_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "SHELL_CONFIG_DIR")
readonly EMACS_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "EMACS_CONFIG_DIR")
readonly DOOM_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "DOOM_CONFIG_DIR")

# Check for volumes, create them if necessary
need_ownership_fix=0
declare -a vols=($SHELL_CONFIG_VOL $EMACS_CONFIG_VOL $DOOM_CONFIG_VOL)
for vol in "${vols[@]}"; do
    if ! docker volume ls -q | grep -q $vol; then
        echo "Creating volume: $vol" >&2
        docker volume create $vol > /dev/null
        need_ownership_fix=1
    fi
done

# Fix ownership if necessary
if [ $need_ownership_fix -ne 0 ]; then
    docker run --rm  \
        --mount "type=volume,src=$SHELL_CONFIG_VOL,dst=$SHELL_CONFIG_DIR" \
        --mount "type=volume,src=$EMACS_CONFIG_VOL,dst=$EMACS_CONFIG_DIR" \
        --mount "type=volume,src=$DOOM_CONFIG_VOL,dst=$DOOM_CONFIG_DIR" \
        $TARGET_CONTAINER /fix_ownership.sh
fi

# Ensure the files and directories we expect exist
ensure_exists f 600 $HOME/.Xauthority
ensure_exists d 700 $HOME/.ssh
ensure_exists d 700 $HOME/.gnupg
ensure_exists f 644 $HOME/.gitconfig
ensure_exists d 700 $HOME/.xpra

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

readonly -a XPRA_FLAGS=(
    --mount "type=bind,src=$HOME/.xpra,dst=$DEV_USER_HOME/.xpra"
)

readonly -a SHELL_FLAGS=(
    --mount "type=volume,src=$SHELL_CONFIG_VOL,dst=$SHELL_CONFIG_DIR"
)

declare -a emacs_flags=()
if [ -n "$EMACS_CONFIG_DIR" -a -n "$DOOM_CONFIG_DIR" ]; then
    emacs_flags+=(--mount "type=volume,src=$EMACS_CONFIG_VOL,dst=$EMACS_CONFIG_DIR")
    emacs_flags+=(--mount "type=volume,src=$DOOM_CONFIG_VOL,dst=$DOOM_CONFIG_DIR")
fi

declare -a projects_flags=()
if [ $mount_projects -ne 0 ]; then
    projects_basename=$(basename "$projects_dir")
    projects_flags+=(--mount "type=bind,src=$projects_dir,dst=$DEV_USER_HOME/$projects_basename")
fi

declare -a tz_flags=()
if [ $use_tz -ne 0 ]; then
    tz_flags+=(--mount "type=bind,src=/etc/timezone,dst=/etc/timezone")
    tz_flags+=(--mount "type=bind,src=/etc/localtime,dst=/etc/localtime")
fi

docker run --rm --tty --interactive --privileged --network=host --env "TERM=$TERM" \
    "${DISPLAY_FLAGS[@]}" "${SSH_FLAGS[@]}" "${GPG_FLAGS[@]}" "${GIT_FLAGS[@]}" \
    "${XPRA_FLAGS[@]}" "${SHELL_FLAGS[@]}" "${emacs_flags[@]}" \
    "${projects_flags[@]}" "${tz_flags[@]}" "$TARGET_CONTAINER"

exit 0
