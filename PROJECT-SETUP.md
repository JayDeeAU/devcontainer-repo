# 🎯 Project-Specific Setup Guide

## Overview

This devcontainer environment is **universal** and works across multiple projects. However, each project needs a small amount of project-specific configuration.

> **One-Time Setup**: You only need to do this once per project.

---

## Quick Setup (5 Minutes)

### Step 1: Generate Configuration

In your project root (where you cloned the devcontainer-repo):

```bash
# For simple projects
.devcontainer/scripts/config-generator.sh default

# For full-stack projects (frontend + backend)
.devcontainer/scripts/config-generator.sh fullstack

# For microservices
.devcontainer/scripts/config-generator.sh microservices
```

This creates `.container-config.json` with sensible defaults.

### Step 2: Review Configuration

Open `.container-config.json` and verify:

```json
{
  "project": {
    "name": "your-project-name",        // ← Auto-detected from directory
    "container_prefix": "yourproject_",  // ← Used for Docker containers
    "worktree_support": true,            // ← Enable debug worktrees
    "worktree_dirs": {
      "prod": "../your-project-production",
      "staging": "../your-project-staging"
    }
  },
  "environments": {
    "prod": { "branch": "main", ... },
    "staging": { "branch": "develop", ... },
    "local": { "branch": ["feature/*", "hotfix/*"], ... }
  }
}
```

### Step 3: Customize (Optional)

Edit `.container-config.json` if needed:

**Common customizations**:
- Change main branch name (`"main"` → `"master"`)
- Adjust development branch (`"develop"` → `"development"`)
- Disable worktrees if not needed (`"worktree_support": false`)
- Add custom branch patterns for local environment

### Step 4: Test

```bash
# Check configuration is valid
universal-container-manager status

# Start local environment
env-local

# Verify containers are running
docker ps
```

---

## Configuration Options Explained

### Project Settings

```json
"project": {
  "name": "myproject",
  "container_prefix": "myproject_",
  "worktree_support": true,
  "worktree_dirs": {
    "prod": "../myproject-production",
    "staging": "../myproject-staging"
  }
}
```

**`name`**:
- Auto-detected from directory name or git repository
- Used in container names, logs, and status displays
- Convention: lowercase, hyphens for spaces

**`container_prefix`**:
- Prefix for all Docker container names
- Prevents conflicts between multiple projects
- Convention: `{name}_` (with underscore)

**`worktree_support`**:
- `true`: Enables debug worktrees for production/staging debugging
- `false`: Debug modes mount current directory (simpler, no isolation)
- Recommendation: `true` for team projects, `false` for solo projects

**`worktree_dirs`**:
- Where to create debug worktrees (relative to project root)
- Only used if `worktree_support: true`
- Convention: `../projectname-{environment}`

### Environment Settings

```json
"environments": {
  "prod": {
    "branch": "main",
    "compose_files": ["docker/docker-compose.prod.yml"],
    "debug_compose_files": [
      "docker/docker-compose.prod.yml",
      "docker/docker-compose.prod-debug.yml"
    ]
  }
}
```

**`branch`**:
- String: Single branch for this environment (`"main"`)
- Array: Multiple patterns for this environment (`["feature/*", "hotfix/*"]`)
- Used for auto-detection when you run commands

**`compose_files`**:
- Docker Compose files for normal mode
- Can be array of multiple files (merged in order)
- Relative to project root

**`debug_compose_files`**:
- Docker Compose files for debug mode
- Typically includes base + debug overlay
- Enables debugger, source mounting, etc.

---

## Templates Explained

### Default Template

```bash
.devcontainer/scripts/config-generator.sh default
```

**Best for**:
- Simple applications
- Single service projects
- Getting started quickly

**Includes**:
- Basic three-environment setup (prod/staging/local)
- Standard port ranges (7500s, 7600s, 7700s)
- Main/develop branch mapping
- Worktree support disabled (simpler)

### Fullstack Template

```bash
.devcontainer/scripts/config-generator.sh fullstack
```

**Best for**:
- Frontend + Backend projects
- Separate service containers
- Team development

**Includes**:
- Multi-service compose file references
- Worktree support enabled
- Frontend/backend service configurations
- Debug ports for both services

### Microservices Template

```bash
.devcontainer/scripts/config-generator.sh microservices
```

**Best for**:
- Multiple independent services
- Complex architectures
- Large teams

**Includes**:
- Multiple service definitions
- Service-specific debug configurations
- Advanced worktree isolation
- Network configuration examples

---

## Project-Specific vs. Universal

### What's Project-Specific

These files live in **your project repo** and vary per project:

```
your-project/
├── .container-config.json           # ← Project-specific config
├── docker/
│   ├── docker-compose.local.yml     # ← Your services
│   ├── docker-compose.staging.yml
│   └── docker-compose.prod.yml
├── frontend/                        # ← Your code
├── backend/                         # ← Your code
└── .devcontainer/                   # ← Cloned from devcontainer-repo
```

### What's Universal

These files are **identical across all projects** (from devcontainer-repo):

```
.devcontainer/
├── scripts/
│   ├── universal-container-manager.sh   # ← Same everywhere
│   ├── version-manager.sh               # ← Same everywhere
│   └── config-generator.sh              # ← Same everywhere
├── ARCHITECTURE.md                      # ← Same everywhere
├── QUICK-START.md                       # ← Same everywhere
└── PROJECT-SETUP.md (this file)         # ← Same everywhere

~/dotfiles/                              # ← Same everywhere
├── .functions/
│   ├── git.sh                           # ← Same everywhere
│   ├── help_*.sh                        # ← Same everywhere
│   └── ...
```

**Key insight**: Universal scripts read `.container-config.json` to get project-specific settings.

---

## Branching Strategy

### Standard Git Flow

Default configuration assumes:

```
main/master     → Production environment (7500 ports)
develop         → Staging environment (7600 ports)
feature/*       → Local environment (7700 ports)
hotfix/*        → Local environment (7700 ports)
release/*       → Local environment (7700 ports)
```

### Custom Branching

If your team uses different branches, update `.container-config.json`:

**Example: GitHub Flow (main + feature branches only)**:
```json
{
  "environments": {
    "prod": {
      "branch": "main"
    },
    "staging": {
      "branch": "main",  // Same as prod for GitHub Flow
      "compose_files": ["docker/docker-compose.staging.yml"]
    },
    "local": {
      "branch": ["feature/*", "fix/*", "chore/*"],
      "fallback": true
    }
  }
}
```

**Example: Custom branch names**:
```json
{
  "environments": {
    "prod": {
      "branch": "production"  // Your custom name
    },
    "staging": {
      "branch": "qa"          // Your custom name
    }
  }
}
```

---

## Port Assignments

Port ranges are **fixed across all projects** for consistency:

```
Production:  7500-7599
Staging:     7600-7699
Local:       7700-7799
```

**Why fixed?**
- Prevents confusion when switching projects
- Easy to remember (7500=prod, 7600=staging, 7700=local)
- No conflicts between different projects (each has unique container names)

**Your services**:
Map your services to ports within the range in your docker-compose files:

```yaml
# docker/docker-compose.local.yml
services:
  frontend:
    ports:
      - "7700:3000"      # Frontend on 7700
  backend:
    ports:
      - "7710:8000"      # Backend on 7710
      - "7711:5678"      # Debugger on 7711
```

---

## Worktree Strategy

### When to Enable Worktrees

**Enable** (`"worktree_support": true`) if:
- ✅ Team of 2+ developers
- ✅ Need to debug production while developing features
- ✅ Want true branch isolation
- ✅ Investigate production issues without affecting work

**Disable** (`"worktree_support": false`) if:
- ✅ Solo developer
- ✅ Simpler workflow preferred
- ✅ Rarely debug production/staging
- ✅ Don't need branch isolation

### How Worktrees Work

When enabled:
```
your-project/                 # Main workspace (current branch)
../your-project-production/   # Debug worktree (main branch)
../your-project-staging/      # Debug worktree (develop branch)
```

Commands like `env-prod-debug` use the worktree directory, keeping your main workspace clean.

---

## Multi-Project Setup

If you work on multiple projects:

### Shared Components (Once)

```bash
# Clone dotfiles (once, for all projects)
cd ~
git clone git@github.com:YourOrg/dotfiles.git
cd dotfiles
./dotbootstrap.sh
```

### Per-Project Setup (Each project)

```bash
# Project A
cd ~/projects/project-a
git clone git@github.com:YourOrg/devcontainer-repo.git .devcontainer
.devcontainer/scripts/config-generator.sh fullstack
# Customize .container-config.json for project-a
env-local

# Project B
cd ~/projects/project-b
git clone git@github.com:YourOrg/devcontainer-repo.git .devcontainer
.devcontainer/scripts/config-generator.sh default
# Customize .container-config.json for project-b
env-local
```

**Key points**:
- Same dotfiles for all projects (shared shell environment)
- Same devcontainer scripts for all projects (universal tools)
- Different `.container-config.json` per project (project-specific settings)
- Same commands work everywhere (`gffs`, `env-local`, etc.)

---

## Validation Checklist

After setup, verify everything works:

### Basic Validation

```bash
# 1. Config file exists and is valid JSON
cat .container-config.json | jq .

# 2. Container manager recognizes project
universal-container-manager status

# 3. Start local environment
env-local

# 4. Check containers are running
docker ps | grep $(jq -r '.project.container_prefix' .container-config.json)

# 5. Test git flow commands
gvs  # Should show current version
```

### Advanced Validation

```bash
# 6. Test environment switching
env-status
env-local
env-staging
env-prod

# 7. Test worktrees (if enabled)
universal-container-manager setup-worktrees

# 8. Test feature workflow
gffs test-feature
gvs  # Should show new version
gfff
```

---

## Troubleshooting

### Config file not found

**Error**: `Configuration file not found: .container-config.json`

**Solution**:
```bash
.devcontainer/scripts/config-generator.sh default
```

### Project name detection failed

**Error**: Auto-detected name is wrong

**Solution**: Manually edit `.container-config.json`:
```json
{
  "project": {
    "name": "correct-name",
    "container_prefix": "correctname_"
  }
}
```

### Containers won't start

**Error**: Port conflicts or container name conflicts

**Solution**:
```bash
# Check what's using ports
lsof -i :7700

# Stop all environments
env-stop

# Clean Docker
docker system prune -f

# Try again
env-local
```

### Worktree issues

**Error**: Worktree creation fails

**Solution**:
```bash
# Check existing worktrees
git worktree list

# Remove if needed
git worktree remove ../project-production --force

# Or disable worktrees in config
# "worktree_support": false
```

---

## Migration Guide

### From No Config to Universal System

If you have an existing project without `.container-config.json`:

```bash
# 1. Generate default config
.devcontainer/scripts/config-generator.sh default

# 2. Update to match your existing docker-compose files
# Edit .container-config.json:
#   - Set correct compose file paths
#   - Match your branch names
#   - Set your project name

# 3. Test
env-local

# 4. Commit config
git add .container-config.json
git commit -m "chore: add universal container configuration"
```

### From Project-Specific Scripts

If you have custom container management scripts:

1. **Generate config** based on your current setup
2. **Map your environments** to the three standard ones (prod/staging/local)
3. **Update docker-compose files** to use standard port ranges
4. **Test thoroughly** before removing old scripts
5. **Document differences** for your team

---

## Best Practices

### Configuration Management

✅ **DO**:
- Commit `.container-config.json` to your repository
- Use config generator for new projects
- Document any non-standard customizations
- Keep compose file paths relative to project root

❌ **DON'T**:
- Hard-code project names in compose files
- Use absolute paths in configuration
- Modify universal scripts (they're shared)
- Skip the validation checklist

### Team Setup

**For new team members**:
1. Clone project repository
2. Generate config (if not in repo)
3. Run validation checklist
4. Read QUICK-START.md
5. Start coding with `env-local`

**For existing projects**:
1. Document your specific customizations
2. Share `.container-config.json` via git
3. Point to this PROJECT-SETUP.md for questions
4. Standardize on universal commands

---

## Summary

### Remember

1. **Universal System**: Same commands across all projects
2. **Project-Specific Config**: `.container-config.json` is your only customization
3. **One-Time Setup**: Generate config, customize if needed, commit
4. **Validation**: Always run validation checklist after setup

### Quick Reference

```bash
# Setup new project
.devcontainer/scripts/config-generator.sh [template]

# Validate setup
universal-container-manager status
env-local

# Daily usage (same across all projects!)
gffs my-feature    # Start feature
feat "commit msg"  # Commit
gfff               # Finish feature
```

---

**Need help?** Run `dot_help_all` for complete command reference.
