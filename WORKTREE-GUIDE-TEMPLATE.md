# Git Worktree Guide for Debug Environments

**Template for projects using worktree-based debugging strategy**

> 💡 **Note:** This is a generic template. Customize for your project's specific needs.

---

## What Are Worktrees?

Git worktrees allow you to check out multiple branches simultaneously in separate directories. For debugging, we use **detached worktrees** as isolated scratch pads.

### Key Concept: Scratch Pads

Worktrees in this setup are **temporary investigation spaces**, not development environments:

- ✅ Safe to add debug prints, logs, breakpoints
- ✅ Persist across sessions until manually deleted
- ✅ Can be refreshed to latest code from origin
- ❌ **Never meant to be committed**
- ❌ Changes won't merge back to main codebase

---

## Directory Structure

```
/workspaces/
├── your-project/              # Main workspace
│   ├── .git/                  # Git repository
│   ├── backend/
│   ├── frontend/
│   └── .devcontainer/
│
├── your-project-production/   # Production debug worktree
│   ├── .git                   # → Points to main repo
│   ├── backend/               # Detached at origin/main
│   ├── frontend/
│   └── README-DEBUG.md        # Reminder this is scratch
│
└── your-project-staging/      # Staging debug worktree
    ├── .git                   # → Points to main repo
    ├── backend/               # Detached at origin/develop
    └── frontend/
```

---

## Setup Process

### One-Time Initial Setup

```bash
# Create worktrees for production and staging debugging
universal-container-manager setup-worktrees
```

This command:
1. Creates detached worktrees in sibling directories
2. Checks out the appropriate branch (main for prod, develop for staging)
3. Adds worktrees to `.gitignore` in main workspace
4. Creates README files as reminders
5. Optionally adds to VSCode workspace

### Manual Setup (Alternative)

If you need to create worktrees manually:

```bash
cd /workspaces/your-project

# Production worktree (tracking main)
git worktree add --detach ../your-project-production main

# Staging worktree (tracking develop)
git worktree add --detach ../your-project-staging develop

# Add to gitignore
echo "your-project-production/" >> .gitignore
echo "your-project-staging/" >> .gitignore
```

---

## Usage Workflows

### Scenario 1: Investigating Production Issue

```bash
# 1. Start production debug environment
env-prod --debug

# This:
# - Creates worktree if doesn't exist
# - Starts containers with source mounting from worktree
# - Exposes debug ports

# 2. Navigate to worktree
cd ../your-project-production

# 3. Add debug statements
# Edit files as needed:
# - Add console.log(), print(), etc.
# - Add extra logging
# - Comment out problematic code
# - Insert temporary fixes

# 4. Attach VSCode debugger
# In main workspace:
# - Press F5
# - Select "Production: Full Stack Debug"
# - Set breakpoints in worktree code

# 5. Investigate the issue
# - Step through code
# - Inspect variables
# - Test theories

# 6. When done debugging:
# Option A: Keep worktree for later (it persists)
# Option B: Refresh to clean state
env-prod --debug --sync

# Option C: Delete and recreate fresh
cd /workspaces/your-project
rm -rf ../your-project-production
```

### Scenario 2: Testing Staging Changes

```bash
# 1. Start staging debug environment
env-staging --debug

# 2. If worktree is old, refresh it
env-staging --debug --sync

# 3. Navigate and add debugging
cd ../your-project-staging

# 4. Debug as needed
# Follow same process as production scenario
```

### Scenario 3: Switching Between Environments

```bash
# Main workspace: develop feature
cd /workspaces/your-project
git checkout feature/new-feature
env-local

# Production issue reported: investigate
env-prod --debug
# Worktree at ../your-project-production used automatically

# Back to feature development
env-local
# Back to main workspace
```

---

## Worktree Lifecycle

### Creation
- **Automatic:** First time running `env-prod --debug` or `env-staging --debug`
- **Manual:** Run `universal-container-manager setup-worktrees`
- **Triggered:** When debug mode needs source mounting

### Maintenance
```bash
# Check staleness (if worktree > 7 days old, warning shown)
env-prod --debug  # Shows warning if stale

# Refresh worktree (pulls latest from origin)
env-prod-sync              # Shortcut alias
env-staging-sync           # Shortcut alias
# OR
env-prod --debug --sync    # Alternative form
env-staging --debug --sync # Alternative form

# This does:
# 1. git fetch origin [branch]
# 2. git reset --hard origin/[branch]
# 3. Discards all local changes in worktree
```

### Deletion
```bash
# Manual deletion
cd /workspaces/your-project
rm -rf ../your-project-production
rm -rf ../your-project-staging

# Git cleanup (optional, good practice)
git worktree prune

# Worktrees will be recreated next time you use debug mode
```

---

## VSCode Integration

### Adding Worktrees to Workspace

Update your `.code-workspace` file:

```jsonc
{
  "folders": [
    {
      "path": ".",
      "name": "Main Workspace"
    },
    {
      "path": "../your-project-production",
      "name": "🐛 DEBUG: Production"
    },
    {
      "path": "../your-project-staging",
      "name": "🐛 DEBUG: Staging"
    }
  ]
}
```

Benefits:
- Browse worktree code in sidebar
- Edit debug statements easily
- See file differences
- Terminal in worktree context

### Path Mappings in launch.json

Ensure debug configurations point to worktrees:

```jsonc
{
  "configurations": [
    {
      "name": "Production: Backend",
      "type": "debugpy",
      "pathMappings": [{
        // Use worktree path for production
        "localRoot": "${workspaceFolder}/../your-project-production/backend",
        "remoteRoot": "/app"
      }]
    },
    {
      "name": "Local: Backend",
      "type": "debugpy",
      "pathMappings": [{
        // Use main workspace for local
        "localRoot": "${workspaceFolder}/backend",
        "remoteRoot": "/app"
      }]
    }
  ]
}
```

---

## Best Practices

### DO ✅

1. **Use for Investigation**
   - Debugging production issues
   - Adding temporary logging
   - Testing theories with prints
   - Isolating problematic code

2. **Refresh Regularly**
   - Before starting new investigation
   - After major releases
   - When code is > 7 days old

3. **Delete When Done**
   - After issue is resolved
   - When no longer needed
   - To save disk space

4. **Document Findings**
   - Keep notes outside worktree
   - Document root cause in main repo
   - Update tests based on findings

### DON'T ❌

1. **Never Commit from Worktree**
   - Worktrees are scratch pads
   - Commits could create confusion
   - Use main workspace for real changes

2. **Don't Develop Features**
   - Worktrees are for debugging only
   - Use main workspace + feature branches
   - Keep worktrees disposable

3. **Don't Rely on Persistence**
   - Worktrees can be deleted anytime
   - Don't store important code there
   - Save findings elsewhere

4. **Don't Push from Worktree**
   - Even if you commit (accidentally)
   - Use main workspace for pushes
   - Worktree commits are throwaway

---

## Troubleshooting

### "Worktree doesn't exist"

```bash
# Create it
universal-container-manager setup-worktrees

# Or manually
git worktree add --detach ../your-project-production main
```

### "Worktree is locked"

```bash
# Check worktree status
git worktree list

# If corrupted, remove lock
rm -f .git/worktrees/your-project-production/locked

# Or prune and recreate
git worktree prune
rm -rf ../your-project-production
universal-container-manager setup-worktrees
```

### "Path mappings don't work"

```bash
# Verify worktree exists and has correct structure
ls -la ../your-project-production

# Check launch.json paths match actual structure
# Should be: ${workspaceFolder}/../your-project-production/backend
# Not: ${workspaceFolder}/your-project-production/backend
```

### "Changes disappeared"

This is expected behavior! Worktrees are scratch pads.

Solutions:
- If you need changes: Copy them to main workspace before syncing
- If you accidentally synced: Check if you have local git commits
- If deleted: Worktree changes are not recoverable (by design)

### "Conflicting files"

```bash
# Worktree has merge conflicts after sync
cd ../your-project-production

# Just reset hard (safe since it's scratch)
git reset --hard origin/main
git clean -fdx
```

---

## Advanced Usage

### Comparing Main vs Worktree

```bash
# See what's different
git diff ../your-project-production

# Or use VSCode
# Open both folders in workspace
# Compare files side-by-side
```

### Preserving Debug Code

If you want to keep useful debug code:

```bash
# 1. Copy from worktree to main workspace
cd /workspaces/your-project
cp ../your-project-production/backend/debug_utils.py ./backend/

# 2. Commit in main workspace
git add backend/debug_utils.py
git commit -m "feat: add debug utilities from investigation"

# 3. Worktree remains unchanged (scratch pad)
```

### Multiple Worktrees

For complex debugging:

```bash
# Create additional worktrees
git worktree add --detach ../your-project-hotfix hotfix/critical-bug

# Use custom environment
cd docker
docker-compose -f docker-compose.custom.yml up

# Clean up when done
cd /workspaces/your-project
git worktree remove ../your-project-hotfix
```

### Worktree with Different Configurations

```bash
# Create worktree with specific commit
git worktree add --detach ../your-project-v1.0.0 v1.0.0

# Useful for:
# - Debugging old releases
# - Comparing versions
# - Reproducing historical bugs
```

---

## Git Worktree Commands Reference

```bash
# List all worktrees
git worktree list

# Add new worktree
git worktree add <path> <branch>
git worktree add --detach <path> <commit>

# Remove worktree
git worktree remove <path>

# Prune deleted worktrees
git worktree prune

# Move worktree to different location
git worktree move <old-path> <new-path>

# Lock worktree (prevent deletion)
git worktree lock <path>

# Unlock worktree
git worktree unlock <path>
```

---

## Performance Considerations

### Disk Space

Each worktree contains:
- Full working directory (source files)
- Shared .git repository (no duplication)

**Typical sizes:**
- Small project: ~50-200 MB per worktree
- Medium project: ~200-500 MB per worktree
- Large project: ~500 MB - 2 GB per worktree

### Cleanup Strategy

```bash
# Regular cleanup (weekly/monthly)
cd /workspaces/your-project

# Remove unused worktrees
rm -rf ../your-project-production
rm -rf ../your-project-staging

# Prune git references
git worktree prune

# Worktrees will auto-recreate when needed
```

---

## FAQ

**Q: Why use worktrees instead of just switching branches?**

A: Worktrees let you keep your main workspace on your feature branch while investigating production code. No context switching needed.

**Q: Can I have multiple developers using the same worktree?**

A: No, each developer should have their own worktrees. They're personal scratch pads.

**Q: What happens if I commit in a worktree?**

A: The commit exists in git but isn't on any branch (detached HEAD). Just don't push it. Refresh worktree to discard.

**Q: Can I merge changes from worktree to main?**

A: Not recommended. Worktrees are scratch pads. Manually port useful code to main workspace if needed.

**Q: How often should I sync worktrees?**

A: Before investigating new issues or when warned it's >7 days old. Fresher is better.

**Q: Can I use worktrees for development?**

A: Technically yes, but not recommended. Use main workspace + feature branches for development. Worktrees are for debugging only.

---

## Summary

**Worktrees are:**
- 🎯 Investigation tools, not development environments
- 🔒 Isolated from your main workspace
- 🔄 Refreshable to latest code
- 🗑️ Disposable and recreatable
- 🚫 Never to be committed/pushed

**Use them to:**
- Debug production issues safely
- Add temporary logging
- Test theories without affecting main code
- Investigate staging problems

**Remember:**
- Refresh before use: `--sync`
- Delete when done: `rm -rf`
- Never commit from worktree
- Save findings elsewhere

---

**Last Updated:** [Your Date]  
**Template Version:** 1.0.0  
**Learn More:** `git worktree --help`
