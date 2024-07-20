#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

CONTAINER_REPO="taughz-dev"
DEFAULT_TARGET_TAG="latest"

CONTAINERS=("BASE" "CPP" "ROS" "EMSDK" "EMACS" "XPRA" "USER")

declare -A CONTAINER_DIRS=(
    ["BASE"]="$SCRIPT_DIR/base"
    ["CPP"]="$SCRIPT_DIR/cpp"
    ["ROS"]="$SCRIPT_DIR/ros"
    ["EMSDK"]="$SCRIPT_DIR/emsdk"
    ["EMACS"]="$SCRIPT_DIR/emacs"
    ["XPRA"]="$SCRIPT_DIR/xpra"
    ["USER"]="$SCRIPT_DIR/user"
)

declare -A CONTAINER_ALPHAS=(
    ["BASE"]="b"
    ["CPP"]="c"
    ["ROS"]="r"
    ["EMSDK"]="w"
    ["EMACS"]="e"
    ["XPRA"]="x"
    ["USER"]="u"
)

# Usage: show_usage
#
# Prints help message for this script.
function show_usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-t | --tag TAG] [-a | --all] [-c | --cpp]
            [-r | --ros] [-w | --emsdk][-e | --emacs] [-x | --xpra]
            [-u | --user] [-k | --no-cache] [-n | --name]
            [-p | --plain] [-h | --help]

Make the Taughz development container.

    -t | --tag TAG      Tag the container with the given tag
    -a | --all          Build all containers
    -c | --cpp          Build the C++ container
    -r | --ros          Build the ROS container
    -w | --emsdk        Build the EMSDK (Emscripten) container
    -e | --emacs        Build the Emacs container
    -x | --xpra         Build the Xpra container
    -u | --user         Build the user container
    -k | --no-cache     Build without using cache
    -n | --name         Display the name of the container
    -p | --plain        Display plain progress during build
    -h | --help         Display this help message
EOF
}

# Usage: md5sum_dir_contents DIR
#
# Get the combined MD5 sum of every file in a directory.
function md5sum_dir_contents() {
    local target_dir target_files
    target_dir="$1"
    target_files=($(find "$target_dir" -type f | LC_ALL=C sort))
    cat "${target_files[@]}" | md5sum - | cut -d ' ' -f 1
}

# Default options
target_tag=$DEFAULT_TARGET_TAG
declare -A container_requested=(
    ["BASE"]=1
    ["CPP"]=0
    ["ROS"]=0
    ["EMSDK"]=0
    ["EMACS"]=0
    ["XPRA"]=0
    ["USER"]=0
)
no_cache=0
show_name=0
plain_progress=0

# Convert long options to short options, preserving order
for arg in "${@}"; do
    case "${arg}" in
        "--tag") set -- "${@}" "-t";;
        "--all") set -- "${@}" "-a";;
        "--cpp") set -- "${@}" "-c";;
        "--ros") set -- "${@}" "-r";;
        "--emsdk") set -- "${@}" "-w";;
        "--emacs") set -- "${@}" "-e";;
        "--xpra") set -- "${@}" "-x";;
        "--user") set -- "${@}" "-u";;
        "--no-cache") set -- "${@}" "-k";;
        "--name") set -- "${@}" "-n";;
        "--plain") set -- "${@}" "-p";;
        "--help") set -- "${@}" "-h";;
        *) set -- "${@}" "${arg}";;
    esac
    shift
done

# Parse short options using getopts
while getopts "t:acrwexuknph" arg &>/dev/null; do
    case "${arg}" in
        "t") target_tag=$OPTARG;;
        "a") for co in "${CONTAINERS[@]}"; do container_requested[$co]=1; done;;
        "c") container_requested["CPP"]=1;;
        "r") container_requested["ROS"]=1;;
        "w") container_requested["EMSDK"]=1;;
        "e") container_requested["EMACS"]=1;;
        "x") container_requested["XPRA"]=1;;
        "u") container_requested["USER"]=1;;
        "k") no_cache=1;;
        "n") show_name=1;;
        "p") plain_progress=1;;
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

# Determine the target container
TARGET_CONTAINER="$CONTAINER_REPO:$target_tag"

# Make buildkit show plain progress
if [ $plain_progress -ne 0 ]; then
    export BUILDKIT_PROGRESS="plain"
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

# Add extra build arguments
extra_buildargs=()
if [ $no_cache -ne 0 ]; then
    extra_buildargs=("--no-cache")
fi

# Get the user data ready
user_buildargs=()
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
        base_buildargs=()
        if [ $container != "BASE" ]; then
            base_buildargs=(
                "--build-arg" "BASE_CONTAINER=${container_name[$previous_container]}"
            )
        fi
        # Set the md5sum, except for the user container
        md5sum_buildargs=()
        if [ $container != "USER" ]; then
            md5sum_buildargs=(
                "--build-arg" "${container}_CONTAINER_MD5SUM=${container_md5sum[$container]}"
            )
        fi
        # Set the user variables, only for the user container
        maybe_user_buildargs=()
        if [ $container = "USER" ]; then
            maybe_user_buildargs=("${user_buildargs[@]}")
        fi
        # Build the container!
        (cd "${CONTAINER_DIRS[$container]}" \
            && docker build "${extra_buildargs[@]}" \
                "${base_buildargs[@]}" "${md5sum_buildargs[@]}" "${maybe_user_buildargs[@]}" \
                -t ${container_name[$container]} -f Containerfile .)
    else
        echo "Has: ${container_name[$container]}"
    fi
    previous_container=$container
done

# Tag the final container with the target tag
docker tag ${container_name["LATEST"]} $TARGET_CONTAINER

exit 0
