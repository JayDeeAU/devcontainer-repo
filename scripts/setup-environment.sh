#!/usr/bin/env bash
# scripts/setup-environment.sh
# Complete environment setup - dotfiles, project dependencies, and docker context

set -e

echo "🚀 Setting up development environment..."

# Setup dotfiles
echo "🏠 Setting up dotfiles..."
if [ ! -d ~/dotfiles ]; then
    git clone https://github.com/JayDeeAU/dotfiles.git ~/dotfiles
    cd ~/dotfiles
    chmod +x ./dotbootstrap.sh
    ./dotbootstrap.sh || echo "⚠️ Dotfiles setup failed, continuing..."
    cd -
else
    echo "📁 Dotfiles directory already exists, skipping clone"
fi

# Setup VSCode workspace configuration
echo "⚙️ Setting up VSCode workspace configuration..."

# Create .vscode directory if it doesn't exist
mkdir -p .vscode

# Copy tasks.json from devcontainer to workspace .vscode folder
if [ -f ".devcontainer/tasks.json" ]; then
    echo "📋 Copying tasks.json to workspace .vscode folder..."
    cp .devcontainer/tasks.json .vscode/tasks.json
    echo "✅ Tasks configuration copied successfully"
else
    echo "⚠️ No tasks.json found in .devcontainer directory"
fi

# Setup project dependencies
echo "📦 Setting up project dependencies..."
chmod +x .devcontainer/scripts/setup-project-dependencies.sh
.devcontainer/scripts/setup-project-dependencies.sh

# Render governance files from base submodules (if present)
if [ -x "claude-base/base-init.sh" ]; then
    echo "📐 Rendering Claude Base governance files..."
    claude-base/base-init.sh --refresh || echo "⚠️ Claude Base rendering had warnings (non-blocking)"
fi
if [ -x "infra-base/scripts/infra-init.sh" ]; then
    echo "🏗️ Validating infrastructure configuration..."
    infra-base/scripts/infra-init.sh --validate || echo "⚠️ Infra validation had warnings (non-blocking)"
fi

# Set docker context
echo "🐳 Setting docker context..."
docker context use default

echo "✅ Environment setup completed"
echo "💡 VSCode tasks are now available via Ctrl+F1"