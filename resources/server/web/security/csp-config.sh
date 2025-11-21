#!/bin/bash
# StackCodeSy Content Security Policy Configuration
# Sets HTTP security headers for the web application

set -e

LOG_FILE="/tmp/stackcodesy-csp-config.log"
ENABLE_CSP="${STACKCODESY_ENABLE_CSP:-true}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Configuring Content Security Policy..."

if [ "$ENABLE_CSP" != "true" ]; then
    log "CSP: DISABLED"
    exit 0
fi

# Create CSP header configuration
CSP_HEADER="default-src 'self'; "
CSP_HEADER+="script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:; "
CSP_HEADER+="style-src 'self' 'unsafe-inline' blob:; "
CSP_HEADER+="img-src 'self' data: https: blob:; "
CSP_HEADER+="font-src 'self' data: blob:; "
CSP_HEADER+="connect-src 'self' wss: https: blob:; "
CSP_HEADER+="worker-src 'self' blob:; "
CSP_HEADER+="frame-src 'self' https:; "
CSP_HEADER+="frame-ancestors 'none'; "
CSP_HEADER+="base-uri 'self'; "
CSP_HEADER+="form-action 'self';"

# Export for use by web server
export STACKCODESY_CSP_HEADER="$CSP_HEADER"

# Create nginx config snippet if nginx is being used
if command -v nginx &> /dev/null; then
    mkdir -p /etc/nginx/snippets

    cat > /etc/nginx/snippets/stackcodesy-security-headers.conf << EOF
# StackCodeSy Security Headers

# Content Security Policy
add_header Content-Security-Policy "$CSP_HEADER" always;

# Prevent clickjacking
add_header X-Frame-Options "DENY" always;

# Prevent MIME type sniffing
add_header X-Content-Type-Options "nosniff" always;

# XSS Protection (legacy browsers)
add_header X-XSS-Protection "1; mode=block" always;

# Referrer Policy
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Permissions Policy (formerly Feature Policy)
add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()" always;

# HSTS (HTTP Strict Transport Security)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Remove server identification
server_tokens off;
EOF

    log "Nginx security headers configuration created at /etc/nginx/snippets/stackcodesy-security-headers.conf"
    log "Include this in your nginx server block with: include /etc/nginx/snippets/stackcodesy-security-headers.conf;"
fi

# Create Apache config snippet if Apache is being used
if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
    mkdir -p /etc/apache2/conf-available

    cat > /etc/apache2/conf-available/stackcodesy-security-headers.conf << EOF
# StackCodeSy Security Headers

# Content Security Policy
Header always set Content-Security-Policy "$CSP_HEADER"

# Prevent clickjacking
Header always set X-Frame-Options "DENY"

# Prevent MIME type sniffing
Header always set X-Content-Type-Options "nosniff"

# XSS Protection
Header always set X-XSS-Protection "1; mode=block"

# Referrer Policy
Header always set Referrer-Policy "strict-origin-when-cross-origin"

# Permissions Policy
Header always set Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=()"

# HSTS
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

# Remove server signature
ServerSignature Off
ServerTokens Prod
EOF

    log "Apache security headers configuration created at /etc/apache2/conf-available/stackcodesy-security-headers.conf"
    log "Enable with: a2enconf stackcodesy-security-headers"
fi

# Create standalone CSP header file for Node.js/Express integration
cat > /tmp/stackcodesy-csp-headers.json << EOF
{
  "Content-Security-Policy": "$CSP_HEADER",
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "X-XSS-Protection": "1; mode=block",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "geolocation=(), microphone=(), camera=(), payment=(), usb=()",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains; preload"
}
EOF

log "CSP headers exported to /tmp/stackcodesy-csp-headers.json"

# Summary
log "Content Security Policy configured successfully"
log "CSP Header: $CSP_HEADER"

# Additional security recommendations
log ""
log "Security Recommendations:"
log "1. Always use HTTPS in production"
log "2. Implement rate limiting at reverse proxy level"
log "3. Use fail2ban for brute force protection"
log "4. Keep base images and dependencies updated"
log "5. Regularly scan for vulnerabilities"

log "CSP configuration completed"
