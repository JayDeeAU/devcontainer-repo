#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-init.sh
# Initialize Claude Code configuration after container creation

set -e

echo "🤖 Initializing Claude Code configuration..."

CONFIG_DIR="/home/joe/.config/claude-code"
CONFIG_FILE="$CONFIG_DIR/config.json"
HOST_BACKUP_DIR="/home/joe/.claude-code-host-backup"
HOST_BACKUP_FILE="$HOST_BACKUP_DIR/config.json"

# Ensure directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$HOST_BACKUP_DIR"

# Check for existing configuration in host backup
if [ -f "$HOST_BACKUP_FILE" ]; then
    echo "📥 Found existing Claude Code configuration on host"
    cp "$HOST_BACKUP_FILE" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    chown joe:joe "$CONFIG_FILE"
    
    # Validate the configuration
    if command -v jq &> /dev/null; then
        if jq . "$CONFIG_FILE" >/dev/null 2>&1; then
            MASKED_KEY=$(jq -r '.apiKey // "not-set"' "$CONFIG_FILE" | sed 's/\(.\{8\}\).*/\1.../')
            echo "✅ Claude Code configuration restored (API key: $MASKED_KEY)"
        else
            echo "⚠️  Configuration file is corrupted, removing..."
            rm -f "$CONFIG_FILE"
        fi
    else
        echo "✅ Claude Code configuration restored"
    fi
else
    echo "💡 No existing Claude Code configuration found"
    echo "   Run 'claude-code-setup' to configure your API key"
fi

# Set proper ownership
chown -R joe:joe "$CONFIG_DIR"
chown -R joe:joe "$HOST_BACKUP_DIR"

echo "🤖 Claude Code initialization complete"