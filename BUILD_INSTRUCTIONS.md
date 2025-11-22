# StackCodeSy - Build Instructions

Complete guide for building StackCodeSy with full branding from source.

## Quick Start (2 steps)

```bash
# 1. Build locally (30-50 minutes, one time)
./build-local.sh

# 2. Build and run Docker (2-3 minutes)
docker-compose up -d --build

# Access at http://localhost:8889
```

---

## Detailed Instructions

### Prerequisites

#### System Requirements
- **RAM**: 16GB minimum, 32GB recommended
- **Disk**: 10GB free space
- **OS**: macOS, Linux, or Windows (WSL2)
- **Time**: 30-50 minutes for first build

#### Software Requirements
- **Node.js 20+** ([download](https://nodejs.org))
- **Git** ([download](https://git-scm.com))
- **jq** (for JSON manipulation)
  - macOS: `brew install jq`
  - Linux: `apt install jq` or `yum install jq`
- **Docker** ([download](https://docker.com))
- **Docker Compose** (included with Docker Desktop)

### Step 1: Build VSCode Locally

The `build-local.sh` script compiles VSCode from source with StackCodeSy branding.

```bash
# Make script executable
chmod +x build-local.sh

# Run build
./build-local.sh
```

#### What happens during build:

```
[1/8] Check requirements (Node.js, npm, git, jq, RAM)
[2/8] Create build directories
[3/8] Clone VSCode from GitHub (~500MB)
[4/8] Apply StackCodeSy branding to source
      - Modify product.json
      - Modify package.json
      - Create custom welcome page
[5/8] Install dependencies (~5-10 min)
[6/8] Compile vscode-reh-web (~30-40 min) ⏳
[7/8] Verify build output
[8/8] Create tarball → dist/vscode-reh-web-linux-x64.tar.gz
```

**Total time**: 35-50 minutes

**Output**: `dist/vscode-reh-web-linux-x64.tar.gz` (~150-200MB)

#### Monitor progress:

```bash
# The script shows progress. During compilation you'll see:
# "Starting compilation..."
# "This will take 30-50 minutes..."

# If it seems stuck, it's probably still compiling.
# Be patient! ☕
```

#### Troubleshooting:

**Out of memory**:
```bash
# Increase Node.js memory
export NODE_OPTIONS="--max-old-space-size=16384"
./build-local.sh
```

**Build fails**:
```bash
# Clean and retry
rm -rf build/vscode
./build-local.sh
```

**Already compiled, want to rebuild**:
```bash
# Remove build directory
rm -rf build/

# Or just the compiled output
rm -rf build/vscode/vscode-reh-web-linux-x64

# Then run again
./build-local.sh
```

### Step 2: Build Docker Image

Once you have `dist/vscode-reh-web-linux-x64.tar.gz`:

```bash
# Build Docker image (uses pre-built binaries)
docker-compose build

# This only takes 2-3 minutes because:
# - VSCode is already compiled
# - Just copying files and installing scripts
```

### Step 3: Run

```bash
# Start container
docker-compose up -d

# View logs
docker-compose logs -f

# Access editor
open http://localhost:8889
```

---

## Build Options

### Change VSCode Version

Edit `build-local.sh`:
```bash
export VSCODE_VERSION=1.96.0
./build-local.sh
```

### Different Environments

```bash
# Development (no security)
docker-compose -f docker-compose.dev.yml up -d

# Staging (moderate security)
export STACKCODESY_USER_ID=user123
export STACKCODESY_AUTH_TOKEN=token
docker-compose -f docker-compose.staging.yml up -d

# Production (maximum security)
export STACKCODESY_USER_ID=user123
export STACKCODESY_AUTH_TOKEN=token
docker-compose -f docker-compose.prod.yml up -d
```

---

## Advanced: Manual Compilation

If you want more control:

```bash
# 1. Clone VSCode
git clone --depth 1 --branch 1.95.3 https://github.com/microsoft/vscode.git
cd vscode

# 2. Apply branding manually
jq '.nameShort = "StackCodeSy"' product.json > product.json.tmp
mv product.json.tmp product.json

# 3. Install dependencies
npm ci

# 4. Compile
export NODE_OPTIONS="--max-old-space-size=8192"
npm run gulp vscode-reh-web-linux-x64

# 5. Package
tar -czf vscode-reh-web-linux-x64.tar.gz vscode-reh-web-linux-x64/

# 6. Move to dist
mkdir -p ../dist
mv vscode-reh-web-linux-x64.tar.gz ../dist/
```

---

## CI/CD Integration

### GitHub Actions (optional)

If you want automated builds, you can:

1. Compile locally once
2. Upload tarball to GitHub Releases
3. Docker pulls from releases instead of compiling

Or use a powerful CI runner:

```yaml
# .github/workflows/build.yml
jobs:
  build:
    runs-on: ubuntu-latest-16-cores  # Need powerful runner
    steps:
      - uses: actions/checkout@v4
      - run: ./build-local.sh
      - uses: actions/upload-artifact@v4
        with:
          name: vscode-reh-web
          path: dist/vscode-reh-web-linux-x64.tar.gz
```

### Build Server

For teams, set up a dedicated build server:

```bash
# On build server (with 32GB+ RAM)
git clone https://github.com/yourorg/StackCodeSy.git
cd StackCodeSy
./build-local.sh

# Share dist/vscode-reh-web-linux-x64.tar.gz with team
# Everyone else just uses the pre-built binary
```

---

## File Structure After Build

```
StackCodeSy/
├── build/
│   └── vscode/                        # Source code (gitignored)
│       ├── vscode-reh-web-linux-x64/  # Compiled output
│       ├── product.json               # Branded
│       └── package.json               # Branded
├── dist/
│   └── vscode-reh-web-linux-x64.tar.gz  # Final output (150-200MB)
├── build-local.sh                     # Build script
├── Dockerfile.prebuilt                # Uses pre-built tarball
└── docker-compose.yml                 # Uses Dockerfile.prebuilt
```

---

## Performance Tips

### Speed up subsequent builds

If you need to rebuild:

```bash
# Don't delete build/vscode/ directory
# Just delete the compiled output:
rm -rf build/vscode/vscode-reh-web-linux-x64

# Rebuild (faster because dependencies are cached)
./build-local.sh
```

### Parallel builds

If building multiple versions:

```bash
# Build v1.95.3
VSCODE_VERSION=1.95.3 ./build-local.sh

# Build v1.96.0 (in parallel, if you have enough RAM)
VSCODE_VERSION=1.96.0 ./build-local.sh
```

---

## Distribution

### Share with team

```bash
# Upload to file server
scp dist/vscode-reh-web-linux-x64.tar.gz user@server:/shared/

# Or create GitHub Release
gh release create v1.95.3 dist/vscode-reh-web-linux-x64.tar.gz
```

### Docker Registry

```bash
# Build image
docker build -f Dockerfile.prebuilt -t stackcodesy:1.95.3 .

# Push to registry
docker tag stackcodesy:1.95.3 yourregistry/stackcodesy:1.95.3
docker push yourregistry/stackcodesy:1.95.3
```

---

## Maintenance

### Update VSCode version

```bash
# 1. Update version
export VSCODE_VERSION=1.96.0

# 2. Rebuild
./build-local.sh

# 3. Test
docker-compose build
docker-compose up -d

# 4. Verify branding
# Open http://localhost:8889 and check it says "StackCodeSy"
```

### Verify branding after build

```bash
# Extract tarball
cd dist
tar -xzf vscode-reh-web-linux-x64.tar.gz
cd vscode-reh-web

# Check product.json
jq '.nameShort, .nameLong' product.json

# Should show:
# "StackCodeSy"
# "StackCodeSy Editor"

# Run server to verify UI
./bin/code-server --host 0.0.0.0 --port 8080
# Open browser and check branding
```

---

## Support

- **Build issues**: Check `build/vscode/` for error logs
- **Docker issues**: Check `docker-compose logs`
- **Memory issues**: Increase Docker memory to 16GB+
- **Time concerns**: First build takes 40-60 min, it's normal

For more help, see:
- [README.md](README.md) - General documentation
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Production deployment

---

**Built with ❤️ for StackCodeSy**
