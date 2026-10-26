#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

DOCKER_CONFLICT_PKGS=(
    "docker.io"
    "docker-doc"
    "docker-compose"
    "podman-docker"
    "containerd"
    "runc"
)

DOCKER_PKGS=(
    "docker-ce"
    "docker-ce-cli"
    "containerd.io"
    "docker-buildx-plugin"
    "docker-compose-plugin"
)

DOCKER_DEB_URL="https://download.docker.com/linux/ubuntu"
DOCKER_DEB_DIST="jammy"
DOCKER_DEB_COMP="stable"
DOCKER_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_KEY_FILE="/usr/share/keyrings/docker-keyring.gpg"
DOCKER_REPO_FILE="/etc/apt/sources.list.d/docker.list"

NVIDIA_PKGS=(
    "nvidia-container-toolkit"
)

NVIDIA_DEB_URL="https://nvidia.github.io/libnvidia-container/stable/deb/amd64"
NVIDIA_KEY_URL="https://nvidia.github.io/libnvidia-container/gpgkey"
NVIDIA_KEY_FILE="/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
NVIDIA_REPO_FILE="/etc/apt/sources.list.d/nvidia-container-toolkit.list"

# Check for root
if [ $(id -u) -eq 0 ]; then
    echo "ERROR: Do not run this script as root!" >&2
    exit 1
fi

# Validate sudo session
sudo -v
while true; do sudo -v; sleep 60; done &
trap "kill $!" EXIT

# Determine if Docker must be restarted to add the NVIDIA runtime
needs_docker_restart=0
if [ -e /proc/driver/nvidia/version ]; then
    docker_runtimes=$(sudo docker info --format '{{json .Runtimes}}' 2> /dev/null || true)
    if ! echo "$docker_runtimes" | grep -q '"nvidia"'; then
        needs_docker_restart=1
    fi
fi

# Restarting Docker would stop running containers, so refuse to do that
if [ $needs_docker_restart -ne 0 ]; then
    echo "WARNING: Docker must be restarted to add the NVIDIA runtime" >&2
    if [ -n "$(sudo docker ps -q 2> /dev/null || true)" ]; then
        echo "ERROR: Docker has running containers, please stop them first!" >&2
        exit 1
    fi
fi

# Install necessary utilities to get the key
if ! command -v curl &> /dev/null || ! command -v gpg &> /dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -qq -y curl gpg ca-certificates > /dev/null
fi

# Install the Docker keyring
if [ ! -f "$DOCKER_KEY_FILE" ]; then
    curl -fsSL "$DOCKER_KEY_URL" | sudo gpg --dearmor -o "$DOCKER_KEY_FILE"
    sudo chmod 644 "$DOCKER_KEY_FILE"
fi

# Add the Docker repo
if [ ! -f "$DOCKER_REPO_FILE" ]; then
    {
        echo "# Docker Repo for Ubuntu";
        echo "deb [arch=amd64 signed-by=$DOCKER_KEY_FILE] $DOCKER_DEB_URL $DOCKER_DEB_DIST $DOCKER_DEB_COMP";
    } | sudo tee "$DOCKER_REPO_FILE" > /dev/null
fi

# Install the Docker packages
sudo apt-get update -qq
sudo apt-get remove -qq -y "${DOCKER_CONFLICT_PKGS[@]}" > /dev/null
sudo apt-get install -qq -y "${DOCKER_PKGS[@]}" > /dev/null

# Add the Docker group if necessary
if ! getent group docker &> /dev/null; then
    sudo groupadd --system docker
fi

# Warnings are deferred to the end, so they are not lost in the output
added_docker_group=0

# Add the current user to the Docker group
docker_users=$(getent group docker | cut -d : -f 4 | tr , '\n')
if ! echo "$docker_users" | grep -q "^$(id -un)\$"; then
    sudo usermod --append --groups docker $(id -un)
    added_docker_group=1
fi

# The NVIDIA Container Toolkit is only needed with the proprietary NVIDIA driver
if [ -e /proc/driver/nvidia/version ]; then
    # Install the NVIDIA Container Toolkit keyring
    if [ ! -f "$NVIDIA_KEY_FILE" ]; then
        curl -fsSL "$NVIDIA_KEY_URL" | sudo gpg --dearmor -o "$NVIDIA_KEY_FILE"
        sudo chmod 644 "$NVIDIA_KEY_FILE"
    fi

    # Add the NVIDIA Container Toolkit repo
    if [ ! -f "$NVIDIA_REPO_FILE" ]; then
        {
            echo "# NVIDIA Container Toolkit Repo";
            echo "deb [arch=amd64 signed-by=$NVIDIA_KEY_FILE] $NVIDIA_DEB_URL /";
        } | sudo tee "$NVIDIA_REPO_FILE" > /dev/null
    fi

    # Install the NVIDIA Container Toolkit packages
    sudo apt-get update -qq
    sudo apt-get install -qq -y "${NVIDIA_PKGS[@]}" > /dev/null

    # Register the NVIDIA runtime with Docker, which requires a restart
    if [ $needs_docker_restart -ne 0 ]; then
        sudo nvidia-ctk runtime configure --runtime=docker > /dev/null
        sudo systemctl restart docker
    fi
fi

if [ $added_docker_group -ne 0 ]; then
    echo "WARNING: User was added to the 'docker' group, please log out!" >&2
fi

exit 0
