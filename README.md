# DevContainer Repository - Technical Documentation

> **📌 DevContainer Implementation Guide**: This document is for DevOps engineers, system administrators, and developers extending the devcontainer infrastructure. For daily development workflows, see [QUICK-START.md](QUICK-START.md).

---

## 📚 Documentation Map

**For Users:**
- [INDEX.md](INDEX.md) - Documentation overview and navigation
- [QUICK-START.md](QUICK-START.md) - 5-minute getting started guide
- [PROJECT-SETUP.md](PROJECT-SETUP.md) - One-time project configuration
- [WORKFLOWS-QUICK-REFERENCE.md](WORKFLOWS-QUICK-REFERENCE.md) - Command lookup table
- [WORKFLOWS-DETAILED-GUIDE.md](WORKFLOWS-DETAILED-GUIDE.md) - Complete workflow scenarios
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview

**For Maintainers (this document):**
- DevContainer feature system implementation
- Docker Compose configuration requirements
- Debug worktree management
- Feature development guidelines
- Extension and maintenance procedures

---

## Table of Contents

1. [Overview](#overview)
2. [Feature System Architecture](#feature-system-architecture)
3. [Docker Compose Configuration Requirements](#docker-compose-configuration-requirements)
4. [Debug Worktree Management](#debug-worktree-management)
5. [Feature Development Guide](#feature-development-guide)
6. [Maintenance Procedures](#maintenance-procedures)

---

## Overview

This is a **modern feature-based DevContainer environment** designed for universal cross-project use. The environment supports Python, Node.js, and full-stack development workflows with automated project setup and persistent configurations.

### Core Philosophy

- **Universal Design**: Works identically across all projects - clone once, use everywhere
- **Feature-Based**: Modular components, not monolithic Dockerfiles
- **Project-Agnostic**: Configuration via `.container-config.json` (generated per project)
- **Developer-Focused**: Hide complexity, expose simple commands

> **📌 Universal Repository**: This is the `devcontainer-repo` that gets cloned into your project's `.devcontainer/` directory. The same code works for any project - only `.container-config.json` differs per project.

### How It Works

1. **Clone devcontainer-repo** into your project: `.devcontainer/`
2. **Generate config** for your project: `config-generator.sh`
3. **Customize features** (optional): Edit `devcontainer.json`
4. **Use everywhere**: Same commands, scripts, and workflows across all projects

### What This Environment Provides

- **Base Environment**: Python 3.12 + Node.js 22 in Debian Bookworm
- **Package Managers**: Poetry (Python) and pnpm (Node.js) 
- **Docker Integration**: Docker-outside-of-Docker for container development
- **Git Integration**: GitHub CLI with SSH key mounting
- **Extension Management**: VS Code extension synchronization with backup/restore
- **AI Integration**: Claude Code CLI with persistent credentials
- **Universal Container Manager**: Multi-environment orchestration (prod/staging/local)
- **Version Manager**: Sequential semantic versioning for parallel development

---

## Feature System Architecture

### Modern Feature-Based Design

The architecture uses DevContainer's **feature system** instead of monolithic Dockerfiles. This provides modularity, reusability, and easier maintenance across multiple projects.

```
.devcontainer/
├── devcontainer.json              # Main configuration file
├── features/                      # Custom feature definitions
│   ├── organizational-standards/  # ✅ Development tools & utilities
│   ├── host-ssh-access/           # ✅ SSH key mounting  
│   ├── extension-manager/         # ✅ VS Code extension sync
│   └── claude-code/              # ✅ AI assistance integration
└── scripts/                       # Environment and project setup
    ├── setup-environment.sh       # Main post-create setup
    ├── setup-project-dependencies.sh
    ├── universal-container-manager.sh
    ├── version-manager.sh
    ├── config-generator.sh
    ├── sync-extensions.sh
    ├── list-extensions.sh
    └── restore-extensions.sh
```

### Container Configuration Analysis

#### Base Container
```json
{
  "name": "Modern Python + Next.js Development Environment",
  "image": "mcr.microsoft.com/devcontainers/python:3.12-bookworm",
  "runArgs": ["--name", "devcontainer_codemian", "--hostname", "devcontainer"]
}
```

#### External Features (Third-Party)
```json
"features": {
  "ghcr.io/devcontainers/features/common-utils:2": {
    "installZsh": true,
    "configureZshAsDefaultShell": true,
    "installOhMyZsh": false,           // Disabled for performance
    "username": "joe",                 // Custom user instead of vscode
    "userUid": "1000",
    "userGid": "1000",
    "upgradePackages": true,
    "nonFreePackages": false
  },
  "ghcr.io/devcontainers/features/node:1": {
    "version": "22",
    "nodeGypDependencies": true
  },
  "ghcr.io/devcontainers-extra/features/poetry:2": {},
  "ghcr.io/devcontainers-extra/features/pnpm:2": {},
  "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {
    "enableNonRootDocker": true,
    "moby": false                      // Use host Docker, not Moby
  },
  "ghcr.io/devcontainers/features/github-cli:1": {}
}
```

#### Internal Features (Custom)
```json
"./features/organizational-standards": {
  "installFonts": false,              // Disabled for faster builds
  "installNetworkTools": true,
  "installDevTools": true
},
"./features/host-ssh-access": {},
"./features/extension-manager": {
  "autoSync": true,
  "watchInterval": "30",
  "backupExtensions": true
},
"./features/claude-code": {
  "installLatest": true,
  "createAliases": true
}
```

#### Persistent Mounts
```json
"mounts": [
  "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind",
  "source=${localEnv:HOME}/.ssh,target=/home/joe/.ssh,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.claude,target=/home/joe/.claude,type=bind,consistency=cached"
]
```

#### Lifecycle Automation
```json
"postCreateCommand": "chmod +x .devcontainer/scripts/setup-environment.sh && .devcontainer/scripts/setup-environment.sh"
```

---

## Feature System Implementation

### Feature Structure Pattern

Each feature follows this standardized structure:
```
features/<feature-name>/
├── devcontainer-feature.json    # Feature metadata and options
├── install.sh                   # Installation logic (runs during build)
└── README.md                     # Documentation (if exists)
```

### Feature Implementation Deep Dive

#### 1. Organizational Standards Feature

**Location**: `features/organizational-standards/`

**Purpose**: Provides organizational standards and essential development tools (customize for your organization)

**devcontainer-feature.json**:
```json
{
  "id": "organizational-standards",
  "version": "1.0.0",
  "name": "Organizational Standards",
  "description": "Standard fonts, networking tools, and debugging utilities for organizational projects",
  "options": {
    "installFonts": {
      "type": "boolean",
      "default": true,
      "description": "Install Microsoft and Google fonts"
    },
    "installNetworkTools": {
      "type": "boolean", 
      "default": true,
      "description": "Install networking and debugging tools"
    },
    "installDevTools": {
      "type": "boolean",
      "default": true,
      "description": "Install additional development utilities"
    }
  },
  "containerEnv": {
    "ORG_STANDARDS_VERSION": "1.0.0"
  }
}
```

**install.sh Implementation Details**:

1. **User Management Pattern**:
   ```bash
   # Handle existing vscode user/group conflicts
   if id -u vscode >/dev/null 2>&1; then
       userdel -r vscode 2>/dev/null || true
   fi
   
   # Create custom user with correct UID/GID (customize username as needed)
   CONTAINER_USER="youruser"  # Change this to your preferred username
   if ! id -u $CONTAINER_USER >/dev/null 2>&1; then
       groupadd -g 1000 $CONTAINER_USER
       useradd -u 1000 -g 1000 -m -s /bin/bash $CONTAINER_USER
       usermod -aG sudo $CONTAINER_USER
       echo "$CONTAINER_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$CONTAINER_USER
   fi
   ```

2. **Font Installation** (when enabled):
   ```bash
   if [ "${INSTALLFONTS}" = "true" ]; then
       # Microsoft TrueType Core Fonts
       echo "deb http://ftp.debian.org/debian/ bookworm contrib" >> /etc/apt/sources.list
       apt-get update
       echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
       apt-get install -y ttf-mscorefonts-installer
       
       # Google Fonts
       mkdir -p /usr/share/fonts/googlefonts
       wget https://github.com/google/fonts/archive/main.tar.gz -O gfonts.tar.gz
       tar -xf gfonts.tar.gz
       find fonts-main/ -name "*.ttf" -exec install -m644 {} /usr/share/fonts/googlefonts/ \;
       fc-cache -f -v
   fi
   ```

3. **Development Tools Installation**:
   ```bash
   if [ "${INSTALLDEVTOOLS}" = "true" ]; then
       apt-get install -y \
           jq \         # JSON processor
           tree \       # Directory tree viewer
           htop \       # Process monitor
           unzip zip \  # Archive tools
           rsync \      # File synchronization
           xclip \      # Clipboard tool
           procps \     # Process utilities
           poppler-utils \ # PDF utilities
           zsh          # Z shell
   fi
   ```

#### 2. Host SSH Access Feature

**Location**: `features/host-ssh-access/`

**Purpose**: Enables persistent SSH key access for git operations

**devcontainer-feature.json**:
```json
{
  "id": "host-ssh-access",
  "version": "1.0.0",
  "name": "Host SSH Access",
  "description": "Provides persistent SSH key access from host to DevContainer for git operations",
  "options": {
    "setupGitConfig": {
      "type": "boolean",
      "default": true,
      "description": "Automatically configure git user settings"
    },
    "testConnections": {
      "type": "boolean",
      "default": true,
      "description": "Test SSH connections to common git providers"
    },
    "gitProviders": {
      "type": "string",
      "default": "github.com,gitlab.com",
      "description": "Comma-separated list of git providers to test"
    }
  },
  "containerEnv": {
    "GIT_SSH_COMMAND": "ssh -o StrictHostKeyChecking=no"
  }
}
```

**install.sh Implementation Details**:

1. **SSH Directory Setup Pattern**:
   ```bash
   # Create SSH directory structure for container user
   # (CONTAINER_USER detected using pattern above)
   USER_HOME="/home/$CONTAINER_USER"
   mkdir -p "$USER_HOME/.ssh"
   chown "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.ssh"
   chmod 700 "$USER_HOME/.ssh"
   ```

2. **SSH Configuration Pattern**:
   ```bash
   cat > "$USER_HOME/.ssh/config" << 'EOF'
   Host github.com
       HostName github.com
       User git
       IdentitiesOnly yes
       StrictHostKeyChecking no
       UserKnownHostsFile /dev/null
   
   Host gitlab.com
       HostName gitlab.com
       User git
       IdentitiesOnly yes
       StrictHostKeyChecking no
       UserKnownHostsFile /dev/null
   EOF
   ```

3. **Utility Scripts Created**:
   - `/usr/local/bin/test-ssh-access` - Tests SSH connections to git providers
   - `/usr/local/bin/setup-git-user` - Interactive git user configuration
   - `/usr/local/bin/ssh-post-create` - Post-container-creation SSH setup

#### 3. Extension Manager Feature

**Location**: `features/extension-manager/`

**Purpose**: Automatically manages VS Code extensions and syncs with devcontainer.json

**devcontainer-feature.json**:
```json
{
  "id": "extension-manager",
  "version": "1.0.0",
  "name": "VS Code Extension Manager",
  "description": "Automatically captures extension changes and syncs with devcontainer.json configuration",
  "options": {
    "autoSync": {
      "type": "boolean",
      "default": true,
      "description": "Automatically sync installed extensions to devcontainer.json"
    },
    "watchInterval": {
      "type": "string",
      "default": "30",
      "description": "How often to check for extension changes (seconds)"
    },
    "backupExtensions": {
      "type": "boolean",
      "default": true,
      "description": "Create backup of extension list before changes"
    }
  },
  "containerEnv": {
    "EXTENSION_MANAGER_AUTO_SYNC": "${autoSync}",
    "EXTENSION_MANAGER_WATCH_INTERVAL": "${watchInterval}"
  }
}
```

**install.sh Implementation Details**:

1. **Wrapper Script Pattern**:
   The feature creates wrapper scripts that delegate to the actual implementation in `.devcontainer/scripts/`:
   
   ```bash
   cat > /usr/local/bin/sync-extensions << 'EOF'
   #!/bin/bash
   SCRIPT_PATH="/workspaces/$(basename $PWD)/.devcontainer/scripts/sync-extensions.sh"
   if [ -f "$SCRIPT_PATH" ]; then
       "$SCRIPT_PATH" "$@"
   else
       echo "❌ Extension sync script not found at: $SCRIPT_PATH"
       exit 1
   fi
   EOF
   ```

2. **Commands Created**:
   - `sync-extensions` - Manually sync extensions to devcontainer.json
   - `list-extensions` - Show extension status report  
   - `restore-extensions` - Restore from backup

#### 4. Claude Code Feature

**Location**: `features/claude-code/`

**Purpose**: Integrates Claude Code AI assistant with persistent API key storage

**devcontainer-feature.json**:
```json
{
  "id": "claude-code",
  "version": "1.0.0", 
  "name": "Claude Code AI Assistant",
  "description": "Installs Claude Code CLI with persistent API key configuration across container rebuilds",
  "options": {
    "installLatest": {
      "type": "boolean",
      "default": true,
      "description": "Install the latest version of Claude Code"
    },
    "createAliases": {
      "type": "boolean",
      "default": true,
      "description": "Create convenient aliases for Claude Code commands"
    }
  }
}
```

**install.sh Implementation Details**:

1. **User Detection Pattern** (use in all features):
   ```bash
   # Detect container user (customize list for your setup)
   CONTAINER_USER=""
   for user in youruser joe vscode; do
       if id -u $user >/dev/null 2>&1; then
           CONTAINER_USER="$user"
           break
       fi
   done
   
   if [ -z "$CONTAINER_USER" ]; then
       echo "❌ No suitable user found"
       exit 1
   fi
   ```

2. **Node.js Dependency**:
   ```bash
   if ! command -v node &> /dev/null; then
       curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
       apt-get install -y nodejs
   fi
   
   npm install -g @anthropic-ai/claude-code
   ```

3. **Alias Creation**:
   ```bash
   cat > "$USER_HOME/.claude-code-aliases" << 'EOF'
   alias cc='claude'
   alias cc-setup='claude-setup'
   alias cc-python='claude "write python code for:"'
   alias cc-js='claude "write javascript code for:"'
   alias cc-fix='claude "fix this code:"'
   alias cc-explain='claude "explain this code:"'
   alias cc-review='claude "review this code for bugs and improvements:"'
   EOF
   ```

---

## Script System Analysis

### Main Environment Setup Script

#### setup-environment.sh

**Purpose**: Main post-create initialization script run by `postCreateCommand`

**Implementation Pattern**:
```bash
#!/usr/bin/env bash
set -e

echo "🚀 Setting up development environment..."

# 1. Setup dotfiles (customize repository URL)
echo "🏠 Setting up dotfiles..."
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/yourorg/dotfiles.git}"
if [ ! -d ~/dotfiles ]; then
    git clone $DOTFILES_REPO ~/dotfiles
    cd ~/dotfiles
    chmod +x ./dotbootstrap.sh
    ./dotbootstrap.sh || echo "⚠️ Dotfiles setup failed, continuing..."
    cd -
else
    echo "📁 Dotfiles directory already exists, skipping clone"
fi

# 2. Setup project dependencies
echo "📦 Setting up project dependencies..."
chmod +x .devcontainer/scripts/setup-project-dependencies.sh
.devcontainer/scripts/setup-project-dependencies.sh

# 3. Set docker context
echo "🐳 Setting docker context..."
docker context use default

echo "✅ Environment setup completed"
```

#### setup-project-dependencies.sh

**Purpose**: Intelligent project type detection and dependency installation

**Detection Logic**:
```bash
# Skip if this is a devcontainer repository itself
if [ -d "features" ] && [ -d "templates" ] && [ -f "devcontainer.json" ]; then
    echo "🏗️ Detected devcontainer repository structure - skipping project dependency setup"
    exit 0
fi

# Poetry project detection
if [ -f "pyproject.toml" ]; then
    echo "🐍 Setting up Poetry project..."
    poetry config virtualenvs.in-project true
    poetry install
fi

# Node.js project detection  
if [ -f "package.json" ] && [[ "$PWD" != *"node_modules"* ]]; then
    echo "📦 Setting up pnpm project..."
    pnpm install
fi

# Monorepo structure detection
for dir in frontend backend api web server; do
    if [ -d "$dir" ]; then
        echo "📁 Found $dir directory, checking for dependencies..."
        # Check for pyproject.toml or package.json in subdirectories
    fi
done
```

### Extension Management Scripts

#### sync-extensions.sh

**Purpose**: Captures VS Code extension changes and syncs to devcontainer.json

**Core Logic**:
```bash
# Get currently installed extensions
get_current_extensions() {
    code --list-extensions 2>/dev/null | sort | jq -R . | jq -s .
}

# Get extensions from devcontainer.json
get_devcontainer_extensions() {
    if [ -f "$DEVCONTAINER_JSON" ]; then
        jq -r '.customizations.vscode.extensions[]? // empty' "$DEVCONTAINER_JSON" 2>/dev/null | sort | jq -R . | jq -s .
    else
        echo "[]"
    fi
}

# Update devcontainer.json with new extensions
update_devcontainer_json() {
    local new_extensions="$1"
    
    # Create backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$DEVCONTAINER_JSON" "$BACKUP_DIR/devcontainer-$timestamp.json"
    
    # Update extensions array
    local temp_file=$(mktemp)
    jq --argjson extensions "$new_extensions" \
       '.customizations.vscode.extensions = $extensions' \
       "$DEVCONTAINER_JSON" > "$temp_file"
    
    mv "$temp_file" "$DEVCONTAINER_JSON"
}
```

#### list-extensions.sh

**Purpose**: Shows extension status report comparing installed vs configured

**Output Format**:
```bash
📦 Extension Status Report
==========================

🔧 Currently Installed:
  ✓ anthropic.claude-code
  ✓ bradlc.vscode-tailwindcss
  ✓ ms-python.python

📄 In devcontainer.json:
  📝 anthropic.claude-code
  📝 ms-python.python

📊 Statistics:
  Installed: 15 extensions
  In config: 13 extensions

💡 Commands:
  sync-extensions     - Sync installed extensions to devcontainer.json
  list-extensions     - Show this status report
  restore-extensions  - Restore from backup
```

#### restore-extensions.sh

**Purpose**: Restore devcontainer.json from backup

**Interactive Process**:
```bash
# Show available backups
echo "📋 Available backups:"
find "$BACKUP_DIR" -name "devcontainer-*.json" -printf "%f %TY-%Tm-%Td %TH:%TM\n" | sort -r | head -10

# User selects backup
read -p "Enter backup filename (or press Enter to cancel): " backup_file

# Show what will be restored
echo "📄 Extensions in backup:"
jq -r '.customizations.vscode.extensions[]? // empty' "$BACKUP_DIR/$backup_file" | sort | sed 's/^/  - /'

# Confirm and restore
read -p "Restore this backup? (y/N): " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cp "$BACKUP_DIR/$backup_file" "$DEVCONTAINER_JSON"
    echo "✅ Restored from backup: $backup_file"
fi
```

---

## Docker Compose Configuration Requirements

### Pull Policy Configuration

When using the Universal Container Manager with your project's docker-compose files, **it is critical** to configure the `pull_policy` correctly for each environment to avoid using stale images.

#### Problem: Stale Images After Build

Without proper `pull_policy` settings, Docker Compose may pull old images from GHCR **even when you just built fresh images locally**, causing your latest code changes to not appear in running containers.

#### Solution: Environment-Specific Pull Policies

**For Staging Environment (`docker-compose.staging.yml`):**
```yaml
services:
  backend:
    image: ghcr.io/yourorg/project/backend:staging
    build:
      context: ./backend
      dockerfile: Dockerfile
    pull_policy: build  # Always build when context available, don't pull
    ports:
      - "7610:8000"

  frontend:
    image: ghcr.io/yourorg/project/frontend:staging
    build:
      context: ./frontend
      dockerfile: Dockerfile
    pull_policy: build  # Always build when context available, don't pull
    ports:
      - "7600:3000"
```

**For Local Environment (`docker-compose.local.yml`):**
```yaml
services:
  backend:
    image: ghcr.io/yourorg/project/backend:local
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    pull_policy: build  # or "never" - always use local builds
    ports:
      - "7710:8000"
    volumes:
      - ./backend:/app  # Source mounting for hot reload

  frontend:
    image: ghcr.io/yourorg/project/frontend:local
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    pull_policy: build  # or "never" - always use local builds
    ports:
      - "7700:3000"
    volumes:
      - ./frontend:/app  # Source mounting for hot reload
```

**For Production Environment (`docker-compose.prod.yml`):**
```yaml
services:
  backend:
    image: ghcr.io/yourorg/project/backend:prod
    pull_policy: always  # Always pull stable images from GHCR
    # No build section - production pulls pre-built images
    ports:
      - "7510:8000"

  frontend:
    image: ghcr.io/yourorg/project/frontend:prod
    pull_policy: always  # Always pull stable images from GHCR
    # No build section - production pulls pre-built images
    ports:
      - "7500:3000"
```

#### Pull Policy Options Explained

- **`build`** (Recommended for staging/local):
  - Tries to build if build context is available
  - Falls back to pulling if build context not available
  - Best for development machines with source code

- **`never`** (Alternative for staging/local):
  - Never pulls from registry, always uses local images
  - Fails if image doesn't exist locally
  - More explicit than `build` but less flexible

- **`always`** (Recommended for production):
  - Always pulls latest image from registry before starting
  - Ensures you're running the latest pushed version
  - Required for production deployments

- **`if_not_present`** (Default behavior):
  - Only pulls if image doesn't exist locally
  - Can cause issues if local image is stale

- **`missing`**:
  - Similar to `if_not_present`
  - Only pulls if no image found locally

#### Universal Container Manager Integration

The Universal Container Manager build logic works as follows:

```bash
# Staging/Local
env-staging          # Uses existing images (no build, no push)
env-staging --build  # Builds fresh, prompts to push to GHCR

# Production
env-prod             # Pulls from GHCR (stable images)
env-prod --build     # Builds locally, prompts to push

# Local
env-local            # Uses existing images (fast restart)
env-local --build    # Rebuilds with latest changes
```

With `pull_policy: build` in staging/local compose files:
- `docker compose build` creates fresh local images
- `docker compose up -d` uses those fresh local images (not GHCR)
- Push to GHCR happens after verification
- Other machines can pull from GHCR

#### Migration Checklist

If you're experiencing stale image issues, check:

1. ✅ Add `pull_policy: build` to all services in `docker-compose.staging.yml`
2. ✅ Add `pull_policy: build` to all services in `docker-compose.local.yml`
3. ✅ Add `pull_policy: always` to all services in `docker-compose.prod.yml`
4. ✅ Remove any `pull_policy` from production if it has `build` sections
5. ✅ Test: `env-staging --build` should use freshly built images
6. ✅ Test: `env-prod` should pull from GHCR

---

### Debug Worktree Management

The Universal Container Manager uses **Git worktrees** for isolated debugging of production and staging environments. This ensures your debug sessions don't affect your main workspace and allows you to preserve temporary debugging code between sessions.

#### How Worktrees Work

**Debug Modes That Use Worktrees:**
- `env-prod-debug` (or `env-prod --debug`): Creates worktree at `../project-production` (main branch)
- `env-prod-sync` (or `env-prod --debug --sync`): Refresh production worktree with latest from origin/main
- `env-staging-debug` (or `env-staging --debug`): Creates worktree at `../project-staging` (develop branch)
- `env-staging-sync` (or `env-staging --debug --sync`): Refresh staging worktree with latest from origin/develop

**Debug Mode Without Worktree:**
- `env-local`: Uses current directory (stays on your current branch)
- `env-local` with debugger: Same as above, just enables debugger wait

**Regular Modes (No Source Mounting):**
- `env-prod`: Uses built images only, no source mount
- `env-staging`: Uses built images only, no source mount

#### Worktree Lifecycle

**First Debug Session:**
```bash
# Creates worktree and syncs from origin
env-staging --debug

# Worktree created at: ../project-staging
# Branch: develop (synced from origin)
# Port: 7611
```

**Subsequent Debug Sessions:**
```bash
# Uses existing worktree, preserves your changes
env-staging --debug

# Your debug prints and temporary code are still there!
# No automatic sync - your scratch pad is preserved
```

**Updating Worktree:**
```bash
# Pull latest changes from origin when needed
env-staging-sync           # Shortcut alias
# or
env-staging --debug --sync # Alternative form

# This will:
# 1. Switch to develop branch (if detached)
# 2. Pull latest from origin/develop
# 3. You'll lose any temporary debug code
```

#### Key Behaviors

**Worktrees Are Scratch Pads:**
- ✅ Add debug prints, temporary logging, test code
- ✅ Changes stay between sessions (until you --sync)
- ❌ Don't commit important work here
- ❌ Changes never sync back to origin

**Branch Conflicts Handled:**
If your main workspace is on the same branch as a debug environment:
```bash
# Main workspace on develop
cd ~/my-project

# This works! Creates detached HEAD worktree
env-staging --debug

# Worktree created in detached state to avoid conflicts
# You can still debug normally
```

**Source Mounting Matrix:**
```
Environment         Source Mount?    Worktree Location        Branch
-----------         -------------    -----------------        ------
prod                No               N/A                      (uses image)
prod --debug        Yes              ../project-production    main
staging             No               N/A                      (uses image)  
staging --debug     Yes              ../project-staging       develop
local               Yes              Current directory        (your branch)
local (debugger)    Yes              Current directory        (your branch)
```

#### Manual Worktree Setup

If you want to pre-create both worktrees:
```bash
# Creates both prod and staging worktrees with latest sync
universal-container-manager setup-worktrees

# This is optional - worktrees auto-create on first --debug use
```

#### Troubleshooting

**Issue: "Branch already used by worktree"**
```bash
# This is automatically handled!
# If branch is checked out in main workspace,
# worktree uses detached HEAD instead
```

**Issue: Worktree stuck in detached HEAD**
```bash
# Use --sync to recover
env-staging --debug --sync

# This will:
# 1. Checkout develop branch
# 2. Pull latest changes
```

**Issue: Want to clean up worktree**
```bash
# Remove worktree manually
git worktree remove ../project-staging --force

# Next debug session will recreate it fresh
```

#### Best Practices

1. **Use worktrees for read-only debugging**
   - Look at production/staging code
   - Add temporary prints/logs
   - Test quick fixes before implementing properly

2. **Use --sync when starting fresh investigation**
   - Pull latest code before debugging new issue
   - Reset worktree to clean state

3. **Don't use --sync mid-debugging**
   - Preserves your temporary debug code
   - Allows multi-session investigations

4. **Regular env-staging doesn't affect your work**
   - Only debug modes mount source
   - Safe to restart staging environment anytime

---

## Feature Development Guide

> **For maintainers adding new features to the devcontainer system**

### Adding a New Feature

#### 1. Create Feature Directory Structure
```bash
mkdir -p features/my-new-feature
```

#### 2. Create Feature Definition

**features/my-new-feature/devcontainer-feature.json**:
```json
{
  "id": "my-new-feature",
  "version": "1.0.0",
  "name": "My New Feature",
  "description": "Description of what this feature does",
  "options": {
    "enableOption": {
      "type": "boolean",
      "default": true,
      "description": "Enable this feature option"
    }
  },
  "containerEnv": {
    "MY_FEATURE_ENABLED": "true"
  }
}
```

#### 3. Create Installation Script

**features/my-new-feature/install.sh**:
```bash
#!/usr/bin/env bash
set -e

echo "Installing My New Feature..."

# Get options (environment variables are UPPERCASE)
ENABLE_OPTION=${ENABLEOPTION:-true}

# User detection pattern (copy from existing features)
CONTAINER_USER=""
if id -u joe >/dev/null 2>&1; then
    CONTAINER_USER="joe"
elif id -u vscode >/dev/null 2>&1; then
    CONTAINER_USER="vscode"
else
    echo "❌ No suitable user found"
    exit 1
fi

USER_HOME="/home/$CONTAINER_USER"

# Installation logic here
if [ "$ENABLE_OPTION" = "true" ]; then
    echo "📦 Installing feature components..."
    # Your installation commands
fi

# Set ownership
chown -R "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.config/my-feature"

echo "✅ My New Feature installed successfully!"
```

#### 4. Update Main Configuration

Add to `.devcontainer/devcontainer.json`:
```json
{
  "features": {
    "./features/my-new-feature": {
      "enableOption": true
    }
  }
}
```

### Modifying Existing Features

> **Guidelines for safe modifications to existing feature implementations**

#### Pattern for Safe Modifications

1. **Test in isolation** by creating a test devcontainer.json
2. **Follow the user detection pattern** used in existing features
3. **Use proper ownership commands** for joe user files
4. **Handle optional dependencies** gracefully
5. **Provide meaningful error messages**

#### Example: Adding a Tool to Organizational Standards

Edit `features/organizational-standards/install.sh`:
```bash
# Add to the development tools section
if [ "${INSTALLDEVTOOLS}" = "true" ]; then
    apt-get install -y \
        jq \
        tree \
        htop \
        # ... existing tools ...
        your-new-tool    # Add your tool here
fi
```

---

## Maintenance Procedures

> **For system administrators maintaining the devcontainer infrastructure**

### Best Practices for Feature Development

1. **Idempotent Operations**: Features should be safe to run multiple times
2. **User Detection**: Always handle both joe and vscode users
3. **Error Handling**: Use `set -e` and provide meaningful error messages
4. **Ownership**: Always set correct ownership for user files
5. **Environment Variables**: Options become UPPERCASE environment variables
6. **Dependencies**: Install required packages at the beginning

#### Testing Features

1. **Build Test**:
   ```bash
   # Test devcontainer build
   # Ctrl+Shift+P -> "Dev Containers: Rebuild Container"
   ```

2. **Functionality Test**:
   ```bash
   # Verify your feature works
   echo $MY_FEATURE_ENABLED
   which your-new-tool
   ```

3. **User Permissions Test**:
   ```bash
   # Check file ownership
   ls -la ~/.config/my-feature
   ```

---

## Implementation Status & Known Issues

### ✅ Production-Ready Components

All features and scripts are production-ready and actively used across multiple projects:

1. **Organizational Standards** - Development tools and utilities (customize for your needs)
2. **Host SSH Access** - SSH key mounting and git provider authentication
3. **Extension Manager** - VS Code extension synchronization and backup
4. **Claude Code** - AI development assistance with persistent credentials
5. **Universal Container Manager** - Multi-environment Docker orchestration
6. **Version Manager** - Sequential semantic versioning for parallel development
7. **Project Detection** - Automatic setup for Poetry and pnpm projects

### 🔧 Customization Points

When deploying to a new organization:

1. **Feature Names**: Rename `organizational-standards` to match your org
2. **User Configuration**: Update default username pattern in features
3. **Dotfiles Repository**: Update `DOTFILES_REPO` URL in setup-environment.sh
4. **Templates**: Customize `.devcontainer/templates/` for common project types
5. **Port Ranges**: Adjust port assignments in universal-container-manager.sh if needed

### 📚 Legacy Documentation

The repository contains archived planning documents in `legacy/` directory:
- Old Dockerfile migration notes
- Feature planning documents
- Pre-refactor documentation

These are kept for historical reference but are not part of the current implementation.

---

## Support & Contribution

### Getting Help

- **User Questions**: See [INDEX.md](INDEX.md) for documentation navigation
- **Technical Issues**: Check this README and feature implementation details
- **Feature Requests**: Propose new features following the patterns in this guide

### Contributing

When contributing new features:
1. Follow the feature structure pattern
2. Use the user detection pattern
3. Make it project-agnostic
4. Document in feature README.md
5. Update this technical guide

---