#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-status.sh
# Show Claude Code configuration status - supports both OAuth and API key

echo "🤖 Claude Code Status Report"
echo "============================="

CONFIG_FILE="/home/joe/.config/claude-code/config.json"
HOST_BACKUP_DIR="/home/joe/.claude-code-host-backup"

# Check CLI installation
if command -v claude &> /dev/null; then
    echo "✅ Claude Code CLI: Installed"
    claude --version 2>/dev/null || echo "   (Version info not available)"
else
    echo "❌ Claude Code CLI: Not installed"
fi

# Check authentication status
echo ""
echo "🔐 Authentication Status:"

# Try to get current authentication info from Claude CLI
AUTH_INFO=$(claude doctor 2>/dev/null | grep -E "(Authenticated|Login|API Key)" || echo "Unable to determine")

if echo "$AUTH_INFO" | grep -q "Authenticated"; then
    echo "✅ Authentication: Active"
    echo "   $AUTH_INFO"
    
    # Try to determine auth type
    if echo "$AUTH_INFO" | grep -q -i "oauth\|console\|pro\|max"; then
        echo "   🔐 Type: OAuth (Pro/Max subscription)"
    elif echo "$AUTH_INFO" | grep -q -i "api"; then
        echo "   🔐 Type: API Key"
    else
        echo "   🔐 Type: Unknown"
    fi
else
    echo "❌ Authentication: Not authenticated"
    echo "   Run 'claude-code-setup' to authenticate"
fi

# Check for API key configuration (legacy/fallback)
if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "📄 Local Configuration: Found"
    
    if command -v jq &> /dev/null; then
        # Show masked API key if present
        MASKED_KEY=$(jq -r '.apiKey // "not-set"' "$CONFIG_FILE" 2>/dev/null | sed 's/\(.\{8\}\).*/\1.../')
        MODEL=$(jq -r '.model // "not-set"' "$CONFIG_FILE" 2>/dev/null)
        AUTH_TYPE=$(jq -r '.authType // "legacy"' "$CONFIG_FILE" 2>/dev/null)
        CREATED=$(jq -r '.created // "unknown"' "$CONFIG_FILE" 2>/dev/null)
        
        if [ "$MASKED_KEY" != "not-set" ]; then
            echo "   🔑 API Key: $MASKED_KEY"
        fi
        echo "   🧠 Model: $MODEL"
        echo "   📅 Created: $CREATED"
        echo "   🔐 Auth Type: $AUTH_TYPE"
    fi
    
    echo "   📁 Location: $CONFIG_FILE"
else
    echo ""
    echo "📄 Local Configuration: Not found"
fi

# Check host backup
if [ -f "$HOST_BACKUP_DIR/config.json" ]; then
    echo "✅ Host Backup: Available"
    if [ -f "$HOST_BACKUP_DIR/last-backup.txt" ]; then
        LAST_BACKUP=$(cat "$HOST_BACKUP_DIR/last-backup.txt")
        echo "   📅 Last backup: $LAST_BACKUP"
    fi
else
    echo "⚠️  Host Backup: Not found"
fi

echo ""
echo "📋 Available commands:"
echo "   claude-code-setup      - Configure authentication (OAuth or API key)"
echo "   claude-code-test       - Test configuration"
echo "   claude-code-backup     - Backup config to host"
echo "   claude-code-status     - Show this status"
echo "   claude login           - Direct OAuth authentication"
echo "   claude logout          - Logout from current session"

# Show aliases if available
if [ -f "/home/joe/.claude-code-aliases" ]; then
    echo ""
    echo "🔧 Available aliases:"
    echo "   cc, cc-python, cc-js, cc-fix, cc-explain, cc-review"
fi

echo ""
echo "💡 Authentication Options:"
echo "   OAuth: Use your Pro/Max subscription (recommended)"
echo "   API Key: Pay-per-use with Anthropic Console credits"