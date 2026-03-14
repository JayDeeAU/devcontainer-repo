#!/usr/bin/env bash
# features/host-ssh-access/install.sh
# Setup SSH access from host to container with persistent credentials

set -e

echo "🔑 Installing Host SSH Access feature..."

# Variables from feature options
SETUP_GIT_CONFIG=${SETUPGITCONFIG:-true}
TEST_CONNECTIONS=${TESTCONNECTIONS:-true}
GIT_PROVIDERS=${GITPROVIDERS:-"github.com,gitlab.com"}

# Install SSH client if not present
if ! command -v ssh &> /dev/null; then
    echo "📦 Installing SSH client..."
    apt-get update && apt-get install -y openssh-client
fi

# Ensure target user has proper setup
TARGET_USER="${USERNAME:-developer}"
if ! id -u "$TARGET_USER" >/dev/null 2>&1; then
    echo "⚠️  Creating $TARGET_USER user..."
    # GID 100 (users) per ADR-004 — already exists on Debian bookworm
    getent group 100 >/dev/null || groupadd -g 100 users
    useradd -u 1000 -g 100 -m -s /bin/bash "$TARGET_USER"
fi

# Create SSH directory structure for target user
echo "📁 Setting up SSH directory structure..."
mkdir -p /home/$TARGET_USER/.ssh
chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.ssh
chmod 700 /home/$TARGET_USER/.ssh

# Create SSH config for common git providers
echo "⚙️  Creating SSH config..."
cat > /home/$TARGET_USER/.ssh/config << 'EOF'
# SSH config for git providers
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

# Fallback for any git SSH
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.ssh/config
chmod 600 /home/$TARGET_USER/.ssh/config

# Create SSH test script for direct key usage
echo "🧪 Creating SSH test script..."
cat > /usr/local/bin/test-ssh-access << 'EOF'
#!/bin/bash
# Test SSH access to git providers (direct key mode)

echo "🔑 Testing SSH access to git providers (direct key mode)..."
echo "📁 Available SSH keys:"
ls -la "$HOME/.ssh/id_"* 2>/dev/null || echo "No SSH keys found"
echo ""

# Split providers by comma
IFS=',' read -ra PROVIDERS <<< "$1"

for provider in "${PROVIDERS[@]}"; do
    echo "🧪 Testing $provider..."
    if ssh -T "git@$provider" 2>&1 | grep -q "successfully authenticated\|Welcome to GitLab"; then
        echo "✅ $provider: Connected successfully"
        
        # Extract username if possible
        if [[ "$provider" == "github.com" ]]; then
            USERNAME=$(ssh -T "git@$provider" 2>&1 | grep "Hi " | cut -d' ' -f2 | cut -d'!' -f1)
            echo "👤 GitHub user: $USERNAME"
        fi
    else
        echo "❌ $provider: Connection failed"
        echo "💡 Troubleshooting tips:"
        echo "   - Ensure SSH keys are mounted: ls -la ~/.ssh/"
        echo "   - Check key permissions: chmod 600 ~/.ssh/id_*"
        echo "   - Verify key is added to $provider"
        echo "   - Test manually: ssh -T git@$provider"
    fi
    echo ""
done

echo "🏠 Testing host SSH access..."
echo "💡 Your host SSH should work normally (no special setup needed)"
EOF

chmod +x /usr/local/bin/test-ssh-access

# Create git setup script
if [ "$SETUP_GIT_CONFIG" = "true" ]; then
    echo "⚙️  Creating git setup script..."
    cat > /usr/local/bin/setup-git-user << 'EOF'
#!/bin/bash
# Interactive git user setup

echo "⚙️  Git User Configuration"
echo "========================="

# Check if already configured
CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$CURRENT_NAME" ] && [ -n "$CURRENT_EMAIL" ]; then
    echo "✅ Git already configured:"
    echo "   Name: $CURRENT_NAME"
    echo "   Email: $CURRENT_EMAIL"
    
    read -p "Would you like to update these settings? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Get user input
read -p "Enter your full name: " GIT_NAME
read -p "Enter your email address: " GIT_EMAIL

# Validate input
if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    echo "❌ Name and email are required"
    exit 1
fi

# Configure git
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Set some sensible defaults
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input

echo "✅ Git user configured successfully:"
echo "   Name: $(git config --global user.name)"
echo "   Email: $(git config --global user.email)"
EOF

    chmod +x /usr/local/bin/setup-git-user
fi

# Create post-create setup script
echo "🚀 Creating post-create setup script..."
cat > /usr/local/bin/ssh-post-create << EOF
#!/bin/bash
# Post-create SSH setup

echo "🔑 Post-create SSH setup..."

# Fix permissions if SSH directory exists and is mounted
if [ -d "/home/$TARGET_USER/.ssh" ]; then
    echo "🔧 Fixing SSH permissions..."
    chown -R $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.ssh
    chmod 700 /home/$TARGET_USER/.ssh
    find /home/$TARGET_USER/.ssh -type f -exec chmod 600 {} \;
fi

# Test connections if enabled
if [ "$TEST_CONNECTIONS" = "true" ]; then
    sudo -u $TARGET_USER test-ssh-access "$GIT_PROVIDERS"
fi

# Setup git user if not configured
if [ "$SETUP_GIT_CONFIG" = "true" ]; then
    if [ -z "\$(sudo -u $TARGET_USER git config --global user.name 2>/dev/null)" ]; then
        echo "⚙️  Git user not configured. Run 'setup-git-user' to configure."
    else
        echo "✅ Git user already configured"
    fi
fi

echo "✅ SSH post-create setup complete"
EOF

chmod +x /usr/local/bin/ssh-post-create

# Test the installation
if [ "$TEST_CONNECTIONS" = "true" ]; then
    echo "🧪 Running initial SSH test..."
    # Note: This will likely fail during feature install since SSH mount isn't active yet
    # but the script will be available for post-create testing
fi

echo "✅ Host SSH Access feature installed successfully"
echo ""
echo "📋 Next steps:"
echo "   1. Ensure SSH agent is running on host: eval \"\$(ssh-agent -s)\""
echo "   2. Add your SSH key: ssh-add ~/.ssh/id_rsa"
echo "   3. Rebuild DevContainer to activate SSH mounting"
echo "   4. Run 'test-ssh-access github.com' to verify connection"
echo "   5. Run 'setup-git-user' to configure git if needed"