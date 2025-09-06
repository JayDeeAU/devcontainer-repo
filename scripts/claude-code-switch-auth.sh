#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-switch-auth.sh
# Switch between OAuth and API key authentication

echo "🔄 Claude Code Authentication Switcher"
echo "======================================"

echo ""
echo "📋 Current Status:"
claude-code-status | grep -E "(Authentication|CLI)"

echo ""
echo "🔐 Switch To:"
echo "  1. OAuth (Pro/Max subscription)"
echo "  2. API Key (Pay-per-use)"
echo "  3. Logout from current session"
echo ""

read -p "Choose option (1, 2, or 3): " SWITCH_CHOICE

case $SWITCH_CHOICE in
    1)
        echo ""
        echo "🔄 Switching to OAuth authentication..."
        
        # Logout first to clear any existing auth
        echo "📤 Logging out from current session..."
        claude logout 2>/dev/null || echo "No active session to logout"
        
        # Start OAuth login
        echo "🔐 Starting OAuth authentication..."
        claude login
        
        if [ $? -eq 0 ]; then
            echo "✅ Successfully switched to OAuth authentication!"
            echo "🧪 Test with: claude-code-test"
        else
            echo "❌ OAuth authentication failed"
        fi
        ;;
        
    2)
        echo ""
        echo "🔄 Switching to API key authentication..."
        
        # Logout from OAuth first
        echo "📤 Logging out from current session..."
        claude logout 2>/dev/null || echo "No active session to logout"
        
        # Run API key setup
        echo "🔑 Starting API key setup..."
        claude-code-setup
        ;;
        
    3)
        echo ""
        echo "📤 Logging out from current session..."
        claude logout
        
        # Also remove local config if present
        read -p "Also remove local API key configuration? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "/home/joe/.config/claude-code/config.json"
            echo "🗑️  Local configuration removed"
        fi
        
        echo "✅ Logged out successfully"
        echo "💡 Run 'claude-code-setup' to authenticate again"
        ;;
        
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac