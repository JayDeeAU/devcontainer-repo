#!/usr/bin/env bash
# features/claude-code/install.sh
# Install Claude Code CLI with persistent credentials

set -e

echo "🤖 Installing Claude Code AI Assistant..."

# Get configuration from feature options
INSTALL_LATEST=${INSTALLLATEST:-true}
CREATE_ALIASES=${CREATEALIASES:-true}
SETUP_AUTOCOMPLETION=${SETUPAUTOCOMPLETION:-true}
API_KEY_PERSISTENCE=${APIKEYPERSISTENCE:-true}

# Handle user situation - could be vscode or joe depending on feature order
CONTAINER_USER=""
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
    echo "✅ Found joe user (UID: $(id -u joe), GID: $(id -g joe))"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
    echo "✅ Found vscode user (UID: $(id -u vscode), GID: $(id -g vscode))"
    echo "💡 Note: Using vscode user - joe user will be created later by common-utils"
else
    echo "❌ No suitable user found (neither joe nor vscode)"
    exit 1
fi

# Use the detected user for all operations
USER_HOME="/home/$CONTAINER_USER"

# Install Node.js if not present (Claude Code requires Node.js)
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js (required for Claude Code)..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

# Install Claude Code CLI
if [ "$INSTALL_LATEST" = "true" ]; then
    echo "📦 Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
fi

# Create configuration directory structure
echo "📁 Setting up Claude Code configuration..."
mkdir -p "$USER_HOME/.config/claude-code"
mkdir -p "$USER_HOME/.claude-code-backups"

# Create wrapper commands that call scripts in .devcontainer/scripts/
echo "🔗 Setting up Claude Code commands..."

cat > /usr/local/bin/claude-code-setup << 'EOF'
#!/bin/bash
# Wrapper for Claude Code setup script
# Detect current user (could be joe or vscode)
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
else
    echo "❌ No suitable user found"
    exit 1
fi

SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-setup.sh"
if [ -f "$SCRIPT_PATH" ]; then
    CONTAINER_USER="$CONTAINER_USER" "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code setup script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/claude-code-test << 'EOF'
#!/bin/bash
# Wrapper for Claude Code test script
# Detect current user (could be joe or vscode)
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
else
    echo "❌ No suitable user found"
    exit 1
fi

SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-test.sh"
if [ -f "$SCRIPT_PATH" ]; then
    CONTAINER_USER="$CONTAINER_USER" "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code test script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/claude-code-status << 'EOF'
#!/bin/bash
# Wrapper for Claude Code status script
# Detect current user (could be joe or vscode)
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
else
    echo "❌ No suitable user found"
    exit 1
fi

SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-status.sh"
if [ -f "$SCRIPT_PATH" ]; then
    CONTAINER_USER="$CONTAINER_USER" "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code status script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/claude-code-backup << 'EOF'
#!/bin/bash
# Wrapper for Claude Code backup script
# Detect current user (could be joe or vscode)
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
else
    echo "❌ No suitable user found"
    exit 1
fi

SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-backup.sh"
if [ -f "$SCRIPT_PATH" ]; then
    CONTAINER_USER="$CONTAINER_USER" "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code backup script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/claude-code-switch-auth << 'EOF'
#!/bin/bash
# Wrapper for Claude Code auth switching script
# Detect current user (could be joe or vscode)
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
else
    echo "❌ No suitable user found"
    exit 1
fi

SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-switch-auth.sh"
if [ -f "$SCRIPT_PATH" ]; then
    CONTAINER_USER="$CONTAINER_USER" "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code auth switch script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

# Make wrappers executable
chmod +x /usr/local/bin/claude-code-setup
chmod +x /usr/local/bin/claude-code-test
chmod +x /usr/local/bin/claude-code-status
chmod +x /usr/local/bin/claude-code-backup
chmod +x /usr/local/bin/claude-code-switch-auth

# Create helpful aliases if requested
if [ "$CREATE_ALIASES" = "true" ]; then
    echo "🔧 Creating Claude Code aliases..."
    
    cat > "$USER_HOME/.claude-code-aliases" << 'EOF'
# Claude Code aliases for convenience
alias cc='claude'
alias cc-setup='claude-code-setup'
alias cc-test='claude-code-test'
alias cc-status='claude-code-status'
alias cc-backup='claude-code-backup'
alias cc-switch='claude-code-switch-auth'
alias cc-login='claude login'
alias cc-logout='claude logout'
alias cc-config='cat ~/.config/claude-code/config.json | jq . 2>/dev/null || echo "No local config found"'

# Specialized Claude Code commands
alias cc-python='claude "write python code for:"'
alias cc-js='claude "write javascript code for:"'
alias cc-fix='claude "fix this code:"'
alias cc-explain='claude "explain this code:"'
alias cc-review='claude "review this code for bugs and improvements:"'
EOF
    
    chown "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.claude-code-aliases"
    
    # Add to shell RC files
    echo "" >> "$USER_HOME/.bashrc"
    echo "# Claude Code aliases" >> "$USER_HOME/.bashrc"
    echo "source ~/.claude-code-aliases" >> "$USER_HOME/.bashrc"
    
    if [ -f "$USER_HOME/.zshrc" ]; then
        echo "" >> "$USER_HOME/.zshrc"
        echo "# Claude Code aliases" >> "$USER_HOME/.zshrc"
        echo "source ~/.claude-code-aliases" >> "$USER_HOME/.zshrc"
    fi
fi

# Setup auto-completion if requested
if [ "$SETUP_AUTOCOMPLETION" = "true" ]; then
    echo "⚡ Setting up shell auto-completion..."
    
    # For bash
    if command -v claude &> /dev/null; then
        mkdir -p /etc/bash_completion.d
        claude completion bash > /etc/bash_completion.d/claude-code 2>/dev/null || true
    fi
    
    # For zsh
    if [ -d /usr/share/zsh ]; then
        mkdir -p /usr/share/zsh/vendor-completions
        claude completion zsh > /usr/share/zsh/vendor-completions/_claude-code 2>/dev/null || true
    fi
fi

# Set ownership for all user files
chown -R "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.config/claude-code"
chown -R "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.claude-code-backups"

echo "✅ Claude Code AI Assistant installed successfully!"
echo ""
echo "📁 Script location: .devcontainer/scripts/"
echo "💡 The actual Claude Code management scripts should be maintained in your"
echo "   .devcontainer/scripts/ directory for easy version control and editing."
echo ""
echo "🚀 Next steps:"
echo "   1. Create the Claude Code scripts in .devcontainer/scripts/"
echo "   2. Run 'claude-code-setup' to configure authentication"
echo "   3. Test with 'claude-code-test'"
echo ""
echo "📋 Available commands:"
echo "   claude-code-setup      - Configure authentication (OAuth or API key)"
echo "   claude-code-test       - Test configuration"
echo "   claude-code-status     - Show status"
echo "   claude-code-backup     - Backup config to host"
echo "   claude-code-switch-auth - Switch between auth methods"

if [ "$CREATE_ALIASES" = "true" ]; then
    echo ""
    echo "🔧 Available aliases (after shell restart):"
    echo "   cc, cc-python, cc-js, cc-fix, cc-explain, cc-review"
fi

echo ""
echo "💡 Your credentials will persist across container rebuilds!"
echo "🔄 Currently using: $CONTAINER_USER user"