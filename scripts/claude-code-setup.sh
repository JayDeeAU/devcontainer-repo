#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-setup.sh
# Claude Code API key setup and management

CONFIG_DIR="/home/joe/.config/claude-code"
CONFIG_FILE="$CONFIG_DIR/config.json"
BACKUP_DIR="/home/joe/.claude-code-backups"
HOST_BACKUP_DIR="/home/joe/.claude-code-host-backup"

# Ensure directories exist
mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$HOST_BACKUP_DIR"

echo "🤖 Claude Code Setup"
echo "==================="

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "✅ Existing Claude Code configuration found"
    echo "📄 Config location: $CONFIG_FILE"
    
    # Show current API key (masked)
    if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
        MASKED_KEY=$(jq -r '.apiKey // "not-set"' "$CONFIG_FILE" 2>/dev/null | sed 's/\(.\{8\}\).*/\1.../')
        echo "🔑 Current API key: $MASKED_KEY"
    fi
    
    echo ""
    read -p "Would you like to update your API key? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Get API key from user
echo "🔑 Setting up Claude Code API key"
echo ""
echo "💡 To get your API key:"
echo "   1. Visit: https://console.anthropic.com/settings/keys"
echo "   2. Create a new API key"
echo "   3. Copy the key and paste it below"
echo ""

# Read API key securely
read -s -p "Enter your Claude API key: " API_KEY
echo

if [ -z "$API_KEY" ]; then
    echo "❌ No API key provided. Exiting."
    exit 1
fi

# Validate API key format (basic check)
if [[ ! $API_KEY =~ ^sk-ant-api ]]; then
    echo "⚠️  Warning: API key doesn't match expected format (should start with 'sk-ant-api')"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create backup if config exists
if [ -f "$CONFIG_FILE" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp "$CONFIG_FILE" "$BACKUP_DIR/config-backup-$TIMESTAMP.json"
    echo "💾 Backup created: config-backup-$TIMESTAMP.json"
fi

# Create configuration
cat > "$CONFIG_FILE" << EOF
{
  "apiKey": "$API_KEY",
  "model": "claude-3-5-sonnet-20241022",
  "maxTokens": 8192,
  "temperature": 0.1,
  "created": "$(date -Iseconds)",
  "version": "devcontainer-setup"
}
EOF

# Set proper permissions
chmod 600 "$CONFIG_FILE"
chown joe:joe "$CONFIG_FILE"
chown -R joe:joe "$CONFIG_DIR" "$BACKUP_DIR"

# Auto-backup to host
cp "$CONFIG_FILE" "$HOST_BACKUP_DIR/config.json"
echo "$(date -Iseconds)" > "$HOST_BACKUP_DIR/last-backup.txt"

echo "✅ Claude Code configured successfully!"
echo "📁 Configuration saved to: $CONFIG_FILE"
echo "💾 Backed up to host for persistence"
echo ""
echo "🧪 Test your setup:"
echo "   claude-code-test"
echo "   claude-code 'write a hello world in python'"