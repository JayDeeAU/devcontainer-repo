#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if code command is available
if ! command_exists code; then
    echo "Error: VS Code CLI (code) is not available. Make sure VS Code is installed and in your PATH." >&2
    exit 1
fi

# Get the list of extensions, add quotes, and commas
extensions=$(code --list-extensions | tail -n +2 | sed 's/.*/"&",/' | sed '$ s/,$//')

# Save to file
echo "[$extensions]" > /workspace/.devcontainer/vscode_extensions.json

echo "Extensions list has been saved to .devcontainer/vscode_extensions.json"