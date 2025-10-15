#!/usr/bin/env bash
source ./dev.conf

USERNAME="$USER"
USER_ID=$(id -u)
USER_GID=$(id -g)

# Define the directory on your host containing the SSH keys
# you want to pass to the container.
# This can be your default ~/.ssh or a custom directory.
SSH_DIR_HOST=~/.ssh

# We copy the SSH directory into the current directory to include it in the
# build context, then clean it up afterwards.
cp -r $SSH_DIR_HOST .
SSH_DIR_CONTEXT=$(basename $SSH_DIR_HOST)

docker build --build-arg SSH_DIR="$SSH_DIR_CONTEXT" \
  --build-arg INSTALL_CUDA_IN_CONTAINER="$INSTALL_CUDA_IN_CONTAINER" \
  --build-arg USERNAME="$USERNAME" \
  --build-arg USER_UID="$USER_ID" \
  --build-arg USER_GID="$USER_GID" \
  -f Dockerfile -t dev-container:latest .

# Clean up the copied SSH directory.
rm -rf $SSH_DIR_CONTEXT
