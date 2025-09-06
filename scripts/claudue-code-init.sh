#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-init.sh
# Initialize Claude Code configuration after container creation - supports both OAuth and API key

set -e

echo "🤖 Initializing Claude Code configuration..."

CONFIG_DIR="/home/joe/.config/claude-code"
CONFIG_FILE="$CONFIG_DIR/config.json"
HOST_BACKUP_DIR="/home/joe/.claude-code-host-backup"
HOST_BACKUP_FILE="$HOST_BACKUP_DIR/config.json"

# Ensure directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$HOST_BACKUP_DIR"

# Check if Claude Code is already authenticated via OAuth
if command -v claude &> /dev/null; then
    AUTH_STATUS=$(claude doctor 2>/dev/null | grep -i "authenticated" || echo "not authenticated")
    
    if echo "$AUTH_STATUS" | grep -q -i "authenticated"; then
        echo "✅ Claude Code already authenticated via OAuth"
        echo "   Status: $AUTH_STATUS"
        echo "🤖 Claude Code initialization complete"
        exit 0
    fi
fi

# Check for existing API key configuration in host backup
if [ -f "$HOST_BACKUP_FILE" ]; then
    echo "📥 Found existing API key configuration on host"
    cp "$HOST_BACKUP_FILE" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    chown joe:joe "$CONFIG_FILE"
    
    # Validate the configuration
    if command -v jq &> /dev/null; then
        if jq . "$CONFIG_FILE" >/dev/null 2>&1; then
            MASKED_KEY=$(jq -r '.apiKey // "not-set"' "$CONFIG_FILE" | sed 's/\(.\{8\}\).*/\1.../')
            echo "✅ API key configuration restored (API key: $MASKED_KEY)"
        else
            echo "⚠️  Configuration file is corrupted, removing..."
            rm -f "$CONFIG_FILE"
        fi
    else
        echo "✅ API key configuration restored"
    fi
else
    echo "💡 No existing configuration found"
    echo ""
    echo "🔐 Authentication Options:"
    echo "   1. OAuth (Pro/Max): Run 'claude login'"
    echo "   2. API Key: Run 'claude-code-setup'"
    echo ""
    echo "💡 OAuth is recommended if you have a Pro or Max subscription"
fi

# Set proper ownership
chown -R joe:joe "$CONFIG_DIR"
chown -R joe:joe "$HOST_BACKUP_DIR"

echo "🤖 Claude Code initialization complete"