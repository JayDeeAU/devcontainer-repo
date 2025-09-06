#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-test.sh
# Test Claude Code configuration

CONFIG_FILE="/home/joe/.config/claude-code/config.json"

echo "🧪 Testing Claude Code configuration..."

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No configuration found. Run 'claude-code-setup' first."
    exit 1
fi

# Check if claude-code command exists
if ! command -v claude-code &> /dev/null; then
    echo "❌ claude-code command not found. Installation may have failed."
    exit 1
fi

echo "✅ Claude Code CLI installed"
echo "✅ Configuration file exists"

# Validate configuration format
if command -v jq &> /dev/null; then
    if jq . "$CONFIG_FILE" >/dev/null 2>&1; then
        MASKED_KEY=$(jq -r '.apiKey // "not-set"' "$CONFIG_FILE" | sed 's/\(.\{8\}\).*/\1.../')
        MODEL=$(jq -r '.model // "not-set"' "$CONFIG_FILE")
        echo "✅ Configuration is valid"
        echo "🔑 API Key: $MASKED_KEY"
        echo "🧠 Model: $MODEL"
    else
        echo "❌ Configuration file is corrupted"
        exit 1
    fi
fi

# Test basic command (without making API call)
echo "🔧 Claude Code version:"
claude-code --version 2>/dev/null || echo "Could not get version"

echo ""
echo "💡 To test API connection:"
echo "   claude-code 'say hello'"
echo ""
echo "🔑 To reconfigure API key:"
echo "   claude-code-setup"