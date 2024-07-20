#!/bin/bash

# Copyright (c) 2023 Tim Perkins

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

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

# Check for root
if [ $(id -u) -eq 0 ]; then
    echo "ERROR: Do not run this script as root!" >&2
    exit 1
fi

# Validate sudo session
sudo -v
while true; do sudo -v; sleep 60; done &
trap "kill $!" EXIT

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

# Add the current user to the Docker group
docker_users=$(getent group docker | cut -d : -f 4 | tr , '\n')
if ! echo "$docker_users" | grep -q "^$(id -un)\$"; then
    sudo usermod --append --groups docker $(id -un)
    echo "WARNING: User was added to the 'docker' group, please log out!" >&2
fi

exit 0
