# 🚀 Quick Start Guide

**For developers who just want to start coding.**

> **Universal Guide**: This works for any project using the devcontainer-repo and dotfiles environment. Commands and workflows are identical across all projects.

> **🎯 Need a specific workflow?** Jump to [WORKFLOWS-QUICK-REFERENCE.md](WORKFLOWS-QUICK-REFERENCE.md) for instant lookup table or [WORKFLOWS-DETAILED-GUIDE.md](WORKFLOWS-DETAILED-GUIDE.md) for complete step-by-step scenarios.

> You don't need to understand the complexity - just use these commands!

---

## Daily Development (All You Need to Know)

### 🌟 Start a New Feature

```bash
gffs my-feature-name
```

**That's it!** This single command:
- ✅ Creates `feature/my-feature-name` branch
- ✅ Assigns next version (1.3.0, 1.4.0, etc.)
- ✅ Updates all version files
- ✅ Starts local development environment (port 7700s)
- ✅ You're ready to code in ~5 seconds

### 💻 Work Normally

```bash
# Make changes to your code, then commit:
feat "add user authentication"
feat "add login form"
fix "resolve validation bug"

# Push to remote:
gp
```

### ✅ Finish Your Feature

```bash
gfff
```

**Done!** This command:
- ✅ Merges feature into `develop` branch
- ✅ Switches to staging environment for testing
- ✅ Deletes the feature branch
- ✅ Ready for team review

---

## Emergency Hotfix (Production Bug)

### 🚨 Start Hotfix

```bash
ghfs critical-bug-fix
```

Creates hotfix branch from `main`, assigns patch version (1.2.4, 1.2.5, etc.)

### 🔧 Fix the Bug

```bash
fix "resolve payment processing timeout"
fix "add error handling"
gp
```

### 🚀 Deploy Hotfix

```bash
ghff
```

Merges to `main` AND `develop`, tags release, switches to production environment

---

## Switching Environments

```bash
env-local          # Development (port 7700s)
env-staging        # Pre-production testing (port 7600s)
env-prod           # Production (port 7500s)
```

Each environment is completely isolated with different ports!

---

## Debugging Production Issues

```bash
env-prod-debug
```

- Investigates production code safely
- Enables VSCode debugger (port 7511)
- ⚠️ Read-only - make actual fixes in a hotfix branch

---

## Conventional Commits (Made Easy)

Instead of typing `git commit -m "feat: add login"`, just type:

```bash
feat "add login"       # New feature
fix "bug fix"          # Bug fix
docs "documentation"   # Documentation
style "formatting"     # Code style
refactor "refactor"    # Code refactoring
test "add tests"       # Testing
chore "maintenance"    # Maintenance
```

---

## Version Management

### Check Current Version

```bash
gvs
```

### Manual Version Bump (rarely needed)

```bash
gvb patch    # 1.2.3 → 1.2.4
gvb minor    # 1.2.3 → 1.3.0
gvb major    # 1.2.3 → 2.0.0
```

Usually `gffs` and `ghfs` handle versioning automatically!

---

## Environment Status & Logs

```bash
env-status         # Show which environments are running
env-health         # Health check all services
env-logs           # View all container logs
env-logs backend   # View specific service
env-stop           # Stop all environments
```

---

## Parallel Development (Teams)

Multiple developers work simultaneously without conflicts:

```bash
# Developer A
gffs user-authentication    # Gets version 1.3.0

# Developer B (at the same time)
gffs admin-dashboard        # Gets version 1.4.0

# Developer C (at the same time)
gffs reporting-module       # Gets version 1.5.0
```

**Zero version conflicts!** The system handles everything.

---

## When Things Go Wrong

### Uncommitted Changes

```bash
git stash              # Save work temporarily
gffs new-feature       # Switch branches
git stash pop          # Restore work
```

### Wrong Environment Running

```bash
env-status             # Check what's running
env-stop               # Stop everything
env-local              # Start fresh
```

### Container Issues

```bash
env-stop               # Stop all
docker system prune -f # Clean Docker
env-local              # Restart
```

---

## Learning Path

**Day 1** - Learn these:
```bash
gffs <name>           # Start feature
feat "message"        # Commit
gp                    # Push
gfff                  # Finish feature
```

**Week 1** - Add these:
```bash
env-local             # Local environment
env-staging           # Staging environment
ghfs/ghff             # Hotfix workflow
env-status            # Check status
```

**Month 1** - Master these:
```bash
env-prod-debug        # Production debugging
gvb/gvs               # Manual version control
env-logs              # Log investigation
```

---

## Access Your App

Once environment is running:

```bash
# Local Development
http://localhost:7700    # Frontend
http://localhost:7710    # Backend API
http://localhost:7711    # Backend debugger (if enabled)

# Staging
http://localhost:7600    # Frontend
http://localhost:7610    # Backend API

# Production
http://localhost:7500    # Frontend
http://localhost:7510    # Backend API
```

---

## Get More Help

```bash
# In your shell:
dot_help_workflow        # Complete workflow guide
dot_help_architecture    # System architecture
dot_help_containers      # Container management
dot_help_all             # All help topics

# Documentation:
.devcontainer/PROJECT-SETUP.md               # One-time project setup
.devcontainer/ARCHITECTURE.md                # System design
.devcontainer/WORKFLOWS-DETAILED-GUIDE.md  # Detailed workflow scenarios
```

---

## The Secret

> You're using a sophisticated three-layer system (dotfiles + container manager + version manager), but you only need to know ~5 commands.

**The complexity is hidden so you can stay in flow state.**

Just use the commands and enjoy coding! 🎉
