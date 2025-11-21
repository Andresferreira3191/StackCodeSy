# StackCodeSy - Secure VSCode Web Editor
# Downloads official VSCode server and applies StackCodeSy customizations

FROM node:20-bookworm-slim AS base

# ============================================================================
# Build arguments
# ============================================================================
ARG VSCODE_VERSION=1.95.3
ARG VSCODE_QUALITY=stable

# ============================================================================
# Install runtime and build dependencies
# ============================================================================
RUN apt-get update && apt-get install -y \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    # Security tools
    inotify-tools \
    iptables \
    net-tools \
    # Process management
    supervisor \
    # Text editors
    nano \
    vim \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ============================================================================
# Download official VSCode server
# ============================================================================
WORKDIR /tmp

RUN echo "Downloading VSCode Server ${VSCODE_VERSION}..." && \
    DOWNLOAD_URL="https://update.code.visualstudio.com/${VSCODE_VERSION}/server-linux-x64/${VSCODE_QUALITY}" && \
    echo "URL: ${DOWNLOAD_URL}" && \
    curl -fsSL "${DOWNLOAD_URL}" -o vscode-server.tar.gz && \
    echo "Download completed: $(ls -lh vscode-server.tar.gz | awk '{print $5}')" && \
    \
    echo "Extracting..." && \
    mkdir -p /opt/vscode-server && \
    tar -xzf vscode-server.tar.gz -C /opt/vscode-server --strip-components=1 && \
    rm vscode-server.tar.gz && \
    \
    echo "VSCode Server installed successfully" && \
    ls -lah /opt/vscode-server/

# ============================================================================
# Apply StackCodeSy branding and customizations
# ============================================================================
WORKDIR /opt/vscode-server

# Modify product.json for branding
RUN if [ -f product.json ]; then \
        echo "Applying StackCodeSy branding to product.json..." && \
        cp product.json product.json.original && \
        jq '. + {
            "nameShort": "StackCodeSy",
            "nameLong": "StackCodeSy Editor",
            "applicationName": "stackcodesy",
            "dataFolderName": ".stackcodesy",
            "serverDataFolderName": ".stackcodesy-server",
            "quality": "stable",
            "extensionsGallery": {
                "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
                "itemUrl": "https://marketplace.visualstudio.com/items",
                "controlUrl": "",
                "recommendationsUrl": ""
            }
        }' product.json > product.json.tmp && \
        mv product.json.tmp product.json && \
        echo "Branding applied successfully"; \
    else \
        echo "Warning: product.json not found, skipping branding"; \
    fi

# Create custom welcome/getting started content
RUN mkdir -p /opt/vscode-server/resources/app/out/vs/code/browser/workbench && \
    cat > /opt/vscode-server/welcome.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Welcome to StackCodeSy</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #1e1e1e;
            color: #cccccc;
        }
        h1 { color: #4ec9b0; }
        h2 { color: #569cd6; }
        .feature {
            margin: 20px 0;
            padding: 15px;
            background: #252526;
            border-left: 3px solid #007acc;
        }
        code {
            background: #1e1e1e;
            padding: 2px 6px;
            border-radius: 3px;
            color: #ce9178;
        }
    </style>
</head>
<body>
    <h1>🚀 Welcome to StackCodeSy</h1>
    <p>Your secure, enterprise-grade code editor in the cloud.</p>

    <div class="feature">
        <h2>🔒 Security First</h2>
        <p>Multi-layer security with terminal controls, extension restrictions, and full audit logging.</p>
    </div>

    <div class="feature">
        <h2>🌐 Web-Based</h2>
        <p>Access your development environment from anywhere, on any device.</p>
    </div>

    <div class="feature">
        <h2>⚡ Full VSCode Power</h2>
        <p>All the features you love from VSCode, running securely in your browser.</p>
    </div>

    <hr style="border-color: #3e3e42; margin: 30px 0;">
    <p style="text-align: center; color: #858585;">
        Powered by VSCode | Secured by StackCodeSy
    </p>
</body>
</html>
EOF

# ============================================================================
# Create stackcodesy user and directories
# ============================================================================
RUN useradd -m -u 1000 -s /bin/bash stackcodesy && \
    mkdir -p /workspace /var/log/stackcodesy /opt/stackcodesy && \
    chown -R stackcodesy:stackcodesy /workspace /var/log/stackcodesy /opt/stackcodesy /opt/vscode-server

# ============================================================================
# Copy StackCodeSy security scripts and extensions
# ============================================================================
COPY --chown=stackcodesy:stackcodesy resources/server/web/security/*.sh /opt/stackcodesy/security/
RUN chmod +x /opt/stackcodesy/security/*.sh

COPY --chown=stackcodesy:stackcodesy extensions/ /opt/stackcodesy/extensions/

# ============================================================================
# Build custom authentication extension
# ============================================================================
WORKDIR /opt/stackcodesy/extensions/stackcodesy-auth

RUN if [ -f package.json ]; then \
        echo "Building stackcodesy-auth extension..." && \
        npm install --production && \
        npm run compile && \
        echo "Extension built successfully"; \
    else \
        echo "Warning: stackcodesy-auth extension not found"; \
    fi

# ============================================================================
# Create server startup script
# ============================================================================
RUN cat > /opt/vscode-server/start-server.sh << 'EOF'
#!/bin/bash
set -e

echo "=================================================="
echo "  Starting StackCodeSy Server"
echo "=================================================="

# Server configuration
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
WORKSPACE="${STACKCODESY_WORKSPACE_DIR:-/workspace}"

# Server arguments
ARGS=(
    --host "$HOST"
    --port "$PORT"
    --without-connection-token
    --disable-telemetry
)

# Add custom extensions path if exists
if [ -d "/opt/stackcodesy/extensions" ]; then
    ARGS+=(--extensions-dir /opt/stackcodesy/extensions)
fi

# User data directory
USER_DATA_DIR="/home/stackcodesy/.stackcodesy-server"
mkdir -p "$USER_DATA_DIR"
ARGS+=(--user-data-dir "$USER_DATA_DIR")

echo "Configuration:"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Workspace: $WORKSPACE"
echo "  User: $(whoami)"
echo ""

# Start server
echo "Starting VSCode Server..."
exec /opt/vscode-server/bin/code-server "${ARGS[@]}" "$WORKSPACE"
EOF

RUN chmod +x /opt/vscode-server/start-server.sh && \
    chown stackcodesy:stackcodesy /opt/vscode-server/start-server.sh

# ============================================================================
# Environment variables with defaults
# ============================================================================
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

# ============================================================================
# Expose port
# ============================================================================
EXPOSE 8080

# ============================================================================
# Health check
# ============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# ============================================================================
# Set working directory
# ============================================================================
WORKDIR /workspace

# ============================================================================
# Use security entrypoint
# ============================================================================
ENTRYPOINT ["/opt/stackcodesy/security/entrypoint.sh"]
