#!/bin/bash
# StackCodeSy - Local Build Script
# Compiles VSCode from source with StackCodeSy branding
# Requirements: 16GB+ RAM, Node.js 20+, 30-50 minutes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VSCODE_VERSION="${VSCODE_VERSION:-1.95.3}"
BUILD_DIR="./build"
VSCODE_DIR="$BUILD_DIR/vscode"
OUTPUT_DIR="./dist"

echo -e "${BLUE}=================================================="
echo "  StackCodeSy - Local Build Script"
echo "  Compiling VSCode ${VSCODE_VERSION} with branding"
echo "==================================================${NC}"
echo ""

# Check requirements
echo -e "${YELLOW}[1/8] Checking requirements...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}ERROR: Node.js not found${NC}"
    echo "Install Node.js 20+ from https://nodejs.org"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo -e "${RED}ERROR: Node.js 20+ required (found: $(node -v))${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Node.js $(node -v)${NC}"

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}ERROR: npm not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ npm $(npm -v)${NC}"

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${RED}ERROR: git not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ git $(git --version | cut -d' ' -f3)${NC}"

# Check jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq not found${NC}"
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi
echo -e "${GREEN}✓ jq $(jq --version)${NC}"

# Check available RAM
if [[ "$OSTYPE" == "darwin"* ]]; then
    TOTAL_RAM=$(sysctl hw.memsize | awk '{print int($2/1024/1024/1024)}')
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
else
    TOTAL_RAM=0
fi

if [ "$TOTAL_RAM" -gt 0 ]; then
    echo -e "${GREEN}✓ Total RAM: ${TOTAL_RAM}GB${NC}"
    if [ "$TOTAL_RAM" -lt 16 ]; then
        echo -e "${YELLOW}WARNING: Less than 16GB RAM detected. Build may fail.${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not detect RAM${NC}"
fi

echo ""

# Create build directory
echo -e "${YELLOW}[2/8] Setting up build directory...${NC}"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}✓ Build directory ready${NC}"
echo ""

# Clone VSCode if not exists
if [ -d "$VSCODE_DIR" ]; then
    echo -e "${YELLOW}[3/8] VSCode directory exists, using existing clone...${NC}"
    cd "$VSCODE_DIR"
    git fetch --depth 1 origin tag "$VSCODE_VERSION"
    git checkout "$VSCODE_VERSION"
    cd ../..
else
    echo -e "${YELLOW}[3/8] Cloning VSCode ${VSCODE_VERSION}...${NC}"
    git clone --depth 1 --branch "$VSCODE_VERSION" \
        https://github.com/microsoft/vscode.git "$VSCODE_DIR"
    echo -e "${GREEN}✓ VSCode cloned successfully${NC}"
fi
echo ""

# Apply branding
echo -e "${YELLOW}[4/8] Applying StackCodeSy branding...${NC}"
cd "$VSCODE_DIR"

# Backup original files
if [ ! -f "product.json.original" ]; then
    cp product.json product.json.original
    echo "  Backed up product.json"
fi

# Apply branding to product.json
jq '. + {
    "nameShort": "StackCodeSy",
    "nameLong": "StackCodeSy Editor",
    "applicationName": "stackcodesy",
    "dataFolderName": ".stackcodesy",
    "serverDataFolderName": ".stackcodesy-server",
    "darwinBundleIdentifier": "com.stackcodesy.editor",
    "linuxIconName": "stackcodesy",
    "reportIssueUrl": "https://github.com/yourorg/stackcodesy/issues",
    "documentationUrl": "https://docs.stackcodesy.com",
    "requestFeatureUrl": "https://github.com/yourorg/stackcodesy/issues/new",
    "quality": "stable"
}' product.json.original > product.json

echo -e "${GREEN}✓ Branding applied to product.json${NC}"

# Apply branding to package.json
if [ -f "package.json" ]; then
    if [ ! -f "package.json.original" ]; then
        cp package.json package.json.original
    fi
    jq '.displayName = "StackCodeSy" |
        .name = "stackcodesy" |
        .description = "StackCodeSy - Secure Code Editor"' \
        package.json.original > package.json
    echo -e "${GREEN}✓ Branding applied to package.json${NC}"
fi

# Create custom welcome content
mkdir -p src/vs/workbench/contrib/welcome/page/browser
cat > src/vs/workbench/contrib/welcome/page/browser/stackcodesy-welcome.ts << 'EOF'
/*---------------------------------------------------------------------------------------------
 *  StackCodeSy Custom Welcome Content
 *--------------------------------------------------------------------------------------------*/

export const stackcodesyWelcomeContent = `
# Welcome to StackCodeSy

Your secure, enterprise-grade code editor.

## Features
- 🔒 Multi-layer security controls
- 🌐 Access from anywhere
- 🔐 Custom authentication
- ⚡ Full VSCode power

Powered by VSCode | Secured by StackCodeSy
`;
EOF
echo -e "${GREEN}✓ Custom welcome content created${NC}"

cd ../..
echo ""

# Install dependencies
echo -e "${YELLOW}[5/8] Installing dependencies...${NC}"
echo "This may take 5-10 minutes..."
cd "$VSCODE_DIR"
npm ci
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Compile
echo -e "${YELLOW}[6/8] Compiling vscode-reh-web-linux-x64...${NC}"
echo -e "${BLUE}This will take 30-50 minutes. Please be patient.${NC}"
echo ""
echo "Started at: $(date)"
echo ""

export NODE_OPTIONS="--max-old-space-size=8192"

npm run gulp vscode-reh-web-linux-x64

echo ""
echo -e "${GREEN}✓ Compilation completed successfully!${NC}"
echo "Finished at: $(date)"
echo ""

# Verify build
echo -e "${YELLOW}[7/8] Verifying build...${NC}"
if [ -d "vscode-reh-web-linux-x64" ]; then
    SIZE=$(du -sh vscode-reh-web-linux-x64 | cut -f1)
    echo -e "${GREEN}✓ Build directory found (Size: $SIZE)${NC}"
    echo ""
    echo "Contents:"
    ls -lah vscode-reh-web-linux-x64/ | head -20
else
    echo -e "${RED}ERROR: Build directory not found!${NC}"
    exit 1
fi
echo ""

# Package
echo -e "${YELLOW}[8/8] Creating tarball...${NC}"
cd ..
OUTPUT_FILE="$OUTPUT_DIR/vscode-reh-web-linux-x64.tar.gz"

tar -czf "$OUTPUT_FILE" \
    --transform 's,^vscode/vscode-reh-web-linux-x64,vscode-reh-web,' \
    vscode/vscode-reh-web-linux-x64/

cd ..

TARBALL_SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)
echo -e "${GREEN}✓ Tarball created: $OUTPUT_FILE ($TARBALL_SIZE)${NC}"
echo ""

# Summary
echo -e "${GREEN}=================================================="
echo "  ✓ Build Completed Successfully!"
echo "==================================================${NC}"
echo ""
echo "Output file: $OUTPUT_FILE"
echo "Size: $TARBALL_SIZE"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Test locally:"
echo "   cd dist"
echo "   tar -xzf vscode-reh-web-linux-x64.tar.gz"
echo "   cd vscode-reh-web"
echo "   ./bin/code-server --host 0.0.0.0 --port 8080 --without-connection-token /path/to/workspace"
echo ""
echo "2. Use with Docker:"
echo "   # The tarball is already in ./dist/"
echo "   # Docker will use it automatically if you update the Dockerfile"
echo ""
echo "3. Create GitHub Release:"
echo "   gh release create v${VSCODE_VERSION} dist/vscode-reh-web-linux-x64.tar.gz"
echo ""
echo -e "${GREEN}Build completed at: $(date)${NC}"
