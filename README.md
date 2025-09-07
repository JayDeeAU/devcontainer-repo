# DevContainer Environment - Comprehensive Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [Quick Start Instructions](#quick-start-instructions)
3. [Architecture Deep Dive](#architecture-deep-dive)
4. [Feature System Implementation](#feature-system-implementation)
5. [Script System Analysis](#script-system-analysis)
6. [Maintenance and Extension Guide](#maintenance-and-extension-guide)
7. [Implementation Status](#implementation-status)

---

## Overview

This is a **modern feature-based DevContainer environment** that has been migrated from legacy Dockerfile architecture to a modular, reusable system. The environment supports Python, Node.js, and full-stack development workflows with automated project setup and persistent configurations.

### What Currently Works ✅

- **Base Environment**: Python 3.12 + Node.js 22 in Debian Bookworm
- **Package Managers**: Poetry (Python) and pnpm (Node.js) 
- **Docker Integration**: Docker-outside-of-Docker for container development
- **Git Integration**: GitHub CLI with SSH key mounting
- **Organizational Standards**: Fonts, networking tools, development utilities
- **Project Detection**: Automatic setup for Poetry and pnpm projects
- **Extension Management**: VS Code extension synchronization with backup/restore
- **AI Integration**: Claude Code CLI with persistent credentials

---

## Quick Start Instructions

### For New Projects

1. **Copy DevContainer Configuration**
   ```bash
   # In your new project directory
   cp -r /path/to/this-repo/.devcontainer ./
   ```

2. **Open in VS Code**
   ```bash
   code .
   # Ctrl+Shift+P -> "Dev Containers: Reopen in Container"
   ```

3. **Verify Installation**
   ```bash
   # After container builds (2-5 minutes)
   python --version    # Should show Python 3.12.x
   node --version     # Should show Node.js 22.x
   docker --version   # Should work (Docker-outside-of-Docker)
   gh --version       # Should show GitHub CLI
   
   # Test project dependency detection
   setup-project-dependencies
   ```

### Environment Variables

The container automatically configures:
- `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"`
- Shell default to `zsh`
- Python interpreter path: `/usr/local/python/current/bin/python`

---

## Architecture Deep Dive

### Modern Feature-Based Design

The architecture uses DevContainer's **feature system** instead of monolithic Dockerfiles. This provides modularity, reusability, and easier maintenance.

```
.devcontainer/
├── devcontainer.json              # Main configuration file
├── features/                      # Custom feature definitions
│   ├── codemian-standards/        # ✅ Implemented
│   ├── host-ssh-access/           # ✅ Implemented  
│   ├── extension-manager/         # ✅ Implemented
│   ├── claude-code/              # ✅ Implemented
│   └── git-workflows/            # 🚧 Planned (not implemented)
└── scripts/                       # Environment and project setup
    ├── setup-environment.sh       # Main post-create setup
    ├── setup-project-dependencies.sh
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
"./features/codemian-standards": {
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

#### 1. Codemian Standards Feature

**Location**: `features/codemian-standards/`

**Purpose**: Provides organizational standards and essential development tools

**devcontainer-feature.json**:
```json
{
  "id": "codemian-standards",
  "version": "1.0.0",
  "name": "Codemian Organizational Standards",
  "description": "Standard fonts, networking tools, and debugging utilities for all Codemian projects",
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
    "CODEMIAN_STANDARDS_VERSION": "1.0.0"
  }
}
```

**install.sh Implementation Details**:

1. **User Management**:
   ```bash
   # Handle existing vscode user/group conflicts
   if id -u vscode >/dev/null 2>&1; then
       userdel -r vscode 2>/dev/null || true
   fi
   
   # Create joe user with correct UID/GID
   if ! id -u joe >/dev/null 2>&1; then
       groupadd -g 1000 joe
       useradd -u 1000 -g 1000 -m -s /bin/bash joe
       usermod -aG sudo joe
       echo "joe ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/joe
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

1. **SSH Directory Setup**:
   ```bash
   # Create SSH directory structure for joe user
   mkdir -p /home/joe/.ssh
   chown joe:joe /home/joe/.ssh
   chmod 700 /home/joe/.ssh
   ```

2. **SSH Configuration**:
   ```bash
   cat > /home/joe/.ssh/config << 'EOF'
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

1. **User Detection Pattern**:
   ```bash
   CONTAINER_USER=""
   if id -u joe >/dev/null 2>&1; then
       CONTAINER_USER="joe"
   elif id -u vscode >/dev/null 2>&1; then
       CONTAINER_USER="vscode"
   else
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

### Main Environment Setup

#### setup-environment.sh

**Purpose**: Main post-create initialization script run by `postCreateCommand`

**Implementation**:
```bash
#!/usr/bin/env bash
set -e

echo "🚀 Setting up development environment..."

# 1. Setup dotfiles
echo "🏠 Setting up dotfiles..."
if [ ! -d ~/dotfiles ]; then
    git clone https://github.com/JayDeeAU/dotfiles.git ~/dotfiles
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

## Maintenance and Extension Guide

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

#### Pattern for Safe Modifications

1. **Test in isolation** by creating a test devcontainer.json
2. **Follow the user detection pattern** used in existing features
3. **Use proper ownership commands** for joe user files
4. **Handle optional dependencies** gracefully
5. **Provide meaningful error messages**

#### Example: Adding a Tool to Codemian Standards

Edit `features/codemian-standards/install.sh`:
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

### Best Practices

#### Feature Development Guidelines

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

## Implementation Status

### ✅ Completed Features

1. **Codemian Standards** - Organizational tools and utilities
2. **Host SSH Access** - SSH key mounting and git provider testing
3. **Extension Manager** - VS Code extension synchronization
4. **Claude Code** - AI development assistance with aliases

### 🚧 Planned Features (Not Implemented)

1. **Git Workflows** - Advanced git automation (referenced but not implemented)

The repository contains planning documents for git-workflows feature:
- Reference to dotfiles git automation functions
- Planned implementation structure
- Integration points identified

### 🔧 Maintenance Items

1. **Extension Manager** could be enhanced with automatic watching
2. **Project Detection** could support additional framework types
3. **Tool Manager** system exists in scripts but not integrated into features
4. **Legacy Migration** complete - old files archived in `legacy/` directory

### 🎯 Current Focus

The environment is **production-ready** for:
- Python development with Poetry
- Node.js development with pnpm  
- Full-stack projects
- Container-based development
- Git workflows with SSH authentication
- AI-assisted development with Claude Code

The modular architecture makes it easy to add new features while maintaining the existing stable functionality.