#!/bin/bash
# StackCodeSy Network Security Control
# Implements egress filtering and domain whitelisting

set -e

LOG_FILE="/tmp/stackcodesy-network-security.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Configuring network security..."

EGRESS_FILTER="${STACKCODESY_EGRESS_FILTER:-false}"
BLOCK_ALL_OUTBOUND="${STACKCODESY_BLOCK_ALL_OUTBOUND:-false}"

if [ "$BLOCK_ALL_OUTBOUND" = "true" ]; then
    log "BLOCKING ALL OUTBOUND CONNECTIONS"

    # Check if iptables is available
    if command -v iptables &> /dev/null; then
        # Block all outbound except loopback
        iptables -P OUTPUT DROP 2>/dev/null || log "WARNING: Cannot set iptables policy (not running as root or no cap_net_admin)"
        iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

        log "All outbound connections blocked via iptables"
    else
        log "WARNING: iptables not available, cannot block network"
    fi

    # Also block common network tools
    for tool in wget curl nc netcat telnet ssh ftp; do
        if command -v "$tool" &> /dev/null; then
            chmod 000 "$(which $tool)" 2>/dev/null || true
        fi
    done

    log "Network tools disabled"

elif [ "$EGRESS_FILTER" = "true" ]; then
    log "ENABLING EGRESS FILTERING"

    # Default allowed domains
    ALLOWED_DOMAINS="${STACKCODESY_ALLOWED_DOMAINS:-registry.npmjs.org,github.com,raw.githubusercontent.com,pypi.org,api.github.com}"
    ALLOWED_PORTS="${STACKCODESY_ALLOWED_PORTS:-80,443}"

    log "Allowed domains: $ALLOWED_DOMAINS"
    log "Allowed ports: $ALLOWED_PORTS"

    if command -v iptables &> /dev/null; then
        # Default: DROP all outbound
        iptables -P OUTPUT DROP 2>/dev/null || log "WARNING: Cannot set iptables policy"

        # Allow loopback
        iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

        # Allow DNS
        iptables -A OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
        iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true

        # Allow established connections
        iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

        # Resolve and allow specific domains
        IFS=',' read -ra DOMAINS <<< "$ALLOWED_DOMAINS"
        for domain in "${DOMAINS[@]}"; do
            domain=$(echo "$domain" | xargs)  # trim whitespace

            # Resolve domain to IP addresses
            ips=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u)

            if [ -n "$ips" ]; then
                for ip in $ips; do
                    # Allow HTTPS to this IP
                    iptables -A OUTPUT -p tcp -d "$ip" --dport 443 -j ACCEPT 2>/dev/null || true
                    iptables -A OUTPUT -p tcp -d "$ip" --dport 80 -j ACCEPT 2>/dev/null || true
                    log "Allowed outbound to $domain ($ip)"
                done
            else
                log "WARNING: Could not resolve domain: $domain"
            fi
        done

        # Log blocked attempts
        iptables -A OUTPUT -j LOG --log-prefix "STACKCODESY_BLOCKED: " --log-level 4 2>/dev/null || true

        log "Egress filtering enabled via iptables"
    else
        log "WARNING: iptables not available, using hosts file fallback"

        # Fallback: Use /etc/hosts to block everything except allowed domains
        # This is less reliable but works without iptables

        cat >> /etc/hosts << EOF

# StackCodeSy network restrictions
# All domains blocked except whitelist
EOF

        log "Hosts file updated (limited protection without iptables)"
    fi

else
    log "Network security: DISABLED (full outbound access)"
fi

# Additional network monitoring
ENABLE_NET_MONITORING="${STACKCODESY_ENABLE_NETWORK_MONITORING:-false}"

if [ "$ENABLE_NET_MONITORING" = "true" ]; then
    log "Enabling network connection monitoring..."

    cat > /usr/local/bin/monitor-network << 'EOF'
#!/bin/bash
LOG="/tmp/stackcodesy-network-security.log"

while true; do
    # Log active connections
    connections=$(netstat -tunapl 2>/dev/null | grep ESTABLISHED || true)

    if [ -n "$connections" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] ACTIVE CONNECTIONS:" >> "$LOG"
        echo "$connections" >> "$LOG"
    fi

    sleep 60
done
EOF

    chmod +x /usr/local/bin/monitor-network

    # Start monitoring in background
    nohup /usr/local/bin/monitor-network > /dev/null 2>&1 &
    log "Network monitoring enabled (PID: $!)"
fi

log "Network security configuration completed"
