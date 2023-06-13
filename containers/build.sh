#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

readonly CONTAINER_REPO="taughz-dev"

readonly -a CONTAINERS=("BASE" "EMACS" "EMSDK" "USER")

readonly -A CONTAINER_DIRS=(
    ["BASE"]="$SCRIPT_DIR/base"
    ["EMACS"]="$SCRIPT_DIR/emacs"
    ["EMSDK"]="$SCRIPT_DIR/emsdk"
    ["USER"]="$SCRIPT_DIR/user"
)

readonly -A CONTAINER_ALPHAS=(
    ["BASE"]="b"
    ["EMACS"]="e"
    ["EMSDK"]="w"
    ["USER"]="u"
)

# Usage: show_usage
#
# Prints help message for this script.
function show_usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-n | --name] [-h | --help]

Make the Taughz development container.

    -e | --emacs    Build the Emacs container
    -w | --emsdk    Build the EMSDK (Emscripten) container
    -n | --name     Display the name of the container
    -h | --help     Display this help message
EOF
}

# Usage: md5sum_dir_contents DIR
#
# Get the combined MD5 sum of every file in a directory.
function md5sum_dir_contents() {
    local target_dir="$1"
    local -a target_files=($(find "$target_dir" -type f | LC_ALL=C sort))
    cat "${target_files[@]}" | md5sum - | cut -d ' ' -f 1
}

# Default options
declare -A container_requested=(
    ["BASE"]=1
    ["EMACS"]=0
    ["EMSDK"]=0
    ["USER"]=1
)
show_name=0

# Convert long options to short options, preserving order
for arg in "${@}"; do
    case "${arg}" in
        "--emacs") set -- "${@}" "-e";;
        "--emsdk") set -- "${@}" "-w";;
        "--name") set -- "${@}" "-n";;
        "--help") set -- "${@}" "-h";;
        *) set -- "${@}" "${arg}";;
    esac
    shift
done

# Parse short options using getopts
while getopts "ewnh" arg &>/dev/null; do
    case "${arg}" in
        "e") container_requested["EMACS"]=1;;
        "w") container_requested["EMSDK"]=1;;
        "n") show_name=1;;
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

# Get the MD5 sums of the container build contexts
declare -A container_md5sum=()
for container in "${CONTAINERS[@]}"; do
    if [ ${container_requested[$container]} -eq 0 ]; then
        container_md5sum[$container]=""
        continue
    fi
    container_md5sum[$container]=$(md5sum_dir_contents "${CONTAINER_DIRS[$container]}")
done

# Get the container tags
declare -A container_tag=()
previous_tag=""
for container in "${CONTAINERS[@]}"; do
    if [ ${container_requested[$container]} -eq 0 ]; then
        container_tag[$container]=""
        continue
    fi
    next_part=""
    [ -n "$previous_tag" ] && next_part="-"
    next_part="$next_part${CONTAINER_ALPHAS[$container]}"
    [ $container != "USER" ] && next_part="$next_part${container_md5sum[$container]:0:4}"
    container_tag[$container]="$previous_tag$next_part"
    previous_tag=${container_tag[$container]}
done

# Get the container names
declare -A container_name=()
for container in "${CONTAINERS[@]}"; do
    if [ ${container_requested[$container]} -eq 0 ]; then
        container_name[$container]=""
        continue
    fi
    container_name[$container]="$CONTAINER_REPO:${container_tag[$container]}"
    container_name["LATEST"]=${container_name[$container]}
done

# Show the name if requested
if [ $show_name -ne 0 ]; then
    echo ${container_name["LATEST"]}
    exit 0
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is required!" >&2
    exit 1
fi

# Check for each container
declare -A container_exists=()
for container in "${CONTAINERS[@]}"; do
    if [ ${container_requested[$container]} -eq 0 ]; then
        container_exists[$container]=0
        continue
    fi
    container_exists[$container]=0
    if [ -n "$(docker image ls -q ${container_name[$container]})" ]; then
        container_exists[$container]=1
    fi
done

# Get the user data ready
declare -a user_buildargs=()
if [ ${container_exists["USER"]} -eq 0 ]; then
    passwd_ent=$(getent passwd $(id -u))
    user_name=$(echo ${passwd_ent} | cut -d : -f 1)
    user_uid=$(echo ${passwd_ent} | cut -d : -f 3)
    user_gid=$(echo ${passwd_ent} | cut -d : -f 4)
    user_fullname=$(echo ${passwd_ent} | cut -d : -f 5 | cut -d , -f 1)
    user_buildargs+=("--build-arg" "CUSTOM_DEV_USER=$user_name")
    user_buildargs+=("--build-arg" "CUSTOM_DEV_USER_UID=$user_uid")
    user_buildargs+=("--build-arg" "CUSTOM_DEV_USER_GID=$user_gid")
    user_buildargs+=("--build-arg" "CUSTOM_DEV_USER_FULLNAME=$user_fullname")
fi

# Build each container
previous_container=""
for container in "${CONTAINERS[@]}"; do
    # Skip containers that we don't want in the build
    if [ ${container_requested[$container]} -eq 0 ]; then
        continue
    fi
    # Build the container if we need to
    if [ ${container_exists[$container]} -eq 0 ]; then
        echo "Building: ${container_name[$container]}"
        # Set the base container, except for the base container
        declare -a base_buildargs=()
        if [ $container != "BASE" ]; then
            base_buildargs=(
                "--build-arg" "BASE_CONTAINER=${container_name[$previous_container]}"
            )
        fi
        # Set the md5sum, except for the user container
        declare -a md5sum_buildargs=()
        if [ $container != "USER" ]; then
            md5sum_buildargs=(
                "--build-arg" "${container}_CONTAINER_MD5SUM=${container_md5sum[$container]}"
            )
        fi
        # Set the user variables, only for the user container
        declare -a maybe_user_buildargs=()
        if [ $container = "USER" ]; then
            maybe_user_buildargs=("${user_buildargs[@]}")
        fi
        # Build the container!
        (cd "${CONTAINER_DIRS[$container]}" \
            && docker build \
                "${base_buildargs[@]}" "${md5sum_buildargs[@]}" "${maybe_user_buildargs[@]}" \
                -t ${container_name[$container]} -f Containerfile .)
    else
        echo "Has: ${container_name[$container]}"
    fi
    previous_container=$container
done

# Tag the final container with the latest tag
docker tag ${container_name["LATEST"]} "$CONTAINER_REPO:latest"

exit 0
