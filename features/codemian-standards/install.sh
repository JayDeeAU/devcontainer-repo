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
    apt-utils \
    fontconfig

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

# Create Python symlinks to match host paths for shared venv compatibility
# Host uses /usr/bin/pythonX.Y (apt), container has /usr/local/bin (devcontainer image)
# This allows a single .venv to work in both environments
echo "Creating Python symlinks for host/container venv compatibility..."
for py in /usr/local/bin/python3.*; do
    # Skip config files
    [[ "$py" == *-config ]] && continue
    [[ ! -x "$py" ]] && continue

    pyname=$(basename "$py")
    if [ ! -e "/usr/bin/$pyname" ]; then
        ln -sf "$py" "/usr/bin/$pyname"
        echo "  Linked /usr/bin/$pyname -> $py"
    fi
done

echo "✅ Codemian Standards installed successfully"