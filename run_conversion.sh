#!/bin/bash
set -e

IMAGE_NAME="my-conversion-container"
CONTAINER_NAME="conversion-container"
DEST_DIR="./out"
LOG_TIMEOUT=600 

# Function to check if Docker is installed
check_docker_installed() {
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Installing Docker..."
        # Installation steps (omitted for brevity)
    else
        echo "Docker is already installed."
    fi
}

# Function to clean up Docker container
cleanup() {
    echo "Stopping and removing the Docker container..."
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
}

# Trap signals and call cleanup function
trap cleanup EXIT

# Check and install Docker if necessary
check_docker_installed

# Ensure timeout command is available and in PATH
# Installation steps for timeout (omitted for brevity)

# Add coreutils to PATH if installed by Homebrew
if command -v brew &> /dev/null; then
    export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
fi

# Remove any existing container with the same name
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Removing existing container..."
    docker stop $CONTAINER_NAME > /dev/null 2>&1 || true
    docker rm $CONTAINER_NAME > /dev/null 2>&1 || true
fi

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME .

# Run the Docker container
echo "Running Docker container..."
docker run --privileged -d --name $CONTAINER_NAME -v /lib/modules:/lib/modules:ro $IMAGE_NAME

# Function to check logs for completion message with timeout
listen_to_logs_for_completion() {
    timeout $LOG_TIMEOUT docker logs -f $CONTAINER_NAME | while read -r line; do
        echo "$line"
        if echo "$line" | grep -q "Conversion complete. Keeping container alive..."; then
            echo "Conversion completed successfully."
            break
        fi
    done

    if [ $? -eq 124 ]; then
        echo "Error: Conversion did not complete within the timeout period."
        exit 1
    fi
}

# Wait for the container to complete the conversion
echo "Waiting for conversion to complete..."
listen_to_logs_for_completion

# Check if the destination directory exists, create if it doesn't
if [ ! -d "$DEST_DIR" ]; then
    mkdir -p $DEST_DIR
fi

# Verify the output file exists before copying
echo "Checking if the output file exists in the container..."
if docker exec $CONTAINER_NAME test -f /usr/local/bin/out; then
    # Copy the output files to the local machine
    echo "Copying output files to local machine..."
    docker cp $CONTAINER_NAME:/usr/local/bin/out $DEST_DIR
    echo "Files copied to $DEST_DIR"
else
    echo "Error: Could not find the file /usr/local/bin/out in container $CONTAINER_NAME"
    exit 1
fi
