#!/usr/bin/env bash
# .devcontainer/scripts/restore-extensions.sh
# Restore extensions from backup

BACKUP_DIR="$HOME/.extension-manager/backups"
DEVCONTAINER_JSON="$(pwd)/.devcontainer/devcontainer.json"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ No backups found"
    exit 1
fi

echo "📋 Available backups:"
find "$BACKUP_DIR" -name "devcontainer-*.json" -printf "%f %TY-%Tm-%Td %TH:%TM\n" | sort -r | head -10

echo ""
read -p "Enter backup filename (or press Enter to cancel): " backup_file

if [ -n "$backup_file" ] && [ -f "$BACKUP_DIR/$backup_file" ]; then
    # Show what will be restored
    echo "📄 Extensions in backup:"
    jq -r '.customizations.vscode.extensions[]? // empty' "$BACKUP_DIR/$backup_file" 2>/dev/null | sort | sed 's/^/  - /'
    
    echo ""
    read -p "Restore this backup? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$BACKUP_DIR/$backup_file" "$DEVCONTAINER_JSON"
        echo "✅ Restored from backup: $backup_file"
        echo "💡 You may need to rebuild the DevContainer to install/remove extensions"
    else
        echo "❌ Restore cancelled"
    fi
else
    echo "❌ Backup not found or cancelled"
fi