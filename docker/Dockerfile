# StackCodeSy - Secure VSCode Web Editor
# Multi-stage Dockerfile for production deployment

# ============================================================================
# Stage 1: Runtime Environment
# ============================================================================
FROM node:20-bookworm-slim AS runtime

LABEL maintainer="StackCodeSy Team"
LABEL description="Secure VSCode Web Editor with custom authentication and security controls"
LABEL version="1.0.0"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    git \
    # Security tools
    inotify-tools \
    iptables \
    net-tools \
    # Process management
    supervisor \
    # Text editors (for restricted terminal)
    nano \
    vim \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create stackcodesy user
RUN useradd -m -u 1000 -s /bin/bash stackcodesy \
    && mkdir -p /workspace /var/log/stackcodesy /opt/stackcodesy \
    && chown -R stackcodesy:stackcodesy /workspace /var/log/stackcodesy /opt/stackcodesy

# Create directory structure
RUN mkdir -p \
    /opt/stackcodesy/vscode-reh-web \
    /opt/stackcodesy/security \
    /opt/stackcodesy/extensions \
    /home/stackcodesy/.stackcodesy

# Copy security scripts
COPY resources/server/web/security/*.sh /opt/stackcodesy/security/
RUN chmod +x /opt/stackcodesy/security/*.sh

# Copy VSCode server binaries (from GitHub Actions artifacts or pre-compiled)
# These will be available as build artifacts from the CI/CD pipeline
# For local development, you need to build vscode-reh-web first
COPY --chown=stackcodesy:stackcodesy vscode-reh-web-*.tar.gz /tmp/ 2>/dev/null || true

# Extract vscode-reh-web if tarball exists
RUN if [ -f /tmp/vscode-reh-web-*.tar.gz ]; then \
        tar -xzf /tmp/vscode-reh-web-*.tar.gz -C /opt/stackcodesy/ && \
        mv /opt/stackcodesy/vscode-reh-web-* /opt/stackcodesy/vscode-reh-web && \
        rm /tmp/vscode-reh-web-*.tar.gz; \
    else \
        echo "WARNING: vscode-reh-web tarball not found. Server will not start."; \
        echo "Build vscode-reh-web using GitHub Actions or run build-vscode-web.sh locally"; \
    fi

# Copy custom extensions
COPY --chown=stackcodesy:stackcodesy extensions/ /opt/stackcodesy/extensions/ 2>/dev/null || true

# Environment variables with defaults
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

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Set working directory
WORKDIR /workspace

# Use security entrypoint
ENTRYPOINT ["/opt/stackcodesy/security/entrypoint.sh"]
