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
