#!/bin/bash
# StackCodeSy Filesystem Security Control
# Implements disk quotas, file size limits, and file type restrictions

set -e

LOG_FILE="/tmp/stackcodesy-filesystem-security.log"
WORKSPACE_DIR="/workspace"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Configuring filesystem security..."

# 1. DISK QUOTAS
DISK_QUOTA_MB="${STACKCODESY_DISK_QUOTA_MB:-0}"  # 0 = no limit

if [ "$DISK_QUOTA_MB" -gt 0 ]; then
    log "Setting disk quota: ${DISK_QUOTA_MB}MB"

    # Create quota monitoring script
    cat > /usr/local/bin/check-disk-quota << EOF
#!/bin/bash
QUOTA_MB=$DISK_QUOTA_MB
WORKSPACE="/workspace"
LOG="/tmp/stackcodesy-filesystem-security.log"

USAGE_MB=\$(du -sm "\$WORKSPACE" 2>/dev/null | cut -f1)

if [ "\$USAGE_MB" -gt "\$QUOTA_MB" ]; then
    echo "[\$(date +'%Y-%m-%d %H:%M:%S')] QUOTA EXCEEDED: \${USAGE_MB}MB / \${QUOTA_MB}MB" >> "\$LOG"
    echo "Disk quota exceeded: \${USAGE_MB}MB / \${QUOTA_MB}MB" >&2
    echo "Please delete some files to continue." >&2
    exit 1
fi
EOF

    chmod +x /usr/local/bin/check-disk-quota
    log "Disk quota monitoring enabled: ${DISK_QUOTA_MB}MB"
else
    log "Disk quota: UNLIMITED"
fi

# 2. FILE SIZE LIMITS
MAX_FILE_SIZE_MB="${STACKCODESY_MAX_FILE_SIZE_MB:-1000}"  # Default 1GB

log "Max file size: ${MAX_FILE_SIZE_MB}MB"

# 3. FILE TYPE RESTRICTIONS
BLOCKED_TYPES="${STACKCODESY_BLOCK_FILE_TYPES:-.exe,.dll,.so,.dylib,.bin,.elf,.msi,.app}"

log "Blocked file types: $BLOCKED_TYPES"

# 4. FILESYSTEM MONITORING
ENABLE_MONITORING="${STACKCODESY_ENABLE_FS_MONITORING:-false}"

if [ "$ENABLE_MONITORING" = "true" ]; then
    log "Enabling filesystem monitoring..."

    # Install inotify-tools if not present
    if ! command -v inotifywait &> /dev/null; then
        log "Installing inotify-tools..."
        apt-get update -qq && apt-get install -y -qq inotify-tools > /dev/null 2>&1 || true
    fi

    if command -v inotifywait &> /dev/null; then
        # Create monitoring script
        cat > /usr/local/bin/monitor-filesystem << 'EOF'
#!/bin/bash
WORKSPACE="/workspace"
LOG="/tmp/stackcodesy-filesystem-security.log"
BLOCKED_TYPES="${STACKCODESY_BLOCK_FILE_TYPES:-.exe,.dll,.so,.dylib,.bin,.elf,.msi,.app}"
MAX_FILE_SIZE_MB="${STACKCODESY_MAX_FILE_SIZE_MB:-1000}"

log_event() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# Monitor file creation and modifications
inotifywait -m -r -e create,modify,moved_to "$WORKSPACE" --format '%e|%w%f' 2>/dev/null |
while IFS='|' read -r event filepath; do
    # Skip if file doesn't exist (race condition)
    [ ! -f "$filepath" ] && continue

    filename=$(basename "$filepath")
    extension="${filename##*.}"

    # Check blocked file types
    if echo ",$BLOCKED_TYPES," | grep -qi ",\.$extension,"; then
        log_event "BLOCKED: Dangerous file type detected: $filepath"
        rm -f "$filepath"
        echo "Security: File type .$extension is not allowed" >&2
        continue
    fi

    # Check file size
    size_mb=$(du -m "$filepath" 2>/dev/null | cut -f1)
    if [ "$size_mb" -gt "$MAX_FILE_SIZE_MB" ]; then
        log_event "BLOCKED: File too large (${size_mb}MB): $filepath"
        rm -f "$filepath"
        echo "Security: File exceeds maximum size of ${MAX_FILE_SIZE_MB}MB" >&2
        continue
    fi

    # Check for suspicious patterns (executables without extension)
    if head -c 4 "$filepath" 2>/dev/null | grep -q $'\x7fELF'; then
        log_event "BLOCKED: ELF executable detected: $filepath"
        rm -f "$filepath"
        echo "Security: Executable files are not allowed" >&2
        continue
    fi

    # Check for scripts with shebang
    if head -n 1 "$filepath" 2>/dev/null | grep -q '^#!'; then
        # Allow common script types
        if [[ ! "$extension" =~ ^(sh|bash|py|js|rb|pl)$ ]]; then
            log_event "WARNING: Script file detected: $filepath"
        fi
    fi

    log_event "FILE: $event - $filepath (${size_mb}MB)"
done
EOF

        chmod +x /usr/local/bin/monitor-filesystem

        # Start monitoring in background
        log "Starting filesystem monitor..."
        nohup /usr/local/bin/monitor-filesystem > /dev/null 2>&1 &
        log "Filesystem monitoring enabled (PID: $!)"
    else
        log "WARNING: inotify-tools not available, filesystem monitoring disabled"
    fi
else
    log "Filesystem monitoring: DISABLED"
fi

# 5. SET WORKSPACE PERMISSIONS
mkdir -p "$WORKSPACE_DIR"
chown -R stackcodesy:stackcodesy "$WORKSPACE_DIR"
chmod 755 "$WORKSPACE_DIR"

log "Filesystem security configuration completed"
