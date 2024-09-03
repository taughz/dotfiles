#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# The container to launch
CONTAINER_REPO="taughz-dev"
DEFAULT_TARGET_TAG="latest"

# The names of the volumes
SHELL_CONFIG_VOL="shell-config"
EMACS_CONFIG_VOL="emacs-config"
DOOM_CONFIG_VOL="doom-config"

# The default projects directory
DEFAULT_PROJECTS_DIR="$HOME/Projects"

# Usage: show_usage
#
# Prints help message for this script.
function show_usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-t | --tag TAG] [-p | --projects [DIR]] [-z | --tz] [-h | --help]

Run the Taughz development container.

    -t | --tag TAG          Run the container with the given tag
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
target_tag=$DEFAULT_TARGET_TAG
mount_projects=0
projects_dir=$DEFAULT_PROJECTS_DIR
use_tz=0

# Convert long options to short options, preserving order
for arg in "$@"; do
    case "$arg" in
        "--tag") set -- "$@" "-t";;
        "--projects") set -- "$@" "-p";;
        "--tz") set -- "$@" "-z";;
        "--help") set -- "$@" "-h";;
        *) set -- "$@" "$arg";;
    esac
    shift
done

# Parse short options using getopts
while getopts "t:pzh" arg &> /dev/null; do
    case "$arg" in
        "t") target_tag=$OPTARG;;
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
shift $((OPTIND - 1))

# There are no positional arguments
if [ $# -gt 0 ]; then
    show_usage
    exit 1
fi

# Determine the target container
TARGET_CONTAINER="$CONTAINER_REPO:$target_tag"

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
CONTAINER_ENV=$(docker run --rm $TARGET_CONTAINER printenv)
DEV_USER=$(get_from_env "$CONTAINER_ENV" "DEV_USER")
DEV_USER_UID=$(get_from_env "$CONTAINER_ENV" "DEV_USER_UID")
DEV_USER_HOME=$(get_from_env "$CONTAINER_ENV" "DEV_USER_HOME")
SHELL_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "SHELL_CONFIG_DIR")
EMACS_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "EMACS_CONFIG_DIR" || true)
DOOM_CONFIG_DIR=$(get_from_env "$CONTAINER_ENV" "DOOM_CONFIG_DIR" || true)

# Check for volumes, create them if necessary
vols=($SHELL_CONFIG_VOL $EMACS_CONFIG_VOL $DOOM_CONFIG_VOL)
for vol in "${vols[@]}"; do
    if ! docker volume ls -q | grep -q $vol; then
        echo "Creating volume: $vol" >&2
        docker volume create $vol > /dev/null
    fi
done

# Ensure the files and directories we expect exist
ensure_exists f 600 $HOME/.Xauthority
ensure_exists d 700 $HOME/.ssh
ensure_exists d 700 $HOME/.gnupg
ensure_exists f 644 $HOME/.gitconfig
ensure_exists d 700 $HOME/.xpra

# Get the user data ready
passwd_ent=$(getent passwd $(id -u))
user_name=$(echo $passwd_ent | cut -d : -f 1)
user_uid=$(echo $passwd_ent | cut -d : -f 3)
user_gid=$(echo $passwd_ent | cut -d : -f 4)
user_fullname=$(echo $passwd_ent | cut -d : -f 5 | cut -d , -f 1)

# Determine if we need to fix the user at runtime
fixed_user=$([ $user_name != $DEV_USER -o $user_uid -ne $DEV_USER_UID ] && echo 1 || echo 0)

fixed_user_flags=()
if [ $fixed_user -ne 0 ]; then
    echo "Detected user mismatch, user will be fixed at runtime" >&2
    fixed_user_flags+=(--user root)
    fixed_user_flags+=(--env "FIXED_DEV_USER=$user_name")
    fixed_user_flags+=(--env "FIXED_DEV_USER_UID=$user_uid")
    fixed_user_flags+=(--env "FIXED_DEV_USER_GID=$user_gid")
    fixed_user_flags+=(--env "FIXED_DEV_USER_FULLNAME=$user_fullname")
fi

# The home directory inside the container
CHOME=$([ $fixed_user -eq 0 ] && echo $DEV_USER_HOME || echo "/home/$user_name")

DISPLAY_FLAGS=(
    --env "DISPLAY=$DISPLAY"
    --mount "type=bind,src=$XAUTHORITY,dst=/root/.Xauthority,readonly"
)

SSH_FLAGS=(
    --mount "type=bind,src=$HOME/.ssh,dst=$CHOME/.ssh"
)

GPG_FLAGS=(
    --mount "type=bind,src=$HOME/.gnupg,dst=$CHOME/.gnupg"
    --mount "type=bind,src=/run/user/$user_uid/gnupg,dst=/run/user/$user_uid/gnupg,readonly"
)

GIT_FLAGS=(
    --mount "type=bind,src=$HOME/.gitconfig,dst=$CHOME/.gitconfig"
)

XPRA_FLAGS=(
    --mount "type=bind,src=$HOME/.xpra,dst=$CHOME/.xpra"
)

SHELL_FLAGS=(
    --mount "type=volume,src=$SHELL_CONFIG_VOL,dst=$SHELL_CONFIG_DIR"
)

emacs_flags=()
if [ -n "$EMACS_CONFIG_DIR" -a -n "$DOOM_CONFIG_DIR" ]; then
    emacs_flags+=(--mount "type=volume,src=$EMACS_CONFIG_VOL,dst=$EMACS_CONFIG_DIR")
    emacs_flags+=(--mount "type=volume,src=$DOOM_CONFIG_VOL,dst=$DOOM_CONFIG_DIR")
fi

projects_flags=()
if [ $mount_projects -ne 0 ]; then
    projects_basename=$(basename "$projects_dir")
    projects_flags+=(--mount "type=bind,src=$projects_dir,dst=$CHOME/$projects_basename")
fi

tz_flags=()
if [ $use_tz -ne 0 ]; then
    tz_flags+=(--mount "type=bind,src=/etc/timezone,dst=/etc/timezone")
    tz_flags+=(--mount "type=bind,src=/etc/localtime,dst=/etc/localtime")
fi

docker run --rm --tty --interactive --privileged --network=host --env "TERM=$TERM" \
    "${DISPLAY_FLAGS[@]}" "${SSH_FLAGS[@]}" "${GPG_FLAGS[@]}" "${GIT_FLAGS[@]}" \
    "${XPRA_FLAGS[@]}" "${SHELL_FLAGS[@]}" "${fixed_user_flags[@]}" "${emacs_flags[@]}" \
    "${projects_flags[@]}" "${tz_flags[@]}" "$TARGET_CONTAINER"

exit 0
