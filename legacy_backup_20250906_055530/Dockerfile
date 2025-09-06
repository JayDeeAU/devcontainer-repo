# CoDemian Dev Container Dockerfile

# Use the official Microsoft Python dev container image as a base
ARG VARIANT="3.12-bookworm"
FROM mcr.microsoft.com/vscode/devcontainers/python:${VARIANT}

# Prevent Python from writing pyc files and enable unbuffered mode
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install Node.js and pnpm
ARG NODE_VERSION="22"
RUN if [ "${NODE_VERSION}" != "none" ]; then \
    # Install Node.js using nvm
    su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1" && \
    # Install pnpm globally
    npm install -g pnpm \
    ; fi

# Install additional OS packages and tools
RUN apt-get update && apt-get upgrade -y && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y --no-install-recommends \
        # Install sudo for privilege escalation
        sudo \
        # Install curl for downloading files and making HTTP requests
        curl \
        # Install apt-utils for better apt functionality
        apt-utils \
        # Install software-properties-common for adding repositories
        software-properties-common \
        # Install build-essential for compiling software
        build-essential \
        # Install wget as an alternative to curl
        wget \
        # Install git for version control
        git \
        # Install libssl-dev and openssl for SSL support
        libssl-dev \
        openssl \
        # Install fontconfig for font management
        fontconfig \
        # Install procps for process utilities like ps, top
        procps \
        # Install poppler-utils for PDF utilities
        poppler-utils \
        # Install lsb-release for LSB information
        lsb-release && \
    # Install Docker
    curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz | \
    tar zxvf - --strip 1 -C /usr/local/bin docker/docker && \
    chmod +x /usr/local/bin/docker &&\
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    # Upgrade pip
    python -m pip install --upgrade pip && \
    # Install Poetry
    curl -sSL https://install.python-poetry.org | python3 - && \
    # Add Poetry to PATH
    echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc && \
    export PATH="/root/.local/bin:$PATH" && \
    # Configure Poetry to create virtual environments in the project directory by default
    poetry config virtualenvs.in-project true

# Install Microsoft TrueType Core Fonts
RUN echo "deb http://ftp.debian.org/debian/ bookworm contrib" >> /etc/apt/sources.list && \
    apt-get update && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get install -y ttf-mscorefonts-installer

# Install Google Fonts
RUN mkdir -p /usr/share/fonts/googlefonts && \
    wget https://github.com/google/fonts/archive/main.tar.gz -O gfonts.tar.gz && \
    tar -xf gfonts.tar.gz && \
    find fonts-main/ -name "*.ttf" -exec install -m644 {} /usr/share/fonts/googlefonts/ \; && \
    rm -rf fonts-main gfonts.tar.gz && \
    fc-cache -f -v

# Set up non-root user
ARG USERNAME=joe
ARG USER_UID=1000
ARG USER_GID=1000

# Modify existing vscode user
RUN usermod -l $USERNAME vscode && \
    usermod -d /home/$USERNAME -m $USERNAME && \
    groupmod -n $USERNAME vscode && \
    echo $USERNAME:Gundev!23 | chpasswd && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Add user to docker group and sudo group
RUN groupadd docker || true && \
    usermod -aG sudo $USERNAME && \
    usermod -aG docker $USERNAME

# Ensure the user owns their home directory
RUN chown -R $USERNAME:$USERNAME /home/$USERNAME

# Copy update_dependencies script
COPY update_dependencies.sh /home/$USERNAME/update_dependencies.sh
RUN chmod +x /home/$USERNAME/update_dependencies.sh && mkdir -p /docker && \
    chown $USERNAME:$USERNAME /docker

RUN apt update && \
    apt install -y ca-certificates curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc
RUN echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "noble") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt update && \
    apt install -y docker-ce-cli

# Switch to non-root user
USER $USERNAME

RUN curl -sSL https://install.python-poetry.org | python3 - && \
    echo 'export PATH="/home/'$USERNAME'/.local/bin:$PATH"' >> /home/$USERNAME/.bashrc && \
    echo 'adding poetry path: export PATH="/home/'$USERNAME'/.local/bin:$PATH"' && \
    export PATH="/home/'$USERNAME'/.local/bin:$PATH" && \
    # Configure Poetry to create virtual environments in the project directory by default
    /home/$USERNAME/.local/bin/poetry config virtualenvs.in-project true

# Set the default shell to bash
ENV SHELL=/bin/bash

CMD ["/bin/bash"]