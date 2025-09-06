#!/bin/bash
# migrate-to-modern-devcontainer.sh
# Safely migrates existing DevContainer setup to modern architecture

set -e

echo "🚀 DevContainer Modernization Migration"
echo "======================================"

# Check if we're in the right directory
if [ ! -f "devcontainer.json" ]; then
    echo "❌ No devcontainer.json found. Please run this from your .devcontainer directory."
    exit 1
fi

# Create timestamp for this migration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="legacy_backup_${TIMESTAMP}"

echo "📦 Step 1: Creating backup..."
mkdir -p "${BACKUP_DIR}"

# Backup all existing files
echo "   Backing up existing devcontainer files..."
cp devcontainer.json "${BACKUP_DIR}/" 2>/dev/null || true
cp Dockerfile "${BACKUP_DIR}/" 2>/dev/null || true
cp docker-compose.yml "${BACKUP_DIR}/" 2>/dev/null || true
cp -r scripts/ "${BACKUP_DIR}/" 2>/dev/null || true
cp *.sh "${BACKUP_DIR}/" 2>/dev/null || true
cp *.md "${BACKUP_DIR}/" 2>/dev/null || true
cp .env* "${BACKUP_DIR}/" 2>/dev/null || true

echo "✅ Backup created in: ${BACKUP_DIR}"

echo "📁 Step 2: Creating modern directory structure..."

# Create the new structure
mkdir -p legacy
mkdir -p features/{codemian-standards,git-workflows,host-ssh-access,extension-manager,claude-code}
mkdir -p templates/{python-nextjs,python-only}
mkdir -p scripts

# Move files to legacy (keeping the backup separate)
echo "   Moving current files to legacy/..."
mv devcontainer.json legacy/ 2>/dev/null || true
mv Dockerfile legacy/ 2>/dev/null || true
mv docker-compose.yml legacy/ 2>/dev/null || true
mv scripts/* legacy/ 2>/dev/null || true
mv *.sh legacy/ 2>/dev/null || true

echo "✅ Legacy files archived"

echo "🔧 Step 3: Creating modern devcontainer.json..."

# Create the new modern devcontainer.json
cat > devcontainer.json << 'EOF'
{
  "name": "Modern Python + Next.js Development Environment",
  "image": "mcr.microsoft.com/devcontainers/python:3.12-bookworm",
  
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "22",
      "nodeGypDependencies": true
    },
    "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {
      "enableNonRootDocker": true,
      "moby": false
    },
    "ghcr.io/devcontainers/features/github-cli:1": {},
    "./features/codemian-standards": {},
    "./features/git-workflows": {},
    "./features/host-ssh-access": {},
    "./features/extension-manager": {},
    "./features/claude-code": {}
  },
  
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-python.vscode-pylance", 
        "ms-python.black-formatter",
        "ms-vscode.vscode-typescript-next",
        "bradlc.vscode-tailwindcss",
        "esbenp.prettier-vscode",
        "eamodio.gitlens",
        "github.copilot",
        "github.copilot-chat",
        "ms-vscode-remote.remote-containers"
      ],
      "settings": {
        "python.defaultInterpreterPath": "/usr/local/python/current/bin/python",
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  },
  
  "remoteUser": "vscode",
  "updateRemoteUserUID": true,
  
  "dotfiles.repository": "https://github.com/JayDeeAU/dotfiles.git",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": "dotbootstrap.sh",
  
  "postCreateCommand": {
    "poetry": "curl -sSL https://install.python-poetry.org | python3 - && export PATH=\"/home/vscode/.local/bin:$PATH\"",
    "pnpm": "npm install -g pnpm",
    "setup-deps": "setup-project-dependencies",
    "docker-context": "docker context use default"
  },
  
  "mounts": [
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind",
    "source=${localEnv:SSH_AUTH_SOCK},target=/ssh-agent,type=bind"
  ],
  
  "remoteEnv": {
    "SSH_AUTH_SOCK": "/ssh-agent"
  }
}
EOF

echo "✅ Modern devcontainer.json created"

echo "🏗️ Step 4: Creating first feature - Codemian Standards..."

# Create Codemian Standards feature
cat > features/codemian-standards/devcontainer-feature.json << 'EOF'
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
EOF

cat > features/codemian-standards/install.sh << 'EOF'
#!/usr/bin/env bash
# features/codemian-standards/install.sh
# Codemian organizational standards - fonts, networking tools, etc.

set -e

echo "Installing Codemian Organizational Standards..."

# Install base packages for all environments
apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-utils

# Install fonts if requested (from original Dockerfile)
if [ "${INSTALLFONTS}" = "true" ]; then
    echo "Installing Microsoft TrueType Core Fonts..."
    echo "deb http://ftp.debian.org/debian/ bookworm contrib" >> /etc/apt/sources.list
    apt-get update
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
    apt-get install -y ttf-mscorefonts-installer

    echo "Installing Google Fonts..."
    mkdir -p /usr/share/fonts/googlefonts
    wget https://github.com/google/fonts/archive/main.tar.gz -O gfonts.tar.gz
    tar -xf gfonts.tar.gz
    find fonts-main/ -name "*.ttf" -exec install -m644 {} /usr/share/fonts/googlefonts/ \;
    rm -rf fonts-main gfonts.tar.gz
    fc-cache -f -v
fi

# Install networking and debugging tools
if [ "${INSTALLNETWORKTOOLS}" = "true" ]; then
    echo "Installing networking tools..."
    apt-get install -y \
        net-tools \
        iputils-ping \
        traceroute \
        nmap \
        dnsutils \
        telnet \
        netcat-openbsd
fi

# Install additional development tools
if [ "${INSTALLDEVTOOLS}" = "true" ]; then
    echo "Installing development utilities..."
    apt-get install -y \
        jq \
        tree \
        htop \
        unzip \
        zip \
        rsync \
        xclip \
        procps \
        poppler-utils \
        fontconfig \
        zsh
fi

echo "✅ Codemian Standards installed successfully"
EOF

chmod +x features/codemian-standards/install.sh

echo "✅ Codemian Standards feature created"

echo "📝 Step 5: Creating project setup helper script..."

cat > scripts/setup-project-dependencies << 'EOF'
#!/usr/bin/env bash
# setup-project-dependencies
# Automated project dependency setup (replaces complex monorepo detection)

set -e

echo "🚀 Setting up project dependencies..."

# Poetry setup (if pyproject.toml exists)
if [ -f "pyproject.toml" ]; then
    echo "🐍 Setting up Poetry project..."
    export PATH="/home/vscode/.local/bin:$PATH"
    poetry config virtualenvs.in-project true
    poetry install
fi

# pnpm setup (if package.json exists and not in node_modules)
if [ -f "package.json" ] && [[ "$PWD" != *"node_modules"* ]]; then
    echo "📦 Setting up pnpm project..."
    pnpm install
fi

# Auto-detect common monorepo structure
for dir in frontend backend api web server magmabi; do
    if [ -d "$dir" ]; then
        echo "📁 Found $dir directory, checking for dependencies..."
        
        if [ -f "$dir/pyproject.toml" ]; then
            echo "🐍 Setting up Poetry in $dir..."
            cd "$dir"
            poetry config virtualenvs.in-project true
            poetry install || echo "⚠️ Poetry install failed for $dir"
            cd ..
        fi
        
        if [ -f "$dir/package.json" ]; then
            echo "📦 Setting up pnpm in $dir..."
            cd "$dir"
            pnpm install || echo "⚠️ pnpm install failed for $dir"
            cd ..
        fi
    fi
done

echo "✅ Project dependencies setup completed"
EOF

chmod +x scripts/setup-project-dependencies

echo "✅ Project setup script created"

echo "📋 Step 6: Creating feature placeholders..."

# Create placeholder feature files for next steps
for feature in git-workflows host-ssh-access extension-manager claude-code; do
    mkdir -p "features/${feature}"
    cat > "features/${feature}/devcontainer-feature.json" << EOF
{
  "id": "${feature}",
  "version": "1.0.0",
  "name": "${feature} Feature",
  "description": "Placeholder for ${feature} feature - to be implemented",
  "options": {}
}
EOF
    
    cat > "features/${feature}/install.sh" << EOF
#!/usr/bin/env bash
# features/${feature}/install.sh
# Placeholder - to be implemented

echo "Installing ${feature} feature..."
echo "⚠️  This is a placeholder - feature not yet implemented"
EOF
    
    chmod +x "features/${feature}/install.sh"
done

echo "✅ Feature placeholders created"

echo "📄 Step 7: Creating README with next steps..."

cat > README.md << 'EOF'
# Modern DevContainer Setup

## Migration Completed ✅

Your DevContainer has been migrated to modern architecture!

### What Was Done

1. **Legacy files archived** - All your original files are in `legacy/` and timestamped backup
2. **Modern devcontainer.json created** - Uses Features-based approach
3. **Codemian Standards feature implemented** - Your fonts, tools, and organizational standards
4. **Project setup automation** - Replaces complex monorepo detection
5. **Feature placeholders created** - Ready for implementing remaining features

### What Works Now

- ✅ Basic DevContainer with Python 3.12 + Node.js 22
- ✅ Docker-outside-of-Docker access
- ✅ GitHub CLI integration
- ✅ Codemian Standards (fonts, networking tools, dev utilities)
- ✅ Automatic project dependency setup
- ✅ Your dotfiles integration (dotbootstrap.sh)

### Next Steps

1. **Test the basic setup** - Open this in VS Code and test container rebuild
2. **Implement remaining features** one by one:
   - `git-workflows` (your git automation functions)
   - `host-ssh-access` (SSH to Docker host)
   - `extension-manager` (VS Code extension curation)
   - `claude-code` (AI development assistance)

### Testing the Migration

```bash
# 1. Rebuild container in VS Code (Ctrl+Shift+P -> "Rebuild Container")
# 2. Test basic functionality:
python --version  # Should show Python 3.12
node --version    # Should show Node.js 22
docker --version  # Should work (Docker-outside-of-Docker)
gh --version      # Should show GitHub CLI

# 3. Test project setup:
setup-project-dependencies  # Should detect and setup Poetry/pnpm projects
```

### Rollback if Needed

If anything doesn't work, you can rollback:
```bash
# Move legacy files back
cp legacy/* ./
# Remove modern structure
rm -rf features/ templates/ scripts/ README.md
```

### Feature Implementation Order

1. **Codemian Standards** ✅ (Done)
2. **Git Workflows** (Next - your most important custom functionality)
3. **Host SSH Access** (For connecting to Docker host)
4. **Extension Manager** (VS Code extension curation helper)
5. **Claude Code** (AI development assistance)

Contact: Continue with implementing the git-workflows feature next.
EOF

echo "✅ README created with next steps"

echo ""
echo "🎉 Migration Complete!"
echo "===================="
echo ""
echo "✅ Your DevContainer has been successfully migrated to modern architecture!"
echo ""
echo "📋 What to do next:"
echo "   1. Open VS Code and rebuild the container (Ctrl+Shift+P -> 'Rebuild Container')"
echo "   2. Test basic functionality (Python, Node.js, Docker access)"
echo "   3. Run 'setup-project-dependencies' to test project setup"
echo "   4. Review the README.md for detailed next steps"
echo ""
echo "📁 Your original files are safely stored in:"
echo "   - legacy/ (for reference)"
echo "   - ${BACKUP_DIR}/ (timestamped backup)"
echo ""
echo "🔧 Current status:"
echo "   ✅ Modern devcontainer.json created"
echo "   ✅ Codemian Standards feature implemented"
echo "   ⏳ 4 features ready for implementation (git-workflows, host-ssh-access, extension-manager, claude-code)"
echo ""
echo "Ready to implement the git-workflows feature next!"