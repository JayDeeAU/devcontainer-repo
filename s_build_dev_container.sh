#!/bin/bash

# Save the original value of SSH_HOST
ORIGINAL_SSH_HOST="$SSH_HOST"

# Define a cleanup function to restore SSH_HOST
cleanup() {
    export SSH_HOST="$ORIGINAL_SSH_HOST"
    rm -f "$DOCKERFILE_TMP_PATH"
}
trap cleanup EXIT

# Set SSH_HOST to 127.0.0.1 if DOCKER_HOST is not set
if [ -z "$DOCKER_HOST" ]; then
    SSH_HOST="127.0.0.1"
fi

WORKSPACE=/share/DevelopmentProjects/MagmaBI-Full
DEVCONTAINER_JSON_PATH="$WORKSPACE/.devcontainer/devcontainer.json"
DOCKERFILE_PATH_TMP="$WORKSPACE/.devcontainer/Dockerfile.tmp"
DOCKERFILE_PATH="$WORKSPACE/.devcontainer/Dockerfile"

# Remove comments from devcontainer.json and minify the JSON
LABEL_CONTENT=$(grep -v '^\s*//' "$DEVCONTAINER_JSON_PATH" | jq -c '.')

# Escape the JSON string for Docker label
ESCAPED_LABEL_CONTENT=$(printf '%s' "$LABEL_CONTENT" | jq -R '@json')

# Create a temporary Dockerfile with the LABEL appended
cp "$DOCKERFILE_PATH" "$DOCKERFILE_PATH_TMP"
echo -e "\nLABEL devcontainer.metadata=$ESCAPED_LABEL_CONTENT" >> "$DOCKERFILE_PATH_TMP"

# Append the LABEL instruction to the Dockerfile
echo -e "\nLABEL devcontainer.metadata='$LABEL_CONTENT'" >> "$DOCKERFILE_PATH_TMP"

echo "LABEL added to temp Dockerfile."

EXEC_CMD_BUILD="cd $WORKSPACE/.devcontainer && sudo docker build --pull --rm -f 'Dockerfile.tmp' -t codem_devcontainer:latest '.' && rm Dockerfile.tmp"

# Execute commands on the remote server using ssh
echo "Running command on $SSH_HOST: $EXEC_CMD_BUILD"
ssh "$SSH_HOST" -t "/bin/bash -c '$EXEC_CMD_BUILD'"
if [ $? -ne 0 ]; then
    echo "Error: Failed to build the dev container."
    exit 1
fi
echo "Dev container built successfully."