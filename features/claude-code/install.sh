#!/usr/bin/env bash
# features/claude-code/install.sh
# Install Claude Code CLI with direct credential persistence

set -e

echo "🤖 Installing Claude Code AI Assistant..."

# Get configuration from feature options
INSTALL_LATEST=${INSTALLLATEST:-true}
CREATE_ALIASES=${CREATEALIASES:-true}

# Handle user situation - could be vscode or joe depending on feature order
CONTAINER_USER=""
TARGET_USER="${USERNAME:-developer}"
if id -u "$TARGET_USER" >/dev/null 2>&1; then
    CONTAINER_USER="$TARGET_USER"
    echo "✅ Found $TARGET_USER user (UID: $(id -u "$TARGET_USER"), GID: $(id -g "$TARGET_USER"))"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
    echo "✅ Found vscode user (UID: $(id -u vscode), GID: $(id -g vscode))"
    echo "💡 Note: Using vscode user - $TARGET_USER user will be created later by common-utils"
else
    echo "❌ No suitable user found (neither $TARGET_USER nor vscode)"
    exit 1
fi

USER_HOME="/home/$CONTAINER_USER"

# Install Node.js/npm if not present (Claude Code requires Node.js)
# The devcontainer Node feature may install to /usr/local/share/nvm/ which
# isn't always on PATH during feature installation. Check common locations.
for dir in /usr/local/share/nvm/current/bin /usr/local/bin /usr/bin; do
    if [ -x "$dir/node" ] && [ -x "$dir/npm" ]; then
        export PATH="$dir:$PATH"
        break
    fi
done

if ! command -v npm &> /dev/null; then
    echo "📦 Installing Node.js (required for Claude Code)..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

echo "📦 Using Node $(node --version), npm $(npm --version)"

# Install Claude Code CLI
if [ "$INSTALL_LATEST" = "true" ]; then
    echo "📦 Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
fi

# Ensure Claude config directory exists and has correct ownership
echo "📁 Setting up Claude Code configuration directory..."
mkdir -p "$USER_HOME/.claude"
chown -R "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.claude"

# Create simple setup helper
cat > /usr/local/bin/claude-setup << 'EOF'
#!/bin/bash
# Simple Claude Code setup helper

echo "🤖 Claude Code Setup"
echo "===================="
echo ""
echo "✨ Claude Code is ready to use!"
echo ""
echo "🚀 To get started:"
echo "   1. Run 'claude' to start Claude Code"
echo "   2. Choose your authentication method when prompted"
echo "   3. Your credentials automatically persist across container rebuilds"
echo ""

# Check if already authenticated
if claude doctor &>/dev/null; then
    echo "✅ Claude Code is already authenticated and ready to use!"
else
    echo "💡 Run 'claude' to authenticate for the first time"
fi
EOF

chmod +x /usr/local/bin/claude-setup

# Create aliases if requested
if [ "$CREATE_ALIASES" = "true" ]; then
    echo "🔧 Creating Claude Code aliases..."
    
    cat > "$USER_HOME/.claude-code-aliases" << 'EOF'
# Claude Code aliases for convenience
alias cc='claude'
alias cc-setup='claude-setup'

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

echo "✅ Claude Code AI Assistant installed successfully!"
echo ""
echo "🚀 To get started:"
echo "   • Run 'claude-setup' for setup help (optional)"
echo "   • Run 'claude' to authenticate and start coding"
echo ""
echo "📋 Available aliases:"
echo "   cc, cc-python, cc-js, cc-fix, cc-explain, cc-review"
echo ""
echo "💡 Your credentials automatically persist via direct mount!"
echo "🔄 Currently using: $CONTAINER_USER user"