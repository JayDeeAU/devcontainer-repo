#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-status.sh
# Show Claude Code configuration status

echo "🤖 Claude Code Status Report"
echo "============================="

CONFIG_FILE="/home/joe/.config/claude-code/config.json"
HOST_BACKUP_DIR="/home/joe/.claude-code-host-backup"

# Check CLI installation
if command -v claude-code &> /dev/null; then
    echo "✅ Claude Code CLI: Installed"
    claude-code --version 2>/dev/null || echo "   (Version info not available)"
else
    echo "❌ Claude Code CLI: Not installed"
fi

# Check configuration
if [ -f "$CONFIG_FILE" ]; then
    echo "✅ Configuration: Found"
    
    if command -v jq &> /dev/null; then
        # Show masked API key
        MASKED_KEY=$(jq -r '.apiKey // "not-set"' "$CONFIG_FILE" 2>/dev/null | sed 's/\(.\{8\}\).*/\1.../')
        MODEL=$(jq -r '.model // "not-set"' "$CONFIG_FILE" 2>/dev/null)
        CREATED=$(jq -r '.created // "unknown"' "$CONFIG_FILE" 2>/dev/null)
        
        echo "   🔑 API Key: $MASKED_KEY"
        echo "   🧠 Model: $MODEL"
        echo "   📅 Created: $CREATED"
    fi
    
    echo "   📁 Location: $CONFIG_FILE"
else
    echo "❌ Configuration: Not found"
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
echo "   claude-code-setup      - Configure/update API key"
echo "   claude-code-test       - Test configuration"
echo "   claude-code-backup     - Backup config to host"
echo "   claude-code-status     - Show this status"

# Show aliases if available
if [ -f "/home/joe/.claude-code-aliases" ]; then
    echo ""
    echo "🔧 Available aliases:"
    echo "   cc, cc-python, cc-js, cc-fix, cc-explain, cc-review"
fi