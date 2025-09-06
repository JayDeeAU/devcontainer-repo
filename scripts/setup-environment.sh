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

# Setup project dependencies
echo "📦 Setting up project dependencies..."
chmod +x .devcontainer/scripts/setup-project-dependencies.sh
.devcontainer/scripts/setup-project-dependencies.sh

# Set docker context
echo "🐳 Setting docker context..."
docker context use default

echo "✅ Environment setup completed"