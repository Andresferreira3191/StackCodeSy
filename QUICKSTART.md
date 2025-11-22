# StackCodeSy - Quick Start Guide

## 🚀 Fast Start (2 minutes)

```bash
# 1. Clone the repository
git clone https://github.com/Andresferreira3191/StackCodeSy.git
cd StackCodeSy

# 2. Build and run
docker-compose up -d --build

# 3. Access the editor
open http://localhost:8889
```

That's it! VSCode editor is now running in your browser.

## 📦 What happens during build?

### Option A: Docker build from source (Dockerfile)
The Dockerfile automatically:
1. ✅ Clones VSCode source code from GitHub
2. ✅ Applies StackCodeSy branding BEFORE compilation
3. ✅ Compiles vscode-reh-web with custom branding (with C++20 support)
4. ✅ Installs security scripts
5. ✅ Builds custom authentication extension
6. ✅ Configures everything

**Build time:** ~40-60 minutes (first time only - compiling from source)
**Requirements:** Docker with 8GB+ RAM allocated
**Note:** This is normal. VSCode is a large project with 7000+ files.

### Option B: Pre-built binaries (Dockerfile.prebuilt)
If you've already compiled locally using `./build-local.sh`:
```bash
docker build -f Dockerfile.prebuilt -t stackcodesy:latest .
docker-compose up -d
```

**Build time:** ~2-3 minutes (uses pre-compiled tarball from dist/)
**Requirements:** Must run `./build-local.sh` first to create the tarball

## 🔧 Environment Options

### Development (no restrictions)
```bash
docker-compose -f docker-compose.dev.yml up -d
```
- No authentication required
- Full terminal access
- All extensions allowed
- Perfect for local development

### Staging (moderate security)
```bash
export STACKCODESY_USER_ID=user123
export STACKCODESY_AUTH_TOKEN=your-token

docker-compose -f docker-compose.staging.yml up -d
```
- Authentication required
- Restricted terminal (whitelist commands)
- Whitelisted extensions only
- 10GB disk quota

### Production (maximum security)
```bash
export STACKCODESY_USER_ID=user123
export STACKCODESY_AUTH_TOKEN=your-token
export STACKCODESY_SESSION_ID=$(uuidgen)

docker-compose -f docker-compose.prod.yml up -d
```
- Strict authentication
- Terminal disabled
- Strict extension whitelist
- 5GB disk quota
- No external network access
- Full audit logging

## 🎯 Customization

### Change VSCode version

Edit any `docker-compose*.yml` file:

```yaml
services:
  stackcodesy:
    build:
      args:
        VSCODE_VERSION: 1.96.0  # Change this
        VSCODE_QUALITY: stable
```

Then rebuild:
```bash
docker-compose build --no-cache
docker-compose up -d
```

### Configure security

All security is controlled via environment variables. See main [README.md](README.md#configuration) for full list.

Example:
```yaml
environment:
  # Terminal control
  - STACKCODESY_TERMINAL_MODE=restricted
  - STACKCODESY_TERMINAL_ALLOWED_COMMANDS=ls,cd,git,npm

  # Extension control
  - STACKCODESY_EXTENSION_MODE=whitelist
  - STACKCODESY_EXTENSION_WHITELIST=dbaeumer.vscode-eslint,esbenp.prettier-vscode

  # Resource limits
  - STACKCODESY_DISK_QUOTA_MB=5120
  - STACKCODESY_MAX_FILE_SIZE_MB=500
```

## 🐛 Troubleshooting

### Port already in use
```bash
# Change the external port in docker-compose.yml
ports:
  - "9999:8080"  # Change 8889 to 9999
```

### Build fails
```bash
# Clean build
docker-compose down -v
docker system prune -f
docker-compose build --no-cache
```

### Can't access editor
```bash
# Check logs
docker-compose logs -f

# Check if container is running
docker ps | grep stackcodesy

# Check health
docker-compose exec stackcodesy curl http://localhost:8080
```

### Extension not loading
```bash
# Rebuild with clean slate
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 📚 Next Steps

- Read [README.md](README.md) for full documentation
- Check [DEPLOYMENT.md](docs/DEPLOYMENT.md) for production deployment
- Review [SECURITY.md](SECURITY.md) for security features
- See [CONTEXT.md](CONTEXT.md) for implementation details

## ⚡ Performance Tips

### First build (slow)
- Downloads ~150MB VSCode binaries
- Installs all dependencies
- Takes 3-5 minutes

### Subsequent builds (fast)
- Uses Docker cache
- Only rebuilds changed layers
- Takes 30-60 seconds

### Speed up builds
```bash
# Use buildkit
export DOCKER_BUILDKIT=1
docker-compose build

# Or enable globally
echo 'export DOCKER_BUILDKIT=1' >> ~/.bashrc
```

## 🎨 What You Get

- ✅ Full VSCode editor in browser
- ✅ Custom authentication system
- ✅ 6-layer security controls
- ✅ Terminal security (3 modes)
- ✅ Extension marketplace control
- ✅ Filesystem monitoring
- ✅ Network egress filtering
- ✅ Complete audit logging
- ✅ Multi-environment configs
- ✅ Docker Swarm ready
- ✅ Production-ready

## 💡 Pro Tips

**Persist your workspace:**
```yaml
volumes:
  - ./my-projects:/workspace
```

**Enable file watching:**
```yaml
environment:
  - STACKCODESY_ENABLE_FS_MONITORING=true
```

**View audit logs:**
```bash
docker-compose exec stackcodesy tail -f /var/log/stackcodesy/audit.log
```

**Run in background:**
```bash
docker-compose up -d
```

**Stop:**
```bash
docker-compose down
```

**Update VSCode:**
```yaml
# Change version in docker-compose.yml
VSCODE_VERSION: 1.96.0

# Rebuild
docker-compose build --no-cache
docker-compose up -d
```

---

**Need help?** Check the [full documentation](README.md) or [open an issue](https://github.com/Andresferreira3191/StackCodeSy/issues).
