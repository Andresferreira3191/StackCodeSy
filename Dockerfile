# ============================================================================
# StackCodeSy - Build from code-server source
# ============================================================================

# Build stage
FROM node:22-bookworm AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    gcc \
    make \
    python3 \
    python3-pip \
    pkg-config \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    libkrb5-dev \
    git \
    jq \
    rsync \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone code-server source with submodules
RUN echo "Cloning code-server with VSCode submodule..." && \
    git clone --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/coder/code-server.git . && \
    echo "✅ code-server and VSCode cloned"

# ============================================================================
# Apply StackCodeSy branding to VSCode product.json
# ============================================================================
RUN echo "Applying StackCodeSy branding to VSCode..." && \
    cd lib/vscode && \
    cp product.json product.json.original && \
    jq '. + {"nameShort": "StackCodeSy", "nameLong": "StackCodeSy Editor", "applicationName": "stackcodesy", "dataFolderName": ".stackcodesy", "win32MutexName": "stackcodesy", "win32DirName": "StackCodeSy", "win32NameVersion": "StackCodeSy", "win32AppUserModelId": "stackcodesy.stackcodesy", "win32ShellNameShort": "StackCodeSy", "darwinBundleIdentifier": "com.stackcodesy.editor", "linuxIconName": "stackcodesy", "licenseUrl": "https://github.com/yourorg/stackcodesy/blob/main/LICENSE", "reportIssueUrl": "https://github.com/yourorg/stackcodesy/issues", "documentationUrl": "https://docs.stackcodesy.com"}' product.json.original > product.json && \
    cd ../.. && \
    echo "✅ StackCodeSy branding applied to VSCode product.json"

# Apply StackCodeSy branding to code-server package.json
RUN echo "Applying StackCodeSy branding to code-server..." && \
    jq '.name = "stackcodesy" | .description = "StackCodeSy - Secure Code Editor" | .homepage = "https://github.com/yourorg/stackcodesy"' package.json > package.json.tmp && \
    mv package.json.tmp package.json && \
    echo "✅ StackCodeSy branding applied to code-server package.json"

# Install dependencies
RUN echo "Installing dependencies..." && \
    npm ci && \
    echo "✅ Dependencies installed"

# Build VSCode (this takes 30-40 minutes)
ENV VERSION=0.0.0
RUN echo "Building VSCode with StackCodeSy branding..." && \
    npm run build:vscode && \
    echo "✅ VSCode built successfully"

# Build code-server
RUN echo "Building code-server..." && \
    npm run build && \
    echo "✅ code-server built successfully"

# Create release bundle
RUN echo "Creating release bundle..." && \
    npm run release && \
    echo "✅ Release bundle created" && \
    ls -lah release/

# ============================================================================
# Runtime stage
# ============================================================================
FROM debian:12-slim AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    dumb-init \
    git \
    git-lfs \
    htop \
    locales \
    man-db \
    nano \
    openssh-client \
    procps \
    sudo \
    vim \
    wget \
    zsh \
    ca-certificates \
    jq \
    inotify-tools \
    net-tools \
    && git lfs install \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Setup locale
RUN sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8

# Create coder user (handle existing UID 1000)
RUN if id -u 1000 >/dev/null 2>&1; then \
        existing_user=$(id -un 1000); \
        if [ "$existing_user" != "coder" ]; then \
            userdel -r "$existing_user" 2>/dev/null || true; \
        fi; \
    fi && \
    adduser --gecos '' --disabled-password coder --uid 1000 && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Install fixuid for UID/GID mapping
RUN ARCH="$(dpkg --print-architecture)" && \
    curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-$ARCH.tar.gz" | tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: coder\ngroup: coder\n" > /etc/fixuid/config.yml

# Copy built code-server release from builder
COPY --from=builder --chown=coder:coder /build/release /usr/lib/code-server

# Install code-server release
RUN cd /usr/lib/code-server && \
    npm install --omit=dev && \
    ln -s /usr/lib/code-server/out/node/entry.js /usr/bin/code-server && \
    chmod +x /usr/bin/code-server && \
    chmod +x /usr/lib/code-server/out/node/entry.js

# ============================================================================
# Install StackCodeSy security layers
# ============================================================================
RUN mkdir -p \
    /opt/stackcodesy/security \
    /opt/stackcodesy/extensions \
    /var/log/stackcodesy \
    /workspace && \
    chown -R coder:coder /opt/stackcodesy /var/log/stackcodesy /workspace

# Copy security scripts
COPY --chown=coder:coder resources/server/web/security/*.sh /opt/stackcodesy/security/
RUN chmod +x /opt/stackcodesy/security/*.sh

# Copy custom extensions (if any)
COPY --chown=coder:coder extensions/ /opt/stackcodesy/extensions/

# ============================================================================
# Create StackCodeSy configuration
# ============================================================================
RUN mkdir -p /etc/stackcodesy
COPY <<EOF /etc/stackcodesy/config.json
{
  "product": {
    "nameShort": "StackCodeSy",
    "nameLong": "StackCodeSy Editor",
    "applicationName": "stackcodesy",
    "dataFolderName": ".stackcodesy",
    "version": "1.0.0"
  }
}
EOF

# ============================================================================
# Create StackCodeSy entrypoint
# ============================================================================
COPY <<'ENTRYPOINT' /usr/bin/stackcodesy-entrypoint.sh
#!/bin/bash
set -e

echo "============================================"
echo "  StackCodeSy - Secure Code Editor"
echo "  Version: 1.0.0"
echo "============================================"
echo ""

# Load configuration
export STACKCODESY_TERMINAL_MODE="${STACKCODESY_TERMINAL_MODE:-full}"
export STACKCODESY_EXTENSION_MODE="${STACKCODESY_EXTENSION_MODE:-full}"
export STACKCODESY_DISK_QUOTA_MB="${STACKCODESY_DISK_QUOTA_MB:-0}"
export STACKCODESY_ENABLE_AUDIT_LOG="${STACKCODESY_ENABLE_AUDIT_LOG:-true}"

echo "Configuration:"
echo "  Terminal Mode: $STACKCODESY_TERMINAL_MODE"
echo "  Extension Mode: $STACKCODESY_EXTENSION_MODE"
echo "  Audit Log: $STACKCODESY_ENABLE_AUDIT_LOG"
echo ""

# Apply security layers
if [ -d "/opt/stackcodesy/security" ]; then
    echo "Applying security layers..."

    for script in /opt/stackcodesy/security/*.sh; do
        if [ -f "$script" ]; then
            echo "  → $(basename $script)"
            bash "$script" || true
        fi
    done

    echo "✅ Security layers applied"
    echo ""
fi

# Start code-server
echo "Starting StackCodeSy Editor..."
echo "Access at: http://localhost:${PORT:-8080}"
echo ""

exec /usr/bin/dumb-init fixuid -q /usr/bin/code-server \
    --bind-addr "0.0.0.0:${PORT:-8080}" \
    --user-data-dir "/home/coder/.stackcodesy" \
    --disable-telemetry \
    "${@}"
ENTRYPOINT

RUN chmod +x /usr/bin/stackcodesy-entrypoint.sh

# ============================================================================
# User settings
# ============================================================================
USER coder
WORKDIR /home/coder

RUN mkdir -p /home/coder/.stackcodesy/User

# Add custom VSCode settings
COPY <<EOF /home/coder/.stackcodesy/User/settings.json
{
  "workbench.colorTheme": "Default Dark+",
  "workbench.startupEditor": "readme",
  "workbench.welcomePage.walkthroughs.openOnInstall": false,
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "extensions.autoUpdate": false,
  "window.menuBarVisibility": "toggle",
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  "editor.detectIndentation": true,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true
}
EOF

# ============================================================================
# Environment
# ============================================================================
ENV STACKCODESY_VERSION="1.0.0"
ENV STACKCODESY_WORKSPACE_DIR="/workspace"
ENV PORT="8080"

# Allow container startup scripts
ENV ENTRYPOINTD=/home/coder/entrypoint.d

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/usr/bin/stackcodesy-entrypoint.sh"]
CMD ["/workspace"]
