#!/bin/bash
# StackCodeSy Terminal Security Control
# Controls terminal access with three modes: disabled, restricted, full

set -e

TERMINAL_MODE="${STACKCODESY_TERMINAL_MODE:-full}"
LOG_FILE="/tmp/stackcodesy-terminal-security.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Terminal Security Mode: $TERMINAL_MODE"

case "$TERMINAL_MODE" in
    disabled)
        log "Terminal DISABLED - blocking all terminal access"
        # Block terminal by removing shell access
        rm -f /bin/bash /bin/sh /usr/bin/bash /usr/bin/sh 2>/dev/null || true
        ln -sf /bin/false /bin/bash
        ln -sf /bin/false /bin/sh
        ;;

    restricted)
        log "Terminal RESTRICTED - only whitelisted commands allowed"

        # Default whitelist
        ALLOWED_COMMANDS="${STACKCODESY_TERMINAL_ALLOWED_COMMANDS:-ls,cd,pwd,cat,echo,mkdir,rm,cp,mv,touch,nano,vi,vim,git,node,npm,yarn,python,python3,pip,pip3}"

        log "Allowed commands: $ALLOWED_COMMANDS"

        # Create restricted shell wrapper
        cat > /usr/local/bin/restricted-shell << 'EOF'
#!/bin/bash
# Restricted shell wrapper
ALLOWED_COMMANDS="${STACKCODESY_TERMINAL_ALLOWED_COMMANDS:-ls,cd,pwd,cat,echo,mkdir,rm,cp,mv,touch,nano,vi,vim,git,node,npm,yarn,python,python3,pip,pip3}"
LOG_FILE="/tmp/stackcodesy-terminal-security.log"

log_cmd() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] USER: ${STACKCODESY_USER_ID:-unknown} CMD: $1" >> "$LOG_FILE"
}

# Read command
if [ $# -eq 0 ]; then
    # Interactive mode
    while IFS= read -r -p "stackcodesy> " cmd; do
        [ -z "$cmd" ] && continue

        # Extract base command
        base_cmd=$(echo "$cmd" | awk '{print $1}')

        # Check if allowed
        if echo ",$ALLOWED_COMMANDS," | grep -q ",$base_cmd,"; then
            log_cmd "ALLOWED: $cmd"
            eval "$cmd"
        else
            log_cmd "BLOCKED: $cmd"
            echo "Error: Command '$base_cmd' is not allowed in restricted mode"
            echo "Allowed commands: $ALLOWED_COMMANDS"
        fi
    done
else
    # Command mode
    base_cmd=$(echo "$1" | awk '{print $1}')

    if echo ",$ALLOWED_COMMANDS," | grep -q ",$base_cmd,"; then
        log_cmd "ALLOWED: $*"
        exec "$@"
    else
        log_cmd "BLOCKED: $*"
        echo "Error: Command '$base_cmd' is not allowed in restricted mode" >&2
        exit 1
    fi
fi
EOF

        chmod +x /usr/local/bin/restricted-shell

        # Replace shells with restricted version
        for shell in /bin/bash /bin/sh /usr/bin/bash /usr/bin/sh; do
            if [ -f "$shell" ]; then
                mv "$shell" "$shell.original"
                ln -sf /usr/local/bin/restricted-shell "$shell"
            fi
        done

        log "Restricted shell installed successfully"
        ;;

    full)
        log "Terminal FULL ACCESS - no restrictions"
        # No changes needed, full bash access
        ;;

    *)
        log "ERROR: Invalid STACKCODESY_TERMINAL_MODE: $TERMINAL_MODE"
        log "Valid modes: disabled, restricted, full"
        exit 1
        ;;
esac

log "Terminal security configuration completed"
