#!/bin/bash
# StackCodeSy Security Entrypoint
# Orchestrates all security systems before starting VSCode server

set -e

echo "=================================================="
echo "  StackCodeSy - Secure VSCode Web Editor"
echo "  Version: 1.0.0"
echo "  Starting initialization..."
echo "=================================================="
echo ""

SECURITY_DIR="/opt/stackcodesy/security"
LOG_DIR="/var/log/stackcodesy"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Display configuration
echo "Current Configuration:"
echo "  User ID: ${STACKCODESY_USER_ID:-not set}"
echo "  User Email: ${STACKCODESY_USER_EMAIL:-not set}"
echo "  Terminal Mode: ${STACKCODESY_TERMINAL_MODE:-full}"
echo "  Extension Mode: ${STACKCODESY_EXTENSION_MODE:-full}"
echo "  Disk Quota: ${STACKCODESY_DISK_QUOTA_MB:-unlimited} MB"
echo "  Egress Filter: ${STACKCODESY_EGRESS_FILTER:-false}"
echo "  Audit Logging: ${STACKCODESY_ENABLE_AUDIT_LOG:-true}"
echo ""

# 1. TERMINAL SECURITY
echo "Step 1/6: Configuring terminal security..."
if [ -f "$SECURITY_DIR/terminal-security.sh" ]; then
    bash "$SECURITY_DIR/terminal-security.sh"
    log_step "Terminal security configured (Mode: ${STACKCODESY_TERMINAL_MODE:-full})"
else
    log_warn "Terminal security script not found, skipping"
fi
echo ""

# 2. EXTENSION MARKETPLACE SECURITY
echo "Step 2/6: Configuring extension marketplace..."
if [ -f "$SECURITY_DIR/extension-marketplace.sh" ]; then
    bash "$SECURITY_DIR/extension-marketplace.sh"
    log_step "Extension marketplace configured (Mode: ${STACKCODESY_EXTENSION_MODE:-full})"
else
    log_warn "Extension marketplace script not found, skipping"
fi
echo ""

# 3. FILESYSTEM SECURITY
echo "Step 3/6: Configuring filesystem security..."
if [ -f "$SECURITY_DIR/filesystem-security.sh" ]; then
    bash "$SECURITY_DIR/filesystem-security.sh"
    log_step "Filesystem security configured"
else
    log_warn "Filesystem security script not found, skipping"
fi
echo ""

# 4. NETWORK SECURITY
echo "Step 4/6: Configuring network security..."
if [ -f "$SECURITY_DIR/network-security.sh" ]; then
    bash "$SECURITY_DIR/network-security.sh"
    log_step "Network security configured"
else
    log_warn "Network security script not found, skipping"
fi
echo ""

# 5. AUDIT LOGGING
echo "Step 5/6: Initializing audit logging..."
if [ -f "$SECURITY_DIR/audit-log.sh" ]; then
    bash "$SECURITY_DIR/audit-log.sh"
    log_step "Audit logging initialized"
else
    log_warn "Audit logging script not found, skipping"
fi
echo ""

# 6. CONTENT SECURITY POLICY
echo "Step 6/6: Configuring Content Security Policy..."
if [ -f "$SECURITY_DIR/csp-config.sh" ]; then
    bash "$SECURITY_DIR/csp-config.sh"
    log_step "CSP configured"
else
    log_warn "CSP configuration script not found, skipping"
fi
echo ""

# Create stackcodesy user if doesn't exist
if ! id -u stackcodesy > /dev/null 2>&1; then
    echo "Creating stackcodesy user..."
    useradd -m -s /bin/bash stackcodesy
    log_step "User 'stackcodesy' created"
fi

# Ensure proper ownership
WORKSPACE_DIR="${STACKCODESY_WORKSPACE_DIR:-/workspace}"
mkdir -p "$WORKSPACE_DIR"
chown -R stackcodesy:stackcodesy "$WORKSPACE_DIR"
chown -R stackcodesy:stackcodesy /home/stackcodesy

log_step "Workspace permissions configured"

echo ""
echo "=================================================="
echo "  Security initialization completed successfully"
echo "=================================================="
echo ""

# Authentication check
if [ "${STACKCODESY_REQUIRE_AUTH:-true}" = "true" ]; then
    if [ -z "$STACKCODESY_AUTH_TOKEN" ] && [ -z "$STACKCODESY_USER_ID" ]; then
        log_error "Authentication required but no token/user provided"
        log_error "Set STACKCODESY_AUTH_TOKEN or STACKCODESY_USER_ID environment variable"
        exit 1
    fi
    log_step "Authentication validated"
fi

# Start VSCode Server
echo "Starting VSCode Web Server..."
echo "  Host: ${HOST:-0.0.0.0}"
echo "  Port: ${PORT:-8080}"
echo ""

# Switch to stackcodesy user and start server
cd "$WORKSPACE_DIR"

# Check if we have VSCode server
if [ -f "/opt/vscode-server/start-server.sh" ]; then
    log_step "Using VSCode Server (official)"
    exec su stackcodesy -c "/opt/vscode-server/start-server.sh"
elif [ -f "/opt/vscode-server/bin/code-server" ]; then
    log_step "Using VSCode Server binary directly"
    exec su stackcodesy -c "/opt/vscode-server/bin/code-server --host ${HOST:-0.0.0.0} --port ${PORT:-8080} --without-connection-token ${WORKSPACE_DIR}"
else
    log_error "No VSCode server found!"
    log_error "Expected server at /opt/vscode-server/"
    exit 1
fi
