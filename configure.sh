#!/usr/bin/env bash

CONF_FILE="dev.conf"

# If config file doesn't exist, create it from the example
if [ ! -f "$CONF_FILE" ]; then
    cp dev.conf.example "$CONF_FILE"
fi

# Function to update a value in the config file
update_config() {
    local key=$1
    local value=$2
    sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$CONF_FILE"
}

# Parse command-line arguments
while [ "$1" != "" ]; do
    case $1 in
        --enable-gpu)
            update_config "ENABLE_GPU_SUPPORT" "true"
            update_config "INSTALL_CUDA_IN_CONTAINER" "true"
            ;;
        --disable-gpu)
            update_config "ENABLE_GPU_SUPPORT" "false"
            update_config "INSTALL_CUDA_IN_CONTAINER" "false"
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

echo "Configuration updated:"
cat "$CONF_FILE"