#!/bin/bash
# StackCodeSy Extension Marketplace Security Control
# Controls extension marketplace access: disabled, whitelist, full

set -e

EXTENSION_MODE="${STACKCODESY_EXTENSION_MODE:-full}"
LOG_FILE="/tmp/stackcodesy-extension-security.log"
CONFIG_DIR="/home/stackcodesy/.stackcodesy/User"
PRODUCT_JSON="/workspace/vscode/product.json"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Extension Marketplace Mode: $EXTENSION_MODE"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

case "$EXTENSION_MODE" in
    disabled)
        log "Extensions DISABLED - blocking marketplace access"

        # Disable marketplace in product.json
        if [ -f "$PRODUCT_JSON" ]; then
            # Backup original
            cp "$PRODUCT_JSON" "${PRODUCT_JSON}.backup"

            # Remove gallery URLs
            cat "$PRODUCT_JSON" | jq '.extensionsGallery = {
                "serviceUrl": "",
                "itemUrl": "",
                "controlUrl": "",
                "recommendationsUrl": ""
            }' > "${PRODUCT_JSON}.tmp" && mv "${PRODUCT_JSON}.tmp" "$PRODUCT_JSON"

            log "Marketplace URLs removed from product.json"
        fi

        # Create settings.json with marketplace disabled
        cat > "$CONFIG_DIR/settings.json" << 'EOF'
{
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,
  "extensions.ignoreRecommendations": true,
  "extensions.showRecommendationsOnlyOnDemand": true,
  "workbench.enableExperiments": false,
  "extensions.webWorker": false
}
EOF

        log "Extension marketplace completely disabled"
        ;;

    whitelist)
        log "Extensions WHITELIST - only approved extensions allowed"

        # Default whitelist (common safe extensions)
        WHITELIST="${STACKCODESY_EXTENSION_WHITELIST:-dbaeumer.vscode-eslint,esbenp.prettier-vscode,ms-python.python,ms-vscode.vscode-typescript-next}"

        log "Whitelisted extensions: $WHITELIST"

        # Create settings with restricted marketplace
        cat > "$CONFIG_DIR/settings.json" << EOF
{
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,
  "extensions.ignoreRecommendations": true,
  "extensions.showRecommendationsOnlyOnDemand": true,
  "workbench.enableExperiments": false
}
EOF

        # Store whitelist for later validation
        echo "$WHITELIST" > "$CONFIG_DIR/extension-whitelist.txt"

        log "Extension whitelist configured: $WHITELIST"
        ;;

    full)
        log "Extensions FULL ACCESS - marketplace enabled"

        # Create minimal settings
        cat > "$CONFIG_DIR/settings.json" << 'EOF'
{
  "extensions.autoCheckUpdates": true,
  "extensions.autoUpdate": false,
  "extensions.ignoreRecommendations": false
}
EOF

        log "Extension marketplace fully enabled"
        ;;

    *)
        log "ERROR: Invalid STACKCODESY_EXTENSION_MODE: $EXTENSION_MODE"
        log "Valid modes: disabled, whitelist, full"
        exit 1
        ;;
esac

# Set proper permissions
chmod 644 "$CONFIG_DIR/settings.json"
chown -R stackcodesy:stackcodesy "$CONFIG_DIR"

log "Extension marketplace security configuration completed"
