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

The Dockerfile automatically:
1. ✅ Compiles VSCode from source (30-40 min)
2. ✅ Compiles code-server from source
3. ✅ Applies StackCodeSy branding
4. ✅ Installs StackCodeSy security layers
5. ✅ Creates optimized release bundle

**Build time:** ~40-50 minutes (first time - compiling from source)
**Requirements:** Docker with 8GB+ RAM allocated

StackCodeSy is built from [code-server](https://github.com/coder/code-server) source code with enterprise-grade security features and custom branding.

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

**Update code-server:**
```bash
# Pull latest code-server image
docker pull codercom/code-server:latest

# Rebuild
docker-compose build --no-cache
docker-compose up -d
```

---

**Need help?** Check the [full documentation](README.md) or [open an issue](https://github.com/Andresferreira3191/StackCodeSy/issues).
