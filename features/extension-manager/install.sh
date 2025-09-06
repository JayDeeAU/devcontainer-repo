#!/usr/bin/env bash
# features/extension-manager/install.sh
# Lightweight VS Code extension change tracker and devcontainer.json sync

set -e

echo "📦 Installing VS Code Extension Manager..."

# Get configuration from feature options
AUTO_SYNC=${AUTOSYNC:-true}
WATCH_INTERVAL=${WATCHINTERVAL:-30}
BACKUP_EXTENSIONS=${BACKUPEXTENSIONS:-true}

# Install required tools
apt-get update && apt-get install -y jq inotify-tools

# Create extension manager directory for user data
mkdir -p /home/joe/.extension-manager

# Create symbolic links to scripts in devcontainer scripts directory
# The actual scripts will be maintained in .devcontainer/scripts/
echo "🔗 Setting up extension manager commands..."

# Create wrapper scripts that call the maintained scripts
cat > /usr/local/bin/sync-extensions << 'EOF'
#!/bin/bash
# Wrapper for extension sync script
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/sync-extensions.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Extension sync script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the extension manager scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/list-extensions << 'EOF'
#!/bin/bash
# Wrapper for extension list script
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/list-extensions.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Extension list script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the extension manager scripts"
    exit 1
fi
EOF

cat > /usr/local/bin/restore-extensions << 'EOF'
#!/bin/bash
# Wrapper for extension restore script
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/restore-extensions.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Extension restore script not found at: $SCRIPT_PATH"
    echo "💡 Make sure your .devcontainer/scripts/ directory contains the extension manager scripts"
    exit 1
fi
EOF

# Make wrappers executable
chmod +x /usr/local/bin/sync-extensions
chmod +x /usr/local/bin/list-extensions
chmod +x /usr/local/bin/restore-extensions

# Create auto-sync daemon wrapper (if enabled)
if [ "$AUTO_SYNC" = "true" ]; then
    echo "🤖 Setting up auto-sync daemon..."
    
    cat > /usr/local/lib/extension-manager/auto-sync-daemon.sh << 'EOF'
#!/bin/bash
# Auto-sync daemon wrapper

WATCH_INTERVAL=${EXTENSION_MANAGER_WATCH_INTERVAL:-30}
SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/sync-extensions.sh"

echo "🤖 Extension auto-sync daemon started (interval: ${WATCH_INTERVAL}s)"

while true; do
    if [ -f "$SCRIPT_PATH" ]; then
        # Run sync quietly
        "$SCRIPT_PATH" >/dev/null 2>&1
    fi
    sleep "$WATCH_INTERVAL"
done
EOF
    
    mkdir -p /usr/local/lib/extension-manager
    chmod +x /usr/local/lib/extension-manager/auto-sync-daemon.sh
fi

# Set ownership for joe user
chown -R joe:joe /home/joe/.extension-manager

echo "✅ Extension Manager installed successfully!"
echo ""
echo "📋 Available commands:"
echo "  sync-extensions     - Manually sync extensions to devcontainer.json"
echo "  list-extensions     - Show extension status report"
echo "  restore-extensions  - Restore from backup"
echo ""
echo "📁 Script location: .devcontainer/scripts/"
echo "💡 The actual extension manager scripts should be maintained in your"
echo "   .devcontainer/scripts/ directory for easy version control and editing."
echo ""

if [ "$AUTO_SYNC" = "true" ]; then
    echo "🤖 Auto-sync enabled (every ${WATCH_INTERVAL} seconds)"
else
    echo "💡 Auto-sync disabled - use 'sync-extensions' manually"
fi