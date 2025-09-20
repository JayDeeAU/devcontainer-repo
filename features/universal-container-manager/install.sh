#!/usr/bin/env bash
set -e

echo "Installing Universal Container Manager..."

# User detection (preserving existing devcontainer pattern)
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

# Install dependencies that enhanced-container-manager.sh needs
apt-get update
apt-get install -y jq curl wget

# Install universal container management scripts
mkdir -p /usr/local/bin

# Create wrapper scripts that delegate to project scripts
cat > /usr/local/bin/universal-container-manager << 'EOF'
#!/bin/bash
SCRIPT_PATH="$(pwd)/.devcontainer/scripts/universal-container-manager.sh"
if [ -f "$SCRIPT_PATH" ]; then
    "$SCRIPT_PATH" "$@"
else
    echo "❌ Universal container manager script not found at: $SCRIPT_PATH"
    echo "💡 Make sure you're in a project root with .devcontainer/scripts/"
    echo "💡 Run: universal-container-manager init (to set up new project)"
    exit 1
fi
EOF

# Create all the environment aliases (PRESERVE exact MagmaBI functionality)
cat > /usr/local/bin/env-prod << 'EOF'
#!/bin/bash
git checkout main 2>/dev/null || true
universal-container-manager switch prod "$@"
EOF

cat > /usr/local/bin/env-staging << 'EOF'
#!/bin/bash
git checkout develop 2>/dev/null || true
universal-container-manager switch staging "$@"
EOF

cat > /usr/local/bin/env-local << 'EOF'
#!/bin/bash
universal-container-manager switch local "$@"
EOF

cat > /usr/local/bin/env-prod-debug << 'EOF'
#!/bin/bash
git checkout main 2>/dev/null || true
universal-container-manager switch prod --debug "$@"
EOF

cat > /usr/local/bin/env-staging-debug << 'EOF'
#!/bin/bash
git checkout develop 2>/dev/null || true
universal-container-manager switch staging --debug "$@"
EOF

cat > /usr/local/bin/env-health << 'EOF'
#!/bin/bash
universal-container-manager health "$@"
EOF

cat > /usr/local/bin/env-status << 'EOF'
#!/bin/bash
universal-container-manager status "$@"
EOF

cat > /usr/local/bin/env-logs << 'EOF'
#!/bin/bash
universal-container-manager logs "$@"
EOF

cat > /usr/local/bin/env-stop << 'EOF'
#!/bin/bash
universal-container-manager stop "$@"
EOF

# Make all scripts executable
chmod +x /usr/local/bin/universal-container-manager
chmod +x /usr/local/bin/env-*

# Set ownership
chown -R "$CONTAINER_USER:$CONTAINER_USER" "$USER_HOME/.config" 2>/dev/null || true

echo "✅ Universal Container Manager installed successfully!"
echo "🎯 Available commands: env-prod, env-staging, env-local, env-health"
echo "🔧 Debug modes: env-prod-debug, env-staging-debug"
echo "📊 Management: env-status, env-logs, env-stop"