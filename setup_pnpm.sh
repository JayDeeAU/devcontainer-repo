#!/bin/bash

# This script sets up pnpm and installs dependencies for JavaScript components

# Main project directory
PROJECT_DIR="/workspace"

# Find all directories containing a package.json file, one level down
JS_COMPONENTS=$(find "$PROJECT_DIR" -maxdepth 2 -mindepth 2 -name package.json -exec dirname {} \;)

echo "Found JavaScript components:"
echo "$JS_COMPONENTS"
echo "-------------------------"

if [ -z "$JS_COMPONENTS" ]; then
    echo "No JavaScript components found with package.json files."
    exit 0
fi

# Function to set up pnpm for a specific directory
setup_pnpm_for_dir() {
    local dir=$1
    if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
        echo "Setting up pnpm for $dir"
        cd "$dir"
        pnpm install
        cd - > /dev/null
    else
        echo "Skipping pnpm setup for $dir (directory not found or no package.json)"
    fi
}

# Set up pnpm for each component
for component in $JS_COMPONENTS; do
    setup_pnpm_for_dir "$component"
done


echo "pnpm setup completed for all JavaScript components."