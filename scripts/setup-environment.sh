#!/usr/bin/env bash
# scripts/setup-environment.sh
# One-time environment setup — dotfiles and submodule initialization
# Runs as part of postCreateCommand (container creation only)

set -e

echo "🚀 Setting up development environment..."

# Setup dotfiles
echo "🏠 Setting up dotfiles..."
if [ ! -d ~/dotfiles ]; then
    DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/JayDeeAU/dotfiles.git}"
    git clone "$DOTFILES_REPO" ~/dotfiles
    cd ~/dotfiles
    chmod +x ./dotbootstrap.sh
    ./dotbootstrap.sh || echo "⚠️ Dotfiles setup failed, continuing..."
    cd -
else
    echo "📁 Dotfiles directory already exists, skipping clone"
fi

# Validate infrastructure configuration (if present)
if [ -x "infra-base/scripts/infra-init.sh" ]; then
    echo "🏗️ Validating infrastructure configuration..."
    infra-base/scripts/infra-init.sh --validate || echo "⚠️ Infra validation had warnings (non-blocking)"
fi

echo "✅ Environment setup completed"
