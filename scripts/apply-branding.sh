#!/bin/bash
# StackCodeSy Branding Script
# Applies custom branding to VSCode

set -e

VSCODE_DIR="${1:-./vscode}"

if [ ! -d "$VSCODE_DIR" ]; then
    echo "Error: VSCode directory not found: $VSCODE_DIR"
    echo "Usage: $0 <vscode-directory>"
    exit 1
fi

echo "=================================================="
echo "  Applying StackCodeSy Branding"
echo "=================================================="
echo ""

cd "$VSCODE_DIR"

# Backup original product.json
if [ -f "product.json" ] && [ ! -f "product.json.original" ]; then
    echo "[1/5] Backing up original product.json..."
    cp product.json product.json.original
fi

# Update product.json with StackCodeSy branding
echo "[2/5] Updating product.json..."
if command -v jq &> /dev/null; then
    jq '.nameShort = "StackCodeSy" |
        .nameLong = "StackCodeSy Editor" |
        .applicationName = "stackcodesy" |
        .dataFolderName = ".stackcodesy" |
        .serverDataFolderName = ".stackcodesy-server" |
        .darwinBundleIdentifier = "com.stackcodesy.editor" |
        .linuxIconName = "stackcodesy" |
        .win32AppId = "{{StackCodeSy}}" |
        .win32MutexName = "stackcodesy" |
        .win32DirName = "StackCodeSy" |
        .win32NameVersion = "StackCodeSy" |
        .win32RegValueName = "StackCodeSy" |
        .win32AppUserModelId = "StackCodeSy.StackCodeSy" |
        .win32ShellNameShort = "StackCodeSy" |
        .reportIssueUrl = "https://github.com/yourorg/stackcodesy/issues" |
        .documentationUrl = "https://docs.stackcodesy.com" |
        .requestFeatureUrl = "https://github.com/yourorg/stackcodesy/issues/new"' \
      product.json > product.json.tmp && mv product.json.tmp product.json

    echo "✓ product.json updated"
else
    echo "Warning: jq not found, manual editing required"
fi

# Update package.json
echo "[3/5] Updating package.json..."
if [ -f "package.json" ] && command -v jq &> /dev/null; then
    jq '.displayName = "StackCodeSy" |
        .name = "stackcodesy" |
        .description = "StackCodeSy - Secure Code Editor"' \
      package.json > package.json.tmp && mv package.json.tmp package.json

    echo "✓ package.json updated"
fi

# Update README
echo "[4/5] Creating StackCodeSy README..."
cat > README.stackcodesy.md << 'EOF'
# StackCodeSy Editor

StackCodeSy is a secure, web-based code editor built on VSCode.

## Features

- 🔒 **Enterprise Security**: Multi-layer security controls
- 🌐 **Web-Based**: Access from anywhere
- 🔐 **Custom Authentication**: Integrate with your auth system
- 📝 **Full VSCode Features**: All the power of VSCode in the browser
- 🛡️ **Audit Logging**: Complete activity tracking
- 🚀 **High Performance**: Optimized for production use

## Quick Start

```bash
docker-compose up -d
```

Visit http://localhost:8889

## Documentation

See [docs/](docs/) for full documentation.

## License

Based on VSCode (MIT License) with StackCodeSy enhancements.
EOF

echo "✓ README.stackcodesy.md created"

# Create custom welcome page content
echo "[5/5] Creating welcome page content..."
mkdir -p src/vs/workbench/contrib/welcome/page/browser/customContent
cat > src/vs/workbench/contrib/welcome/page/browser/customContent/stackcodesy.md << 'EOF'
# Welcome to StackCodeSy

StackCodeSy is your secure, enterprise-grade code editor in the cloud.

## Getting Started

1. **Open a Folder**: Start by opening a folder or cloning a repository
2. **Install Extensions**: Browse our curated extension marketplace
3. **Start Coding**: All VSCode features at your fingertips

## Security Features

- ✅ Custom authentication
- ✅ Terminal security controls
- ✅ Extension restrictions
- ✅ Network filtering
- ✅ Full audit logging

## Need Help?

- 📖 [Documentation](https://docs.stackcodesy.com)
- 💬 [Support](https://support.stackcodesy.com)
- 🐛 [Report Issues](https://github.com/yourorg/stackcodesy/issues)

---

**Powered by VSCode** | **Secured by StackCodeSy**
EOF

echo "✓ Welcome content created"

echo ""
echo "=================================================="
echo "  Branding Applied Successfully!"
echo "=================================================="
echo ""
echo "Changes made:"
echo "  • product.json - Updated with StackCodeSy branding"
echo "  • package.json - Updated display name"
echo "  • README.stackcodesy.md - Created"
echo "  • Welcome page content - Created"
echo ""
echo "Originals backed up with .original extension"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Add custom icons/logos to resources/"
echo "  3. Build VSCode: npm run gulp vscode-reh-web"
echo ""
