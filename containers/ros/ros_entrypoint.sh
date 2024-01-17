#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

if [ -z "${ROS_DISTRO:-}" ]; then
    echo "ERROR: Critical environment variables are not defined!" >&2
    exit 1
fi

# Set up ROS environment variables
set +o nounset
source "/opt/ros/$ROS_DISTRO/setup.bash"

exec "$@"
