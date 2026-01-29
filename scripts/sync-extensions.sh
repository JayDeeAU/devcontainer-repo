#!/usr/bin/env bash
# .devcontainer/scripts/sync-extensions.sh
# Extension sync script - captures VS Code extension changes
# Works correctly from both main repo and worktrees

set -e

# Get repository root (works in both main repo and worktrees)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")

DEVCONTAINER_JSON="$REPO_ROOT/.devcontainer/devcontainer.json"
BACKUP_DIR="$HOME/.extension-manager/backups"
LAST_EXTENSIONS_FILE="$HOME/.extension-manager/last-extensions.json"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to get currently installed extensions
get_current_extensions() {
    code --list-extensions 2>/dev/null | sort | jq -R . | jq -s .
}

# Function to get extensions from devcontainer.json
get_devcontainer_extensions() {
    if [ -f "$DEVCONTAINER_JSON" ]; then
        jq -r '.customizations.vscode.extensions[]? // empty' "$DEVCONTAINER_JSON" 2>/dev/null | sort | jq -R . | jq -s .
    else
        echo "[]"
    fi
}

# Function to update devcontainer.json with new extensions
update_devcontainer_json() {
    local new_extensions="$1"
    
    if [ ! -f "$DEVCONTAINER_JSON" ]; then
        echo "⚠️  devcontainer.json not found at: $DEVCONTAINER_JSON"
        return 1
    fi
    
    # Create backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$DEVCONTAINER_JSON" "$BACKUP_DIR/devcontainer-$timestamp.json"
    echo "💾 Backup created: devcontainer-$timestamp.json"
    
    # Clean the extensions array of any comment lines or invalid entries
    local cleaned_extensions=$(echo "$new_extensions" | jq 'map(select(. != null and . != "" and (startswith("Extensions installed") | not)))')
    
    # Update the extensions array in devcontainer.json
    local temp_file=$(mktemp)
    jq --argjson extensions "$cleaned_extensions" \
       '.customizations.vscode.extensions = $extensions' \
       "$DEVCONTAINER_JSON" > "$temp_file"
    
    mv "$temp_file" "$DEVCONTAINER_JSON"
    echo "✅ Updated devcontainer.json with $(echo "$cleaned_extensions" | jq length) extensions"
}

# Main sync function
sync_extensions() {
    echo "🔄 Checking for extension changes..."
    
    local current_extensions=$(get_current_extensions)
    local devcontainer_extensions=$(get_devcontainer_extensions)
    
    # Compare current vs last known state
    if [ -f "$LAST_EXTENSIONS_FILE" ]; then
        local last_extensions=$(cat "$LAST_EXTENSIONS_FILE")
        
        if [ "$current_extensions" != "$last_extensions" ]; then
            echo "📦 Extension changes detected!"
            
            # Show what changed
            echo "📋 Current extensions:"
            echo "$current_extensions" | jq -r '.[]' | sed 's/^/  - /'
            
            # Update devcontainer.json
            update_devcontainer_json "$current_extensions"
            
            # Save current state
            echo "$current_extensions" > "$LAST_EXTENSIONS_FILE"
            
            echo "🎉 Extension sync complete!"
        else
            echo "✅ No extension changes detected"
        fi
    else
        # First run - just save current state
        echo "🚀 First run - saving current extension state"
        echo "$current_extensions" > "$LAST_EXTENSIONS_FILE"
        
        # Also sync to devcontainer.json if different
        if [ "$current_extensions" != "$devcontainer_extensions" ]; then
            echo "📦 Syncing current extensions to devcontainer.json"
            update_devcontainer_json "$current_extensions"
        fi
    fi
}

# Run sync
sync_extensions