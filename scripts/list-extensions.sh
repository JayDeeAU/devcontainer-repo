#!/usr/bin/env bash
# .devcontainer/scripts/list-extensions.sh
# List current extensions and their status

echo "📦 Extension Status Report"
echo "=========================="

DEVCONTAINER_JSON="$(pwd)/.devcontainer/devcontainer.json"

echo "🔧 Currently Installed:"
code --list-extensions 2>/dev/null | sort | sed 's/^/  ✓ /'

echo ""
echo "📄 In devcontainer.json:"
if [ -f "$DEVCONTAINER_JSON" ]; then
    jq -r '.customizations.vscode.extensions[]? // empty' "$DEVCONTAINER_JSON" 2>/dev/null | sort | sed 's/^/  📝 /'
else
    echo "  ⚠️  devcontainer.json not found"
fi

echo ""
echo "📊 Statistics:"
installed_count=$(code --list-extensions 2>/dev/null | wc -l)
config_count=$(jq -r '.customizations.vscode.extensions[]? // empty' "$DEVCONTAINER_JSON" 2>/dev/null | wc -l)
echo "  Installed: $installed_count extensions"
echo "  In config: $config_count extensions"

echo ""
echo "💡 Commands:"
echo "  sync-extensions     - Sync installed extensions to devcontainer.json"
echo "  list-extensions     - Show this status report"
echo "  restore-extensions  - Restore from backup"