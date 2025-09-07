#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-init.sh
# Initialize Claude Code with direct credential mounting

set -e

echo "🤖 Initializing Claude Code..."

# Detect current user
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
else
    echo "❌ No suitable user found"
    exit 1
fi

USER_HOME="/home/$CONTAINER_USER"

# Ensure correct ownership of mounted Claude directory
if [ -d "$USER_HOME/.claude" ]; then
    chown -R "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.claude"
    echo "✅ Claude Code directory ownership fixed"
fi

echo "✅ Claude Code initialization complete"
echo "💡 Run 'claude' to start Claude Code (credentials persist automatically)"