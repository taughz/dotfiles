#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

HN2B="hn2b.sh"

IMAGE_REPO="taughz-dev"
DEFAULT_TARGET_TAG="latest"

DOOM_CACHE_REPO="taughz-dev-doom-cache"

IMAGES=("BASE" "CPP" "PYTHON" "ROS" "EMSDK" "EMACS" "XPRA" "USER")

declare -A IMAGE_DIRS=(
    ["BASE"]="$SCRIPT_DIR/base"
    ["CPP"]="$SCRIPT_DIR/cpp"
    ["PYTHON"]="$SCRIPT_DIR/python"
    ["ROS"]="$SCRIPT_DIR/ros"
    ["EMSDK"]="$SCRIPT_DIR/emsdk"
    ["EMACS"]="$SCRIPT_DIR/emacs"
    ["DOOM_CACHE"]="$SCRIPT_DIR/emacs/doom_cache"
    ["XPRA"]="$SCRIPT_DIR/xpra"
    ["USER"]="$SCRIPT_DIR/user"
)

# Usage: show_usage
#
# Prints help message for this script.
function show_usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-t | --tag TAG] [-a | --all] [-c | --cpp]
            [-p | --python] [-r | --ros] [-w | --emsdk][-e | --emacs]
            [-x | --xpra] [-u | --user] [-k | --no-cache] [-n | --name]
            [-l | --log] [-h | --help]

Make the Taughz development image.

    -t | --tag TAG      Tag the image with the given tag
    -a | --all          Build all layers
    -c | --cpp          Build the C++ layer
    -p | --python       Build the Python layer
    -r | --ros          Build the ROS layer
    -w | --emsdk        Build the EMSDK (Emscripten) layer
    -e | --emacs        Build the Emacs layer
    -x | --xpra         Build the Xpra layer
    -u | --user         Build the user layer
    -k | --no-cache     Build without using cache
    -n | --name         Display the name of the layer
    -l | --log          Display plain progress during build
    -h | --help         Display this help message
EOF
}

# Default options
target_tag=$DEFAULT_TARGET_TAG
declare -A layer_requested=(
    ["BASE"]=1
    ["CPP"]=0
    ["PYTHON"]=0
    ["ROS"]=0
    ["EMSDK"]=0
    ["EMACS"]=0
    ["XPRA"]=0
    ["USER"]=0
)
no_cache=0
show_name=0
show_log=0

# Convert long options to short options, preserving order
for arg in "$@"; do
    case "$arg" in
        "--tag") set -- "$@" "-t";;
        "--all") set -- "$@" "-a";;
        "--cpp") set -- "$@" "-c";;
        "--python") set -- "$@" "-p";;
        "--ros") set -- "$@" "-r";;
        "--emsdk") set -- "$@" "-w";;
        "--emacs") set -- "$@" "-e";;
        "--xpra") set -- "$@" "-x";;
        "--user") set -- "$@" "-u";;
        "--no-cache") set -- "$@" "-k";;
        "--name") set -- "$@" "-n";;
        "--log") set -- "$@" "-l";;
        "--help") set -- "$@" "-h";;
        *) set -- "$@" "$arg";;
    esac
    shift
done

# Parse short options using getopts
while getopts "t:acprwexuknlh" arg &> /dev/null; do
    case "$arg" in
        "t") target_tag=$OPTARG;;
        "a") for co in "${IMAGES[@]}"; do layer_requested[$co]=1; done;;
        "c") layer_requested["CPP"]=1;;
        "p") layer_requested["PYTHON"]=1;;
        "r") layer_requested["ROS"]=1;;
        "w") layer_requested["EMSDK"]=1;;
        "e") layer_requested["EMACS"]=1;;
        "x") layer_requested["XPRA"]=1;;
        "u") layer_requested["USER"]=1;;
        "k") no_cache=1;;
        "n") show_name=1;;
        "l") show_log=1;;
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

# Determine the target image
TARGET_IMAGE="$IMAGE_REPO:$target_tag"

# Check for Docker
if ! command -v docker &> /dev/null && [ $show_name -eq 0 ]; then
    echo "ERROR: Docker is required!" >&2
    exit 1
fi

# Check for HN2B
if ! command -v $HN2B &> /dev/null; then
    echo "ERROR: HN2B is required!" >&2
    exit 1
fi

# Add extra build arguments
extra_args=()
if [ $no_cache -ne 0 ]; then
    extra_args+=("--no-cache")
fi
if [ $show_name -ne 0 ]; then
    extra_args+=("--name")
fi
if [ $show_log -ne 0 ]; then
    extra_args+=("--log")
fi

# Get Doom cache image ready
pre_emacs_args=()
if [ ${layer_requested["EMACS"]} -ne 0 ]; then
    hn2b_output=$($HN2B --script \
        "${extra_args[@]}" --file Containerfile $DOOM_CACHE_REPO "${IMAGE_DIRS['DOOM_CACHE']}")
    doom_cache_image=$(echo "$hn2b_output" | grep -Po "(?<=GENERATED_IMAGE=).*")
    pre_emacs_args=(--arg "DOOM_CACHE_IMAGE=$doom_cache_image")
fi

# Get the user data ready
pre_user_args=()
if [ ${layer_requested["USER"]} -ne 0 ]; then
    passwd_ent=$(getent passwd $(id -u))
    user_name=$(echo $passwd_ent | cut -d : -f 1)
    user_uid=$(echo $passwd_ent | cut -d : -f 3)
    user_gid=$(echo $passwd_ent | cut -d : -f 4)
    user_fullname=$(echo $passwd_ent | cut -d : -f 5 | cut -d , -f 1)
    pre_user_args=(
        --arg "CUSTOM_DEV_USER=$user_name"
        --arg "CUSTOM_DEV_USER_UID=$user_uid"
        --arg "CUSTOM_DEV_USER_GID=$user_gid"
        --arg "CUSTOM_DEV_USER_FULLNAME=$user_fullname"
    )
fi

# Loop through using the previous image as the base image
generated_image=""
for image in "${IMAGES[@]}"; do
    if [ ${layer_requested[$image]} -eq 0 ]; then
        continue
    fi
    base_image_args=()
    if [ -n "$generated_image" ]; then
        base_image_args=(--base "$generated_image")
    fi
    emacs_args=()
    if [ $image = "EMACS" ]; then
        emacs_args=("${pre_emacs_args[@]}")
    fi
    user_args=()
    if [ $image = "USER" ]; then
        user_args=("${pre_user_args[@]}")
    fi
    hn2b_output=$($HN2B --script \
        "${extra_args[@]}" "${base_image_args[@]}" "${emacs_args[@]}" "${user_args[@]}" \
        --file Containerfile $IMAGE_REPO "${IMAGE_DIRS[$image]}")
    generated_image=$(echo "$hn2b_output" | grep -Po "(?<=GENERATED_IMAGE=).*")
done

if [ $show_name -ne 0 ]; then
    echo $generated_image
    exit 0
fi

# Tag the final image with the target tag
docker tag $generated_image $TARGET_IMAGE >&2
echo "Tagged: $TARGET_IMAGE"

exit 0
