# MagmaBI Debugging Guide

Complete guide to debugging MagmaBI applications in local, staging, and production environments.

## Table of Contents
- [Quick Start](#quick-start)
- [Environment Overview](#environment-overview)
- [Local Debugging](#local-debugging)
- [Debug Branch Workflow](#debug-branch-workflow)
- [VSCode Debugger Setup](#vscode-debugger-setup)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Start Local Debugging Session
```bash
# Regular local development (live source mounting)
env-local

# Local with debuggers in wait state (for breakpoints)
env-local-debug
```

### Debug Production/Staging Issues
```bash
# Create debug branch from main (production)
debug-start issue-name    # or: dbs issue-name

# Create debug branch from develop (staging)
debug-start --staging issue-name    # or: dbs --staging issue-name

# List active debug branches
debug-list    # or: dbl

# End debug session (returns to original branch, deletes debug branch)
debug-end     # or: dbf
```

## Environment Overview

### Local Environment (7700-7799 ports)
- **Purpose**: Development and debugging
- **Source Code**: Live-mounted from workspace (hot reload)
- **Build Metadata**: Generated via `.env.local.buildinfo`
- **Use Cases**:
  - Feature development
  - Testing production/staging issues
  - Breakpoint debugging

### Staging Environment (7600-7699 ports)
- **Purpose**: Pre-production testing
- **Source Code**: Built into Docker images
- **Build Metadata**: Baked into images during build
- **Use Cases**:
  - Testing current branch in prod-like environment
  - Integration testing
  - Performance testing

### Production Environment (7500-7599 ports)
- **Purpose**: Production deployment simulation
- **Source Code**: Built into Docker images from main branch
- **Build Metadata**: Baked into images during build
- **Branch Behavior**: Tracks current branch → switches to main → runs operations → restores original branch
- **Use Cases**:
  - Pre-deployment testing
  - Production hotfix testing

## Local Debugging

### Regular Local Development

**Start environment:**
```bash
env-local
```

**Features:**
- Live source code mounting
- Hot reload (Next.js + FastAPI)
- Automatic dependency detection
- Build metadata from `.env.local.buildinfo`

**Access points:**
- Frontend: https://magmabi-local.codemian.com
- Backend API: https://api-magmabi-local.codemian.com
- Flower (Celery): https://flower-local.codemian.com
- RedisInsight: https://redis-local.codemian.com

### Local Debug Mode (Debuggers Enabled)

**Start debug environment:**
```bash
env-local-debug
```

**Features:**
- All containers start with debuggers in wait state
- Debuggers listen for VSCode attachment
- Breakpoint support
- Step-through debugging

**Debug Ports:**
- Backend FastAPI: 7711 (debugpy)
- Celery Worker: 7712 (debugpy)
- Celery Beat: 7713 (debugpy)
- Next.js Frontend: 9229 (Node.js main), 9230 (Next.js)

**VSCode Launch Configurations:**
- `Local: Backend FastAPI`
- `Local: Celery Worker`
- `Local: Celery Beat`
- `Local: Next.js Frontend`
- `Local: Full Stack` (compound)
- `Local: Backend Only` (compound)

## Debug Branch Workflow

### When to Use Debug Branches

Debug branches are temporary branches for testing production or staging issues in your local environment with full source mounting.

**Use debug branches when:**
- Investigating production bugs
- Testing staging issues locally
- Need to reproduce specific version behavior
- Want to test hotfix before creating official hotfix branch

**Don't use debug branches for:**
- Regular feature development (use feature branches)
- Long-term work (use appropriate git-flow branches)

### Creating Debug Branches

**From main (production issues):**
```bash
debug-start <issue-name>
# or
dbs <issue-name>
```

Example:
```bash
dbs payment-timeout
# Creates: debug/prod-payment-timeout-20251021-143022
```

**From develop (staging issues):**
```bash
debug-start --staging <issue-name>
# or
dbs --staging <issue-name>
```

Example:
```bash
dbs --staging auth-error
# Creates: debug/staging-auth-error-20251021-143045
```

**What happens:**
1. Fetches latest from source branch (main or develop)
2. Creates timestamped debug branch
3. Checks out new branch
4. Automatically starts `env-local` environment
5. Ready for debugging with full source mounting

### Working in Debug Branches

Once your debug branch is created:

1. **Environment is running**: Local environment auto-started
2. **Make changes**: Edit code with live reload
3. **Test fixes**: Verify changes work
4. **Commit work**: Optional - commit to debug branch if needed

```bash
# Make changes to code
# Test changes

# Optional: commit changes
git add .
git commit -m "debug: fix payment timeout issue"

# Can checkout to other branches if needed
git checkout feature/my-feature

# Return to debug branch later
git checkout debug/prod-payment-timeout-20251021-143022
```

### Listing Debug Branches

```bash
debug-list
# or
dbl
```

**Output example:**
```
🐛 Active Debug Branches
========================

  * debug/prod-payment-timeout-20251021-143022 (from main)  ← current
    debug/staging-auth-error-20251021-143045 (from develop)

💡 Tips:
   - Switch to a branch: git checkout <branch-name>
   - End debug session: debug-end (or dbf)
   - Delete manually: git branch -D <branch-name>
```

### Ending Debug Sessions

**Clean end (recommended):**
```bash
debug-end
# or
dbf
```

**What happens:**
1. Checks for uncommitted changes (prompts if found)
2. Returns to source branch (main for prod, develop for staging)
3. Deletes debug branch

**Manual cleanup:**
If `debug-end` fails or you want manual control:
```bash
# Switch back to base branch
git checkout main    # or develop

# Delete debug branch
git branch -D debug/prod-issue-name-timestamp
```

### Debug Branch Naming Convention

Debug branches follow this pattern:
```
debug/<source>-<issue-name>-<timestamp>

Examples:
debug/prod-payment-timeout-20251021-143022
debug/staging-auth-error-20251021-143045
debug/release-2.7.0-hotfix-20251021-143100
```

**Components:**
- `debug/`: Namespace for all debug branches
- `prod|staging|release-X.X.X`: Source branch indicator
- `<issue-name>`: Descriptive issue name
- `<timestamp>`: YYYYmmdd-HHMMSS for uniqueness

## VSCode Debugger Setup

### Prerequisites

**Extensions required:**
- Python Debugger (debugpy)
- JavaScript Debugger (built-in)

**Container must be running:**
```bash
# Regular local (debuggers not waiting)
env-local

# Debug mode (debuggers waiting for attachment)
env-local-debug
```

### Backend Debugging (Python/FastAPI)

**1. Start local-debug environment:**
```bash
env-local-debug
```

**2. Set breakpoints in Python code:**
- Open backend files in VSCode
- Click left gutter to set breakpoints

**3. Attach debugger:**
- Press F5 or Run → Start Debugging
- Select: `Local: Backend FastAPI`

**4. Trigger code path:**
- Make API requests to trigger breakpoints
- Debugger will pause at breakpoints

**Debugging Celery tasks:**
- Use `Local: Celery Worker` configuration
- Set breakpoints in task files
- Trigger task execution

### Frontend Debugging (Next.js)

**1. Start local-debug environment:**
```bash
env-local-debug
```

**2. Set breakpoints in TypeScript/React code:**
- Open frontend files
- Set breakpoints

**3. Attach debugger:**
- Select: `Local: Next.js Frontend`
- Opens browser debugging tools

**4. Debug in browser:**
- Use Chrome DevTools
- Inspect React components
- Debug client-side logic

### Multi-Service Debugging

**Full stack debugging:**
```bash
# Select compound configuration
"Local: Full Stack"
```

Attaches debuggers to:
- Backend FastAPI
- Celery Worker
- Next.js Frontend

**Backend only:**
```bash
"Local: Backend Only"
```

Attaches debuggers to:
- Backend FastAPI
- Celery Worker
- Celery Beat

## Troubleshooting

### Debugger Won't Attach

**Issue**: "Cannot connect to debugger"

**Solutions:**
```bash
# 1. Verify containers are running
docker ps | grep magmabi

# 2. Check if ports are open
lsof -i :7711  # Backend
lsof -i :9229  # Frontend

# 3. Restart debug environment
env-stop
env-local-debug

# 4. Check container logs
env-logs backend
```

### Dependencies Changed Warning

**Issue**: "Dependencies have changed since last build!"

**Solution:**
```bash
# Rebuild local environment
env-local-build
# or
env-local --build
```

### Port Already in Use

**Issue**: "Port 7700 already in use"

**Solution:**
```bash
# Stop all environments first
env-stop

# Check what's using the port
lsof -i :7700

# Kill the process if needed
kill -9 <PID>

# Restart environment
env-local
```

### Debug Branch Won't Delete

**Issue**: Cannot delete debug branch

**Solution:**
```bash
# Force delete
git branch -D debug/prod-issue-name-timestamp

# If branch is current branch, checkout another first
git checkout main
git branch -D debug/prod-issue-name-timestamp
```

### Build Metadata Not Showing

**Issue**: Version shows as "unknown" or "dev"

**For local environment:**
```bash
# Regenerate buildinfo
rm .env.local.buildinfo
env-local
```

**For staging/prod:**
```bash
# Rebuild images
env-staging-build
# or
env-prod-build
```

### Uncommitted Changes Blocking Debug-End

**Issue**: "You have uncommitted changes!"

**Solutions:**
```bash
# Option 1: Commit changes
git add .
git commit -m "debug: description"

# Option 2: Stash changes
git stash

# Option 3: Discard changes
git reset --hard HEAD

# Then retry
debug-end
```

## Best Practices

### 1. Always Use Debug Branches for Production Issues

```bash
# ✅ Good
dbs payment-timeout      # Creates clean debug branch
# Make changes
# Test
dbf                      # Clean cleanup

# ❌ Bad
git checkout main        # Direct changes to main
# Make changes
```

### 2. Name Debug Branches Descriptively

```bash
# ✅ Good
dbs payment-timeout
dbs auth-token-refresh
dbs celery-task-stuck

# ❌ Bad
dbs test
dbs bug
dbs fix
```

### 3. Clean Up Debug Branches Regularly

```bash
# List active debug branches
dbl

# End sessions you're done with
dbf

# Or manually delete old ones
git branch -D debug/prod-old-issue-20251001-120000
```

### 4. Use env-local-debug Only When Needed

```bash
# Regular development
env-local           # Faster startup, no debugger overhead

# When you need breakpoints
env-local-debug     # Debuggers in wait state
```

### 5. Check Build Metadata After Dependency Changes

```bash
# After npm install or poetry add
env-local-build     # Rebuild with new dependencies

# Verify metadata
curl https://api-magmabi-local.codemian.com/health
```

## Additional Resources

- [Universal Container Manager](./scripts/universal-container-manager.sh)
- [Version Manager](./scripts/version-manager.sh)
- [VSCode Launch Configuration](../.vscode/launch.json)
- [Docker Compose Local](../docker/docker-compose.local.yml)
- [Docker Compose Local Debug](../docker/docker-compose.local-debug.yml)
