#!/usr/bin/env bash
source ./dev.conf

USERNAME="$USER"
GPU_FLAG=""
DOCKER_GID=$(getent group docker | cut -d: -f3)

if [ -z "$DOCKER_GID" ]; then
    echo "Error: 'docker' group not found on host."
    echo "Please run 'sudo groupadd docker && sudo usermod -aG docker $USER'"
    echo "Then, log out and log back in before re-running this script."
    exit 1
fi

# Conditionally add the --gpus flag
if [ "$ENABLE_GPU_SUPPORT" = "true" ]; then
    GPU_FLAG="--gpus all"
fi

# Create our persistent directories on the host if they don't exist.
# This ensures they are created with the correct host user permissions.
mkdir -p repos data articles viewer

docker run -it \
  --name "dev-container" \
  --restart always \
  --cap-add=SYS_NICE \
  --cap-add=SYS_PTRACE \
  $GPU_FLAG \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add $DOCKER_GID \
  -v "$(pwd)/articles:/home/$USERNAME/articles" \
  -v "$(pwd)/viewer:/home/$USERNAME/viewer" \
  -v "$(pwd)/data:/home/$USERNAME/data" \
  -v "$(pwd)/repos:/home/$USERNAME/repos" \
  -p 127.0.0.1:10200:22 \
  -p 127.0.0.1:10201:8888 \
  -p 127.0.0.1:10202:8889 \
  dev-container:latest