#!/usr/bin/env bash
# .devcontainer/scripts/claude-code-backup.sh
# Backup Claude Code configuration to host

CONFIG_FILE="/home/joe/.config/claude-code/config.json"
HOST_BACKUP_DIR="/home/joe/.claude-code-host-backup"
HOST_BACKUP_FILE="$HOST_BACKUP_DIR/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  No Claude Code configuration found to backup"
    exit 0
fi

echo "💾 Backing up Claude Code configuration to host..."

# Create host backup directory
mkdir -p "$HOST_BACKUP_DIR"

# Copy configuration
cp "$CONFIG_FILE" "$HOST_BACKUP_FILE"

# Create timestamp file
echo "$(date -Iseconds)" > "$HOST_BACKUP_DIR/last-backup.txt"

echo "✅ Claude Code configuration backed up to host"
echo "📁 Backup location: ~/.claude-code-devcontainer/"