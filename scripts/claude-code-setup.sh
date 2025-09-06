#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-setup.sh
# Claude Code authentication setup - supports both OAuth and API key

echo "🤖 Claude Code Authentication Setup"
echo "===================================="

echo ""
echo "📋 Authentication Options:"
echo "  1. OAuth (Pro/Max subscription) - Recommended"
echo "  2. API Key (Pay-per-use)"
echo ""

read -p "Choose authentication method (1 or 2): " AUTH_CHOICE

case $AUTH_CHOICE in
    1)
        echo ""
        echo "🔐 Setting up OAuth authentication (Pro/Max subscription)..."
        echo ""
        echo "💡 This will:"
        echo "   - Open your browser for authentication"
        echo "   - Use your existing Pro/Max subscription"
        echo "   - Share usage limits with claude.ai"
        echo ""
        read -p "Continue with OAuth setup? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🚀 Starting OAuth authentication..."
            claude login
            
            if [ $? -eq 0 ]; then
                echo "✅ OAuth authentication successful!"
                echo "🧪 Test with: claude-code-test"
            else
                echo "❌ OAuth authentication failed"
                echo "💡 Try running 'claude login' manually"
            fi
        else
            echo "❌ OAuth setup cancelled"
        fi
        ;;
        
    2)
        echo ""
        echo "🔑 Setting up API key authentication..."
        
        CONFIG_DIR="/home/joe/.config/claude-code"
        CONFIG_FILE="$CONFIG_DIR/config.json"
        BACKUP_DIR="/home/joe/.claude-code-backups"
        HOST_BACKUP_DIR="/home/joe/.claude-code-host-backup"

        # Ensure directories exist
        mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$HOST_BACKUP_DIR"

        # Check if config already exists
        if [ -f "$CONFIG_FILE" ]; then
            echo "✅ Existing API key configuration found"
            
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
  "version": "devcontainer-setup",
  "authType": "api-key"
}
EOF

        # Set proper permissions
        chmod 600 "$CONFIG_FILE"
        chown joe:joe "$CONFIG_FILE"
        chown -R joe:joe "$CONFIG_DIR" "$BACKUP_DIR"

        # Auto-backup to host
        cp "$CONFIG_FILE" "$HOST_BACKUP_DIR/config.json"
        echo "$(date -Iseconds)" > "$HOST_BACKUP_DIR/last-backup.txt"

        echo "✅ API key configuration successful!"
        echo "📁 Configuration saved to: $CONFIG_FILE"
        echo "💾 Backed up to host for persistence"
        echo "🧪 Test with: claude-code-test"
        ;;
        
    *)
        echo "❌ Invalid choice. Please run claude-code-setup again."
        exit 1
        ;;
esac