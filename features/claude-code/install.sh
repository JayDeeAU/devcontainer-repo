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

# Ensure joe user exists
if ! id -u joe >/dev/null 2>&1; then
    echo "⚠️  Creating joe user..."
    groupadd -g 1000 joe
    useradd -u 1000 -g 1000 -m -s /bin/bash joe
fi

# Install Node.js if not present (Claude Code requires Node.js)
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js (required for Claude Code)..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

# Install Claude Code CLI
if [ "$INSTALL_LATEST" = "true" ]; then
    echo "📦 Installing Claude Code CLI..."
    npm install -g claude-code
fi

# Create configuration directory structure
echo "📁 Setting up Claude Code configuration..."
mkdir -p /home/joe/.config/claude-code
mkdir -p /home/joe/.claude-code-backups

# Create wrapper commands that call scripts in .devcontainer/scripts/
echo "🔗 Setting up Claude Code commands..."

cat > /usr/local/bin/claude-code-setup << 'EOF'
#!/bin/bash
# Wrapper for Claude Code setup script
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-setup.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code setup script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/claude-code-test << 'EOF'
#!/bin/bash
# Wrapper for Claude Code test script
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-test.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code test script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/claude-code-status << 'EOF'
#!/bin/bash
# Wrapper for Claude Code status script
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-status.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code status script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/claude-code-backup << 'EOF'
#!/bin/bash
# Wrapper for Claude Code backup script
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/claude-code-backup.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Claude Code backup script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the Claude Code scripts"
    exit 1
fi
EOF

# Make wrappers executable
chmod +x /usr/local/bin/claude-code-setup
chmod +x /usr/local/bin/claude-code-test
chmod +x /usr/local/bin/claude-code-status
chmod +x /usr/local/bin/claude-code-backup

# Create helpful aliases if requested
if [ "$CREATE_ALIASES" = "true" ]; then
    echo "🔧 Creating Claude Code aliases..."
    
    cat > /home/joe/.claude-code-aliases << 'EOF'
# Claude Code aliases for convenience
alias cc='claude-code'
alias cc-setup='claude-code-setup'
alias cc-test='claude-code-test'
alias cc-status='claude-code-status'
alias cc-backup='claude-code-backup'
alias cc-config='cat ~/.config/claude-code/config.json | jq .'

# Specialized Claude Code commands
alias cc-python='claude-code "write python code for:"'
alias cc-js='claude-code "write javascript code for:"'
alias cc-fix='claude-code "fix this code:"'
alias cc-explain='claude-code "explain this code:"'
alias cc-review='claude-code "review this code for bugs and improvements:"'
EOF
    
    chown joe:joe /home/joe/.claude-code-aliases
    
    # Add to shell RC files
    echo "" >> /home/joe/.bashrc
    echo "# Claude Code aliases" >> /home/joe/.bashrc
    echo "source ~/.claude-code-aliases" >> /home/joe/.bashrc
    
    if [ -f /home/joe/.zshrc ]; then
        echo "" >> /home/joe/.zshrc
        echo "# Claude Code aliases" >> /home/joe/.zshrc
        echo "source ~/.claude-code-aliases" >> /home/joe/.zshrc
    fi
fi

# Setup auto-completion if requested
if [ "$SETUP_AUTOCOMPLETION" = "true" ]; then
    echo "⚡ Setting up shell auto-completion..."
    
    # For bash
    if command -v claude-code &> /dev/null; then
        mkdir -p /etc/bash_completion.d
        claude-code completion bash > /etc/bash_completion.d/claude-code 2>/dev/null || true
    fi
    
    # For zsh
    if [ -d /usr/share/zsh ]; then
        mkdir -p /usr/share/zsh/vendor-completions
        claude-code completion zsh > /usr/share/zsh/vendor-completions/_claude-code 2>/dev/null || true
    fi
fi

# Set ownership for all joe user files
chown -R joe:joe /home/joe/.config/claude-code
chown -R joe:joe /home/joe/.claude-code-backups

echo "✅ Claude Code AI Assistant installed successfully!"
echo ""
echo "📁 Script location: .devcontainer/scripts/"
echo "💡 The actual Claude Code management scripts should be maintained in your"
echo "   .devcontainer/scripts/ directory for easy version control and editing."
echo ""
echo "🚀 Next steps:"
echo "   1. Create the Claude Code scripts in .devcontainer/scripts/"
echo "   2. Run 'claude-code-setup' to configure your API key"
echo "   3. Test with 'claude-code-test'"
echo ""
echo "📋 Available commands:"
echo "   claude-code-setup      - Configure API key"
echo "   claude-code-test       - Test configuration"
echo "   claude-code-status     - Show status"
echo "   claude-code-backup     - Backup config to host"

if [ "$CREATE_ALIASES" = "true" ]; then
    echo ""
    echo "🔧 Available aliases (after shell restart):"
    echo "   cc, cc-python, cc-js, cc-fix, cc-explain, cc-review"
fi

echo ""
echo "💡 Your API key will persist across container rebuilds!"