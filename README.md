# StackCodeSy - Secure VSCode Web Editor

StackCodeSy is a production-ready, secure VSCode web editor with custom authentication, multi-layer security controls, and enterprise features.

## 🚀 Features

- **🌐 Web-Based Editor**: Full VSCode experience in the browser
- **🔐 Custom Authentication**: Integrate with your existing auth system
- **🛡️ Multi-Layer Security**:
  - Terminal security (disabled/restricted/full modes)
  - Extension marketplace controls
  - Filesystem monitoring and restrictions
  - Network egress filtering
  - Full audit logging
- **📦 Docker Deployment**: Multiple configurations for dev/staging/prod
- **🔧 Customizable**: Branding, extensions, and security policies
- **⚡ High Performance**: Based on vscode-reh-web (official VSCode web server)

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Security Features](#security-features)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Development](#development)
- [Documentation](#documentation)

## ⚡ Quick Start

### Using Docker Compose (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourorg/StackCodeSy.git
cd StackCodeSy

# Start in development mode (no security restrictions)
docker-compose up -d --build

# Access the editor
open http://localhost:8889
```

### Manual Build

```bash
# 1. Clone VSCode
git clone --depth 1 --branch 1.95.3 https://github.com/microsoft/vscode.git vscode

# 2. Apply branding
./scripts/apply-branding.sh vscode

# 3. Build vscode-reh-web
cd vscode
npm ci --ignore-scripts
npm rebuild
npm run gulp vscode-reh-web-linux-x64

# 4. Package
tar -czf ../vscode-reh-web-linux-x64.tar.gz vscode-reh-web-linux-x64/

# 5. Build Docker image
cd ..
docker build -f docker/Dockerfile -t stackcodesy:latest .

# 6. Run
docker-compose up -d
```

## 🏗️ Architecture

```
StackCodeSy
├── vscode/                      # VSCode source (cloned, not committed)
├── resources/
│   └── server/web/security/     # Security scripts
│       ├── entrypoint.sh        # Main orchestrator
│       ├── terminal-security.sh
│       ├── extension-marketplace.sh
│       ├── filesystem-security.sh
│       ├── network-security.sh
│       ├── audit-log.sh
│       └── csp-config.sh
├── extensions/
│   └── stackcodesy-auth/        # Custom authentication extension
├── docker/
│   ├── Dockerfile               # Production (uses pre-built artifacts)
│   └── Dockerfile.build         # Build from source
├── .github/workflows/
│   └── build-vscode-web.yml     # CI/CD for building vscode-reh-web
├── docker-compose.yml           # Local testing
├── docker-compose.dev.yml       # Development
├── docker-compose.staging.yml   # Staging
└── docker-compose.prod.yml      # Production
```

## 🛡️ Security Features

### 1. Terminal Security (3 Modes)

- **Disabled**: No terminal access
- **Restricted**: Whitelist of allowed commands
- **Full**: Complete terminal access (dev only)

```bash
STACKCODESY_TERMINAL_MODE=restricted
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=ls,cd,pwd,git,npm,node
```

### 2. Extension Marketplace Control

- **Disabled**: No marketplace access
- **Whitelist**: Only approved extensions
- **Full**: Complete marketplace access

```bash
STACKCODESY_EXTENSION_MODE=whitelist
STACKCODESY_EXTENSION_WHITELIST=dbaeumer.vscode-eslint,esbenp.prettier-vscode
```

### 3. Filesystem Security

- Disk quotas per user
- File size limits
- Blocked file types
- Real-time monitoring

```bash
STACKCODESY_DISK_QUOTA_MB=5120
STACKCODESY_MAX_FILE_SIZE_MB=500
STACKCODESY_BLOCK_FILE_TYPES=.exe,.dll,.so
```

### 4. Network Security

- Egress filtering
- Domain whitelist
- Connection monitoring

```bash
STACKCODESY_EGRESS_FILTER=true
STACKCODESY_ALLOWED_DOMAINS=github.com,npmjs.org
```

### 5. Audit Logging

- Session tracking
- Command logging
- File operation logging
- Network connection logging

```bash
STACKCODESY_ENABLE_AUDIT_LOG=true
```

## 🚢 Deployment

### Development

```bash
docker-compose -f docker-compose.dev.yml up -d
```

**Configuration:**
- No authentication
- Full terminal access
- Full extension access
- No resource limits

### Staging

```bash
# Set environment variables
export STACKCODESY_USER_ID=user123
export STACKCODESY_AUTH_TOKEN=your-token
export STACKCODESY_AUTH_API=https://api.yourplatform.com/auth

docker-compose -f docker-compose.staging.yml up -d
```

**Configuration:**
- Authentication required
- Restricted terminal
- Whitelisted extensions
- 10GB disk quota
- Network filtering

### Production

```bash
# Set environment variables
export STACKCODESY_USER_ID=user123
export STACKCODESY_AUTH_TOKEN=your-token
export STACKCODESY_AUTH_API=https://api.yourplatform.com/auth
export STACKCODESY_SESSION_ID=$(uuidgen)

docker-compose -f docker-compose.prod.yml up -d
```

**Configuration:**
- Strict authentication
- Terminal disabled
- Strict extension whitelist
- 5GB disk quota
- No external network access
- Full audit logging

### Production with Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Create secrets
echo "https://api.yourplatform.com/auth" | docker secret create stackcodesy_auth_api -

# Deploy stack
docker stack deploy -c docker-compose.prod.yml stackcodesy

# Scale services
docker service scale stackcodesy_stackcodesy-prod=5

# View logs
docker service logs -f stackcodesy_stackcodesy-prod
```

## ⚙️ Configuration

### Environment Variables

#### Authentication
```bash
STACKCODESY_REQUIRE_AUTH=true|false
STACKCODESY_USER_ID=user-id
STACKCODESY_USER_NAME=user-name
STACKCODESY_USER_EMAIL=user@email.com
STACKCODESY_AUTH_TOKEN=jwt-token
STACKCODESY_AUTH_API=https://api.example.com/auth
```

#### Terminal Security
```bash
STACKCODESY_TERMINAL_MODE=disabled|restricted|full
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=ls,cd,git,npm
```

#### Extension Security
```bash
STACKCODESY_EXTENSION_MODE=disabled|whitelist|full
STACKCODESY_EXTENSION_WHITELIST=ext1,ext2,ext3
```

#### Filesystem Security
```bash
STACKCODESY_DISK_QUOTA_MB=5120
STACKCODESY_MAX_FILE_SIZE_MB=500
STACKCODESY_BLOCK_FILE_TYPES=.exe,.dll
STACKCODESY_ENABLE_FS_MONITORING=true|false
```

#### Network Security
```bash
STACKCODESY_EGRESS_FILTER=true|false
STACKCODESY_BLOCK_ALL_OUTBOUND=true|false
STACKCODESY_ALLOWED_DOMAINS=domain1,domain2
STACKCODESY_ALLOWED_PORTS=80,443
```

#### Logging
```bash
STACKCODESY_ENABLE_AUDIT_LOG=true|false
STACKCODESY_ENABLE_CSP=true|false
```

## 💻 Development

### Prerequisites

- Node.js 20+
- Docker 20+
- Docker Compose 2+
- Git

### Building from Source

```bash
# Clone VSCode
git clone --depth 1 --branch 1.95.3 https://github.com/microsoft/vscode.git vscode

# Install dependencies
cd vscode
npm ci --ignore-scripts
npm rebuild

# Apply branding
cd ..
./scripts/apply-branding.sh vscode

# Build vscode-reh-web
cd vscode
npm run gulp vscode-reh-web-linux-x64

# Build custom authentication extension
cd ../extensions/stackcodesy-auth
npm install
npm run compile
npm run package
```

### Running Locally

```bash
# Option 1: Docker (recommended)
docker-compose up -d --build

# Option 2: Local vscode-reh-web
cd vscode/vscode-reh-web-linux-x64
./server.sh --host 0.0.0.0 --port 8080
```

### Testing Security Features

```bash
# Test restricted terminal
export STACKCODESY_TERMINAL_MODE=restricted
export STACKCODESY_TERMINAL_ALLOWED_COMMANDS=ls,pwd,git
docker-compose up

# Test with authentication
export STACKCODESY_REQUIRE_AUTH=true
export STACKCODESY_AUTH_API=https://api.example.com/auth
docker-compose up
```

## 📚 Documentation

- [CONTEXT.md](CONTEXT.md) - Full project context and implementation history
- [SECURITY.md](SECURITY.md) - Detailed security documentation
- [docs/deployment.md](docs/deployment.md) - Complete deployment guide
- [docs/api-integration.md](docs/api-integration.md) - Authentication API integration
- [extensions/stackcodesy-auth/README.md](extensions/stackcodesy-auth/README.md) - Auth extension docs

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## 📝 License

Based on [VSCode](https://github.com/microsoft/vscode) (MIT License) with StackCodeSy enhancements.

## 🙏 Acknowledgments

- Microsoft VSCode team for the amazing editor
- Code-server project for inspiration on web deployment
- All contributors to this project

## 📧 Support

- 📖 Documentation: https://docs.stackcodesy.com
- 🐛 Issues: https://github.com/yourorg/StackCodeSy/issues
- 💬 Discussions: https://github.com/yourorg/StackCodeSy/discussions

---

**Made with ❤️ by the StackCodeSy Team**
