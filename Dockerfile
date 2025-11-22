# StackCodeSy - Build VSCode from source with full customization
# This compiles VSCode from scratch with StackCodeSy branding

FROM node:20-bookworm AS builder

# ============================================================================
# Build arguments
# ============================================================================
ARG VSCODE_VERSION=1.95.3

# ============================================================================
# Install build dependencies
# ============================================================================
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
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# Clone VSCode source
# ============================================================================
WORKDIR /build

RUN echo "Cloning VSCode ${VSCODE_VERSION}..." && \
    git clone --depth 1 --branch ${VSCODE_VERSION} \
    https://github.com/microsoft/vscode.git vscode && \
    cd vscode && \
    echo "VSCode cloned successfully" && \
    git log -1 --oneline

WORKDIR /build/vscode

# ============================================================================
# Apply StackCodeSy branding BEFORE compilation
# ============================================================================
RUN echo "Applying StackCodeSy branding..." && \
    # Backup original
    cp product.json product.json.original && \
    # Apply branding (single line to avoid parsing issues)
    jq '. + {"nameShort": "StackCodeSy", "nameLong": "StackCodeSy Editor", "applicationName": "stackcodesy", "dataFolderName": ".stackcodesy", "serverDataFolderName": ".stackcodesy-server", "darwinBundleIdentifier": "com.stackcodesy.editor", "linuxIconName": "stackcodesy", "reportIssueUrl": "https://github.com/yourorg/stackcodesy/issues", "documentationUrl": "https://docs.stackcodesy.com", "requestFeatureUrl": "https://github.com/yourorg/stackcodesy/issues/new"}' product.json > product.json.tmp && \
    mv product.json.tmp product.json && \
    echo "✅ Branding applied to product.json" && \
    # Also update package.json
    if [ -f package.json ]; then \
        jq '.displayName = "StackCodeSy" | .name = "stackcodesy" | .description = "StackCodeSy - Secure Code Editor"' package.json > package.json.tmp && \
        mv package.json.tmp package.json && \
        echo "✅ Branding applied to package.json"; \
    fi

# Create custom welcome content
RUN mkdir -p src/vs/workbench/contrib/welcome/page/browser && \
    cat > src/vs/workbench/contrib/welcome/page/browser/stackcodesy-welcome.ts << 'EOF'
/*---------------------------------------------------------------------------------------------
 *  StackCodeSy Custom Welcome Content
 *--------------------------------------------------------------------------------------------*/

export const stackcodesyWelcomeContent = `
# Welcome to StackCodeSy

Your secure, enterprise-grade code editor.

## Features
- 🔒 Multi-layer security
- 🌐 Web-based access
- 🔐 Custom authentication
- ⚡ Full VSCode power

Powered by VSCode | Secured by StackCodeSy
`;
EOF

# ============================================================================
# Install dependencies with C++20 support
# ============================================================================
# Set C++ standard to C++20 for native modules
ENV CXXFLAGS="-std=c++20"
ENV npm_config_cxx="/usr/bin/g++"

RUN echo "Installing dependencies..." && \
    npm ci && \
    echo "✅ Dependencies installed"

# ============================================================================
# Compile vscode-reh-web (Remote Extension Host for Web)
# ============================================================================
ENV NODE_OPTIONS="--max-old-space-size=8192"

RUN echo "Starting compilation of vscode-reh-web-linux-x64..." && \
    echo "This will take 30-50 minutes..." && \
    npm run gulp vscode-reh-web-linux-x64 && \
    echo "✅ Compilation completed successfully"

# Move build output to expected location
# VSCode outputs to ../vscode-reh-web-linux-x64 (parent of vscode repo)
RUN if [ -d "../vscode-reh-web-linux-x64" ]; then \
        echo "✅ Build found at /build/vscode-reh-web-linux-x64"; \
        echo "Size: $(du -sh ../vscode-reh-web-linux-x64 | cut -f1)"; \
        ls -lah ../vscode-reh-web-linux-x64/; \
    else \
        echo "❌ ERROR: Build directory not found at ../vscode-reh-web-linux-x64"; \
        echo "Contents of parent directory:"; \
        ls -lah ../; \
        exit 1; \
    fi

# ============================================================================
# Stage 2: Runtime
# ============================================================================
FROM node:20-bookworm-slim AS runtime

LABEL maintainer="StackCodeSy Team"
LABEL description="StackCodeSy - Secure VSCode Web Editor (compiled from source)"
LABEL version="1.0.0"

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    inotify-tools \
    iptables \
    net-tools \
    supervisor \
    nano \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create stackcodesy user (handle if UID 1000 already exists)
RUN if id -u 1000 >/dev/null 2>&1; then \
        # User with UID 1000 exists (likely 'node'), rename it
        existing_user=$(id -un 1000); \
        if [ "$existing_user" != "stackcodesy" ]; then \
            usermod -l stackcodesy $existing_user; \
            groupmod -n stackcodesy $(id -gn 1000) 2>/dev/null || true; \
        fi; \
    else \
        # Create new user
        useradd -m -u 1000 -s /bin/bash stackcodesy; \
    fi && \
    mkdir -p /workspace /var/log/stackcodesy /opt/stackcodesy /opt/vscode-server && \
    chown -R stackcodesy:stackcodesy /workspace /var/log/stackcodesy /opt/stackcodesy /opt/vscode-server

# Copy compiled vscode-reh-web from builder
# Build output is at /build/vscode-reh-web-linux-x64 (parent of vscode repo)
COPY --from=builder --chown=stackcodesy:stackcodesy /build/vscode-reh-web-linux-x64 /opt/vscode-server

# Copy security scripts
COPY --chown=stackcodesy:stackcodesy resources/server/web/security/*.sh /opt/stackcodesy/security/
RUN chmod +x /opt/stackcodesy/security/*.sh

# Copy custom extensions
COPY --chown=stackcodesy:stackcodesy extensions/ /opt/stackcodesy/extensions/

# Build custom authentication extension
WORKDIR /opt/stackcodesy/extensions/stackcodesy-auth
RUN if [ -f package.json ]; then \
        echo "Building stackcodesy-auth extension..." && \
        npm install --production && \
        npm run compile && \
        echo "✅ Extension built successfully"; \
    fi

# Create server startup script
RUN cat > /opt/vscode-server/start-server.sh << 'EOF'
#!/bin/bash
set -e

echo "=================================================="
echo "  Starting StackCodeSy Server"
echo "  (Compiled from VSCode source with branding)"
echo "=================================================="

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
WORKSPACE="${STACKCODESY_WORKSPACE_DIR:-/workspace}"

ARGS=(
    --host "$HOST"
    --port "$PORT"
    --without-connection-token
    --disable-telemetry
)

if [ -d "/opt/stackcodesy/extensions" ]; then
    ARGS+=(--extensions-dir /opt/stackcodesy/extensions)
fi

USER_DATA_DIR="/home/stackcodesy/.stackcodesy-server"
mkdir -p "$USER_DATA_DIR"
ARGS+=(--user-data-dir "$USER_DATA_DIR")

echo "Configuration:"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Workspace: $WORKSPACE"
echo "  User: $(whoami)"
echo ""
echo "Starting StackCodeSy Server..."

exec /opt/vscode-server/bin/code-server "${ARGS[@]}" "$WORKSPACE"
EOF

RUN chmod +x /opt/vscode-server/start-server.sh && \
    chown stackcodesy:stackcodesy /opt/vscode-server/start-server.sh

# Environment variables
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=8080 \
    STACKCODESY_WORKSPACE_DIR=/workspace \
    STACKCODESY_REQUIRE_AUTH=true \
    STACKCODESY_TERMINAL_MODE=full \
    STACKCODESY_EXTENSION_MODE=full \
    STACKCODESY_DISK_QUOTA_MB=0 \
    STACKCODESY_EGRESS_FILTER=false \
    STACKCODESY_ENABLE_AUDIT_LOG=true \
    STACKCODESY_ENABLE_CSP=true

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

WORKDIR /workspace

ENTRYPOINT ["/opt/stackcodesy/security/entrypoint.sh"]
