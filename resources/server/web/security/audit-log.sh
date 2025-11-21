#!/bin/bash
# StackCodeSy Audit Logging System
# Logs all user actions for security compliance

set -e

LOG_DIR="/var/log/stackcodesy"
AUDIT_LOG="$LOG_DIR/audit.log"
USER_ID="${STACKCODESY_USER_ID:-unknown}"
SESSION_ID="${STACKCODESY_SESSION_ID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo 'unknown')}"

ENABLE_AUDIT="${STACKCODESY_ENABLE_AUDIT_LOG:-true}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

log_event() {
    local event_type="$1"
    local event_data="$2"
    local timestamp=$(date -Iseconds)

    echo "${timestamp}|${USER_ID}|${SESSION_ID}|${event_type}|${event_data}" >> "$AUDIT_LOG"
}

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Audit Logging: $ENABLE_AUDIT" | tee -a /tmp/stackcodesy-audit-log.log

if [ "$ENABLE_AUDIT" != "true" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Audit logging disabled" | tee -a /tmp/stackcodesy-audit-log.log
    exit 0
fi

# Initialize audit log
touch "$AUDIT_LOG"
chmod 644 "$AUDIT_LOG"

# Log session start
log_event "SESSION_START" "User: ${STACKCODESY_USER_EMAIL:-$USER_ID}, Terminal Mode: ${STACKCODESY_TERMINAL_MODE:-full}, Extension Mode: ${STACKCODESY_EXTENSION_MODE:-full}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Session logged: $SESSION_ID" | tee -a /tmp/stackcodesy-audit-log.log

# Setup terminal command logging (if terminal is enabled)
TERMINAL_MODE="${STACKCODESY_TERMINAL_MODE:-full}"

if [ "$TERMINAL_MODE" != "disabled" ]; then
    # Create bash profile for logging
    cat > /etc/profile.d/stackcodesy-audit.sh << 'EOF'
# StackCodeSy Audit Logging for Terminal
export STACKCODESY_AUDIT_LOG="/var/log/stackcodesy/audit.log"
export STACKCODESY_USER_ID="${STACKCODESY_USER_ID:-unknown}"
export STACKCODESY_SESSION_ID="${STACKCODESY_SESSION_ID}"

log_command() {
    local cmd="$1"
    local timestamp=$(date -Iseconds)
    echo "${timestamp}|${STACKCODESY_USER_ID}|${STACKCODESY_SESSION_ID}|TERMINAL_CMD|${cmd}" >> "$STACKCODESY_AUDIT_LOG"
}

# Hook into bash history
if [ -n "$BASH" ]; then
    PROMPT_COMMAND='history -a; log_command "$(history 1 | sed "s/^[ ]*[0-9]*[ ]*//")" 2>/dev/null'
fi
EOF

    chmod 644 /etc/profile.d/stackcodesy-audit.sh
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Terminal command logging enabled" | tee -a /tmp/stackcodesy-audit-log.log
fi

# Setup file operation monitoring (if enabled)
if [ "${STACKCODESY_ENABLE_FS_MONITORING:-false}" = "true" ]; then
    if command -v inotifywait &> /dev/null; then
        cat > /usr/local/bin/audit-file-monitor << 'EOF'
#!/bin/bash
AUDIT_LOG="/var/log/stackcodesy/audit.log"
USER_ID="${STACKCODESY_USER_ID:-unknown}"
SESSION_ID="${STACKCODESY_SESSION_ID}"
WORKSPACE="/workspace"

inotifywait -m -r -e create,modify,delete,move "$WORKSPACE" --format '%e|%w%f' 2>/dev/null |
while IFS='|' read -r event filepath; do
    timestamp=$(date -Iseconds)
    echo "${timestamp}|${USER_ID}|${SESSION_ID}|FILE_${event}|${filepath}" >> "$AUDIT_LOG"
done
EOF

        chmod +x /usr/local/bin/audit-file-monitor

        # Start in background
        nohup /usr/local/bin/audit-file-monitor > /dev/null 2>&1 &
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] File operation logging enabled (PID: $!)" | tee -a /tmp/stackcodesy-audit-log.log
    fi
fi

# Setup network connection logging (if enabled)
if [ "${STACKCODESY_ENABLE_NETWORK_MONITORING:-false}" = "true" ]; then
    cat > /usr/local/bin/audit-network-monitor << 'EOF'
#!/bin/bash
AUDIT_LOG="/var/log/stackcodesy/audit.log"
USER_ID="${STACKCODESY_USER_ID:-unknown}"
SESSION_ID="${STACKCODESY_SESSION_ID}"

while true; do
    connections=$(netstat -tunapl 2>/dev/null | grep ESTABLISHED | awk '{print $5}' | sort -u)

    if [ -n "$connections" ]; then
        for conn in $connections; do
            timestamp=$(date -Iseconds)
            echo "${timestamp}|${USER_ID}|${SESSION_ID}|NETWORK_CONNECTION|${conn}" >> "$AUDIT_LOG"
        done
    fi

    sleep 60
done
EOF

    chmod +x /usr/local/bin/audit-network-monitor

    # Start in background
    nohup /usr/local/bin/audit-network-monitor > /dev/null 2>&1 &
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Network logging enabled (PID: $!)" | tee -a /tmp/stackcodesy-audit-log.log
fi

# Log rotation setup
cat > /etc/logrotate.d/stackcodesy << 'EOF'
/var/log/stackcodesy/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 root root
    sharedscripts
}
EOF

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Audit logging system initialized" | tee -a /tmp/stackcodesy-audit-log.log

# Export session ID for other scripts
export STACKCODESY_SESSION_ID="$SESSION_ID"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Audit log configuration completed" | tee -a /tmp/stackcodesy-audit-log.log
