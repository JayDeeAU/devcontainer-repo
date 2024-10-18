#!/bin/bash

# This script sets up Poetry and creates virtual environments for Python components

# Function to set up Poetry for a specific directory
setup_poetry_for_dir() {
    local dir=$1
    if [ -d "$dir" ] && [ -f "$dir/pyproject.toml" ]; then
        echo "Setting up Poetry for $dir"
        
        # Change to the project directory
        cd "$dir"
        
        # Configure Poetry to create the virtual environment in the project directory
        poetry config virtualenvs.in-project true --local
        
        # Create the virtual environment if it doesn't exist
        if [ ! -d ".venv" ]; then
            echo "Creating virtual environment for $dir"
            poetry env use python3
        fi

        # Update the .env file with the current virtual environment path
        echo "PYTHON_VENV=$(poetry env info --path)" > .env
        
        # Install dependencies
        poetry install
        
        # Create a script to activate the virtual environment
        echo "#!/bin/bash
        source .venv/bin/activate" > activate_venv.sh
        chmod +x activate_venv.sh
        
        echo "Virtual environment created and dependencies installed for $dir"
        
        # Change back to the original directory
        cd - > /dev/null
    else
        echo "Skipping Poetry setup for $dir (directory not found or no pyproject.toml)"
    fi
}
# Main project directory
PROJECT_DIR="/workspace"

# Find all directories containing a pyproject.toml file
echo "Finding Python components with pyproject.toml files..."
PYTHON_COMPONENTS=$(find "$PROJECT_DIR" -maxdepth 2 -mindepth 2 -name pyproject.toml -exec dirname {} \; 2>/dev/null)
echo "Found Python components:"
echo "$PYTHON_COMPONENTS"
echo "-------------------------"


if [ -z "$PYTHON_COMPONENTS" ]; then
    echo "No Python components found with pyproject.toml files."
    exit 0
fi

# Set up Poetry for each component
for component in $PYTHON_COMPONENTS; do
    setup_poetry_for_dir "$component"
done

echo "Poetry setup completed for all Python components."