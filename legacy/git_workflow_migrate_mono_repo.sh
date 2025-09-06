#!/bin/bash

# ------------------------------------------------------------------------------
# git_migrate_monorepo.sh
#
# 📦 PURPOSE:
#   Safely transition a monorepo that uses duplicate folders (e.g. magmabi-prod)
#   into a clean Git branch-based workflow.
#
# 📌 WHEN TO USE:
#   Run this script only once when you're ready to remove -prod folders and
#   create `main` and `develop` branches to manage your environments.
#
# 🛡️ WHAT IT DOES:
#   1. Confirms you're inside a Git repo.
#   2. Commits any uncommitted changes as a pre-migration snapshot.
#   3. Creates a backup branch `prod-legacy`.
#   4. Creates `main` and `develop` branches from current state.
#   5. Removes the `*-prod` folders from Git and the filesystem.
#
# 💡 SAFETY NOTES:
#   - This script **does not touch remote branches**.
#   - A full backup branch is created in case you need to roll back.
#   - You must verify that removing the prod folders is appropriate.
# ------------------------------------------------------------------------------

set -e  # Exit on any error

# Step 1: Check for .git directory
if [ ! -d .git ]; then
  echo "❌ This is not a Git repository. Run this from your project root."
  exit 1
fi

# Step 2: Commit any uncommitted changes
echo "📦 Creating pre-migration snapshot of your current work..."
git add .
git commit -m "Pre-migration snapshot" || echo "⚠️ Nothing to commit (already clean)"

# Step 3: Create a backup branch
echo "🔐 Creating backup branch: prod-legacy"
git checkout -b prod-legacy

# Step 4: Create main and develop branches
echo "🌱 Creating new branches: main and develop"
git checkout -b main
git checkout -b develop

# Step 5: Remove legacy -prod folders
echo "🧹 Removing duplicated *-prod folders from Git and disk..."

# Backup to external folder (optional)
mkdir -p ../legacy-backup
cp -r magmabi-prod backend-prod ../legacy-backup/ 2>/dev/null || echo "⚠️ Skipped backup copy (folders may not exist)"

# Remove from Git tracking
git rm -r magmabi-prod backend-prod 2>/dev/null || echo "⚠️ Skipped Git removal (already gone)"

# Remove from local filesystem
rm -rf magmabi-prod backend-prod

# Final cleanup commit
git commit -m "Remove legacy -prod folders and migrate to branch workflow"

echo "✅ Migration complete!"
echo "You now have:"
echo "  ➤ 'main'   — your stable production branch"
echo "  ➤ 'develop' — your working development branch"
echo "  ➤ 'prod-legacy' — backup of the pre-migration state"
