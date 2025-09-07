#!/usr/bin/env bash
# scripts/setup-project-dependencies
# Project dependency setup - runs only in actual projects, not devcontainer repos

set -e

# Debug PATH and Poetry location
echo "🔍 Debug: Current PATH: $PATH"
echo "🔍 Debug: Looking for Poetry..."
which poetry || echo "Poetry not found in PATH"

# Ensure Poetry is in PATH (it should be in /usr/local/bin from codemian-standards)
export PATH="/usr/local/bin:/root/.local/bin:/home/joe/.local/bin:$PATH"

# Check if we're in a devcontainer template/feature repo (skip setup)
if [ -d "features" ] && [ -d "templates" ] && [ -f "devcontainer.json" ]; then
    echo "🏗️ Detected devcontainer repository structure - skipping project dependency setup"
    exit 0
fi

echo "🚀 Setting up project dependencies..."

# Verify Poetry is available
if ! command -v poetry &> /dev/null; then
    echo "⚠️ Poetry not found in PATH, trying alternative installation..."
    curl -sSL https://install.python-poetry.org | python3 -
    export PATH="/home/joe/.local/bin:$PATH"
fi

# Poetry setup (if pyproject.toml exists)
if [ -f "pyproject.toml" ]; then
    echo "🐍 Setting up Poetry project..."
    poetry config virtualenvs.in-project true
    poetry install
fi

# pnpm setup (if package.json exists and not in node_modules)
if [ -f "package.json" ] && [[ "$PWD" != *"node_modules"* ]]; then
    echo "📦 Setting up pnpm project..."
    pnpm install
fi

# Auto-detect common monorepo structure
for dir in frontend backend api web server; do
    if [ -d "$dir" ]; then
        echo "📁 Found $dir directory, checking for dependencies..."
        
        if [ -f "$dir/pyproject.toml" ]; then
            echo "🐍 Setting up Poetry in $dir..."
            cd "$dir"
            poetry config virtualenvs.in-project true
            poetry install || echo "⚠️ Poetry install failed for $dir"
            cd ..
        fi
        
        if [ -f "$dir/package.json" ]; then
            echo "📦 Setting up pnpm in $dir..."
            cd "$dir"
            pnpm install || echo "⚠️ pnpm install failed for $dir"
            cd ..
        fi
    fi
done

echo "✅ Project dependencies setup completed"