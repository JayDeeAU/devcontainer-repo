#!/bin/bash

# ------------------------------------------------------------------------------
# git_migrate_monorepo_dryrun.sh
#
# 🔍 PURPOSE:
#   Show what would happen during migration from a duplicated-folder repo to a
#   Git branch-based environment, without making any changes.
#
# 🧪 USE THIS FIRST:
#   This script does not perform Git actions or remove files. It’s ideal for
#   verifying folder paths, Git status, and branch naming before running the
#   real `git_migrate_monorepo.sh`.
# ------------------------------------------------------------------------------

echo "🔍 DRY RUN: Git Monorepo Migration Preview"
echo "-----------------------------------------"

# Step 1: Check if in a Git repository
if [ ! -d .git ]; then
  echo "❌ This is not a Git repository. Please run from your project root."
  exit 1
fi

echo "✅ Git repository found."

# Step 2: Check for uncommitted changes
echo "🔍 Checking for uncommitted changes..."
if git diff-index --quiet HEAD --; then
  echo "✅ Working directory is clean."
else
  echo "⚠️ You have uncommitted changes. These would be staged and committed as:"
  echo "    git add ."
  echo "    git commit -m \"Pre-migration snapshot\""
fi

# Step 3: Show branches to be created
echo "📦 The following new branches would be created:"
echo "  ➤ prod-legacy (backup of current state)"
echo "  ➤ main         (for production)"
echo "  ➤ develop      (for active dev)"

# Step 4: Check for folders to be removed
echo "🔍 Checking for -prod folders..."
for folder in magmabi-prod backend-prod; do
  if [ -d "$folder" ]; then
    echo "🗑️ Folder found and scheduled for removal: $folder"
  else
    echo "✅ Folder not found: $folder (nothing to remove)"
  fi
done

# Step 5: Show final actions
echo "🧹 These commands would be executed in the real script:"
echo "  ➤ mkdir ../legacy-backup"
echo "  ➤ cp -r magmabi-prod backend-prod ../legacy-backup/"
echo "  ➤ git rm -r magmabi-prod backend-prod"
echo "  ➤ rm -rf magmabi-prod backend-prod"
echo "  ➤ git commit -m \"Remove legacy -prod folders and migrate to branch workflow\""

echo
echo "✅ DRY RUN COMPLETE."
echo "You can now safely run: ./git_migrate_monorepo.sh"
