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

# Handle existing vscode user/group
if id -u vscode >/dev/null 2>&1; then
    echo "Removing existing vscode user..."
    userdel -r vscode 2>/dev/null || true
fi

if getent group vscode >/dev/null 2>&1; then
    echo "Removing existing vscode group..."
    groupdel vscode 2>/dev/null || true
fi

# Ensure joe user exists with correct UID/GID
if ! id -u joe >/dev/null 2>&1; then
    echo "Creating joe user with UID/GID 1000..."
    groupadd -g 1000 joe
    useradd -u 1000 -g 1000 -m -s /bin/bash joe
    usermod -aG sudo joe
    echo "joe ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/joe
fi

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
        zsh
fi

# NOTE: User directory setup moved to postCreateCommand since user doesn't exist during feature installation

# Install project setup script globally
cat << 'EOF' > /usr/local/bin/setup-project-dependencies
#!/usr/bin/env bash
# setup-project-dependencies
# Automated project dependency setup (replaces complex monorepo detection)

set -e

echo "🚀 Setting up project dependencies..."

# Ensure Poetry is in PATH
export PATH="/home/joe/.local/bin:$PATH"

# Poetry setup (if pyproject.toml exists)
if [ -f "pyproject.toml" ]; then
    echo "🐍 Setting up Poetry project..."
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

chmod +x /usr/local/bin/setup-project-dependencies

echo "✅ Codemian Standards installed successfully"