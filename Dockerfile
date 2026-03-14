FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

# Create container user matching host user (resolved via build.args from ${localEnv:USER})
# Features detect this user by UID 1000 — the username string matches the host for SSH/UX.
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=100

# Remove base image's default non-root user if it conflicts with our UID
RUN if getent passwd ${USER_UID} >/dev/null 2>&1; then \
        EXISTING=$(getent passwd ${USER_UID} | cut -d: -f1); \
        if [ "$EXISTING" != "${USERNAME}" ]; then \
            userdel -r "$EXISTING" 2>/dev/null || true; \
        fi; \
    fi \
    && getent group ${USER_GID} >/dev/null || groupadd -g ${USER_GID} users \
    && if ! id -u "${USERNAME}" >/dev/null 2>&1; then \
        useradd -u ${USER_UID} -g ${USER_GID} -m -s /bin/bash "${USERNAME}"; \
    fi \
    && usermod -aG sudo "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"${USERNAME}"
