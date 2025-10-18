# Universal Container Manager - October 18, 2025 Updates

## Summary of Changes

This document summarizes the critical fixes and enhancements made to the Universal Container Manager on October 18, 2025.

---

## Issues Fixed

### 1. Docker Compose Multiple File Handling

**Problem:** When multiple docker-compose files were specified (e.g., `docker-compose.yml docker-compose.staging.yml`), they were passed incorrectly to docker compose, causing the command to fail.

**Root Cause:** The `compose_files` variable was passed as space-separated values without proper `-f` flags for each file.

**Solution:** Added compose flags conversion loop that formats multiple files correctly:
```bash
# Before: docker compose -f file1 file2 ...
# After:  docker compose -f file1 -f file2 ...
```

**Files Modified:** `universal-container-manager.sh` lines 680-690

---

### 2. Worktree Creation Failures

**Problem:** When trying to create a debug worktree for a branch that was already checked out in the main workspace, git would fail with:
```
fatal: 'develop' is already checked out at '/path/to/project'
```

**Root Cause:** Git doesn't allow the same branch to be checked out in multiple worktrees simultaneously.

**Solution:** Enhanced `create_worktree` function to detect this scenario and use `--detach` fallback:
```bash
# If normal checkout fails, create detached HEAD worktree
git worktree add --detach "$worktree_path" "origin/$branch"
```

**Files Modified:** `universal-container-manager.sh` lines 488-512

---

### 3. Worktree Sync on Detached HEAD

**Problem:** When a worktree was in detached HEAD state, attempting to sync (pull) would fail because there's no tracking branch.

**Root Cause:** `git pull` doesn't work in detached HEAD state without specifying a remote and branch.

**Solution:** Enhanced `sync_worktree` function to:
1. Detect detached HEAD state
2. Automatically checkout the target branch
3. Then pull normally

```bash
# Detects: HEAD detached at abc1234
# Auto-recovers: git checkout develop && git pull
```

**Files Modified:** `universal-container-manager.sh` lines 516-547

---

### 4. Unwanted Automatic Worktree Syncing

**Problem:** User wanted to preserve temporary debug code (print statements, logging) between debug sessions, but worktrees were automatically syncing and losing these changes.

**Root Cause:** Original design assumed worktrees should always be up-to-date with origin.

**Solution:** Added `--sync` flag for explicit control:

**New Behavior:**
- **First time:** Creating worktree always syncs from origin
- **Subsequent times:** Worktree preserved as-is (unless --sync flag used)
- **With --sync:** Explicitly pull latest changes from origin

**Usage Examples:**
```bash
# Uses existing worktree, preserves debug code
env-staging --debug

# Updates worktree to latest origin/develop
env-staging --debug --sync
```

**Files Modified:**
- `universal-container-manager.sh` lines 554-596 (`ensure_worktree_ready` function)
- `universal-container-manager.sh` lines 655-693 (flag parsing)
- `universal-container-manager.sh` line 785 (call site)

---

## Documentation Updates

### 1. Universal Container Manager Header

**Added comprehensive usage documentation:**
```bash
# FLAGS:
#   --build   Force rebuild (required for staging/local with code changes)
#   --debug   Enable debug mode with source mounting (prod/staging only)
#   --sync    Update debug worktree from origin (use with --debug)
#   --push    Auto-push to GHCR after successful build
#
# DEBUG WORKTREES:
#   prod-debug/staging-debug: Isolated worktrees for read-only debugging
#   - Created on first --debug use, preserved between sessions
#   - Use --sync flag to update from origin when needed
#   - Scratch pad area - debug prints won't affect main workspace
#   local-debug: Uses same source as local (current directory)
```

**Files Modified:** `universal-container-manager.sh` lines 1-31

### 2. DevContainer README

**Added new section:** "Debug Worktree Management" with comprehensive documentation including:
- How worktrees work (which environments use them)
- Worktree lifecycle (create, preserve, sync)
- Key behaviors (scratch pads, branch conflicts, source mounting)
- Manual worktree setup
- Troubleshooting guide
- Best practices

**Files Modified:** `.devcontainer/README.md` (inserted after pull_policy section)

---

## Testing Checklist

After these changes, verify:

- [ ] **Multiple compose files:** `env-staging` with multiple compose files works
- [ ] **Branch conflict:** Create debug worktree while main workspace on same branch
- [ ] **Detached HEAD recovery:** Worktree in detached state syncs correctly with --sync
- [ ] **Scratch pad behavior:** Debug code preserved between sessions without --sync
- [ ] **Explicit sync:** --sync flag pulls latest changes from origin

---

## Migration Guide

**For existing projects:**

1. **No action required** - all changes are backward compatible
2. **Optional:** Review worktree usage patterns and use `--sync` when appropriate
3. **Recommended:** Read new documentation in README about worktree lifecycle

---

## Technical Notes

### Worktree Philosophy

Worktrees in the Universal Container Manager serve as **scratch pads** for debugging:

✅ **Use worktrees for:**
- Investigating production/staging issues
- Adding temporary debug prints
- Testing quick fixes before proper implementation
- Multi-session debugging (code preserved)

❌ **Don't use worktrees for:**
- Committing important work
- Long-term development
- Syncing changes back to origin

### Source Mounting Matrix

```
Environment         Source Mount?    Location                 Branch        Port
-----------         -------------    --------                 ------        ----
prod                No               (uses built image)       N/A           7500
prod --debug        Yes              ../project-production    main          7511
staging             No               (uses built image)       N/A           7600
staging --debug     Yes              ../project-staging       develop       7611
local               Yes              Current directory        (current)     7700
local (debugger)    Yes              Current directory        (current)     7711
```

### Branch Conflict Resolution

When creating a worktree for a branch already checked out:

1. **Attempt:** Normal checkout with tracking branch
   ```bash
   git worktree add -b develop ../project-staging origin/develop
   ```

2. **Fallback:** Detached HEAD if branch in use
   ```bash
   git worktree add --detach ../project-staging origin/develop
   ```

3. **Recovery:** Next sync will checkout branch properly
   ```bash
   env-staging --debug --sync
   # Detects detached HEAD
   # Checks out develop
   # Pulls latest
   ```

---

## Related Documentation

- **Implementation Analysis:** See `DEPENDENCY_SYNC_ANALYSIS.md` for broader context
- **Debug Architecture:** See `DEBUG_ENVIRONMENTS_ANALYSIS.md` for design rationale
- **Pull Policy Fix:** See `.devcontainer/README.md` Docker Compose section (Oct 15, 2025)
- **Build Strategy Change:** All environments now require explicit `--build` flag (Oct 15, 2025)

---

## Contributors

- **User:** Identified issues and requirements
- **GitHub Copilot:** Implementation and documentation

**Date:** October 18, 2025
