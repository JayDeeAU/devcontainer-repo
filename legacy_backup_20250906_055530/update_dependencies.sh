#!/bin/bash

# This script updates dependencies for both Python and JavaScript components

# Function to update Poetry dependencies
update_poetry_deps() {
    local dir=$1
    if [ -d "$dir" ] && [ -f "$dir/pyproject.toml" ]; then
        echo "Updating Poetry dependencies for $dir"
        cd "$dir"
        poetry update
        cd - > /dev/null
    fi
}

# Function to update pnpm dependencies
update_pnpm_deps() {
    local dir=$1
    if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
        echo "Updating pnpm dependencies for $dir"
        cd "$dir"
        pnpm update
        cd - > /dev/null
    fi
}

# Main project directory
PROJECT_DIR="/workspace"

# Find and update Python components
PYTHON_COMPONENTS=$(find "$PROJECT_DIR" -name pyproject.toml -exec dirname {} \;)
for component in $PYTHON_COMPONENTS; do
    update_poetry_deps "$component"
done

# Find and update JavaScript components
JS_COMPONENTS=$(find "$PROJECT_DIR" -name package.json -exec dirname {} \;)
for component in $JS_COMPONENTS; do
    update_pnpm_deps "$component"
done

echo "All dependencies updated."