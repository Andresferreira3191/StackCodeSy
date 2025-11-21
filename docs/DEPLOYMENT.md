# StackCodeSy Deployment Guide

Complete guide for deploying StackCodeSy in different environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Build Process](#build-process)
3. [Local Development](#local-development)
4. [Staging Deployment](#staging-deployment)
5. [Production Deployment](#production-deployment)
6. [Docker Swarm Deployment](#docker-swarm-deployment)
7. [Kubernetes Deployment](#kubernetes-deployment)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

#### Development
- CPU: 2+ cores
- RAM: 4GB+
- Disk: 10GB+
- OS: Linux, macOS, or Windows (with WSL2)

#### Production
- CPU: 4+ cores
- RAM: 8GB+ (16GB+ recommended for compilation)
- Disk: 50GB+ SSD
- OS: Linux (Ubuntu 22.04+ or Debian 11+ recommended)

### Software Requirements

- **Docker**: 20.10+ ([Install Docker](https://docs.docker.com/get-docker/))
- **Docker Compose**: 2.0+ ([Install Compose](https://docs.docker.com/compose/install/))
- **Git**: 2.30+
- **Node.js**: 20+ (for local builds only)

### Optional but Recommended

- **Nginx** or **Caddy** for reverse proxy
- **Certbot** for SSL certificates
- **Fail2ban** for security
- **Prometheus** + **Grafana** for monitoring

## Build Process

### Option 1: Using GitHub Actions (Recommended)

The project includes a GitHub Actions workflow that automatically builds vscode-reh-web.

1. **Fork or push the repository to GitHub**
2. **Workflow triggers automatically** on push to `main` or `develop`
3. **Download artifacts** from the Actions tab
4. **Use in Docker** by placing tarballs in project root

### Option 2: Local Build

```bash
# 1. Clone VSCode
git clone --depth 1 --branch 1.95.3 https://github.com/microsoft/vscode.git vscode

# 2. Install dependencies
cd vscode
npm ci --ignore-scripts
npm rebuild

# 3. Apply branding (optional)
cd ..
./scripts/apply-branding.sh vscode

# 4. Build vscode-reh-web
cd vscode
npm run gulp vscode-reh-web-linux-x64

# 5. Create tarball
tar -czf ../vscode-reh-web-linux-x64.tar.gz \
  --transform 's,^vscode-reh-web-linux-x64,vscode-reh-web,' \
  vscode-reh-web-linux-x64/

# 6. Verify
ls -lh ../vscode-reh-web-linux-x64.tar.gz
```

**Note**: Building requires 8-16GB RAM and takes 15-30 minutes.

## Local Development

### Quick Start

```bash
# Clone repository
git clone https://github.com/yourorg/StackCodeSy.git
cd StackCodeSy

# Start development environment
docker-compose up -d --build

# View logs
docker-compose logs -f

# Access editor
open http://localhost:8889
```

### Development Configuration

The development environment (`docker-compose.dev.yml`) has:
- ✅ No authentication required
- ✅ Full terminal access
- ✅ Full extension marketplace
- ✅ No resource limits
- ✅ Live code reloading (via bind mounts)

### Stopping and Cleaning

```bash
# Stop containers
docker-compose down

# Remove volumes (clean slate)
docker-compose down -v

# Remove images
docker-compose down --rmi all
```

## Staging Deployment

### Step 1: Set Environment Variables

Create `.env.staging`:

```bash
# User identification
STACKCODESY_USER_ID=staging-user-123
STACKCODESY_USER_NAME=Staging User
STACKCODESY_USER_EMAIL=staging@example.com

# Authentication
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_AUTH_TOKEN=your-staging-token
STACKCODESY_AUTH_API=https://staging-api.yourplatform.com/auth

# Security settings
STACKCODESY_TERMINAL_MODE=restricted
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=ls,cd,pwd,cat,git,npm,node,python

STACKCODESY_EXTENSION_MODE=whitelist
STACKCODESY_EXTENSION_WHITELIST=dbaeumer.vscode-eslint,esbenp.prettier-vscode

# Resource limits
STACKCODESY_DISK_QUOTA_MB=10240
STACKCODESY_MAX_FILE_SIZE_MB=1000

# Network
STACKCODESY_EGRESS_FILTER=true
STACKCODESY_ALLOWED_DOMAINS=github.com,npmjs.org,pypi.org
```

### Step 2: Deploy

```bash
# Load environment
source .env.staging

# Deploy
docker-compose -f docker-compose.staging.yml up -d --build

# Check status
docker-compose -f docker-compose.staging.yml ps

# View logs
docker-compose -f docker-compose.staging.yml logs -f
```

### Step 3: Configure Reverse Proxy

#### Using Nginx

```nginx
# /etc/nginx/sites-available/stackcodesy-staging

server {
    listen 80;
    server_name staging.stackcodesy.example.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name staging.stackcodesy.example.com;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/staging.stackcodesy.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/staging.stackcodesy.example.com/privkey.pem;

    # Security headers
    include /etc/nginx/snippets/stackcodesy-security-headers.conf;

    # Proxy settings
    location / {
        proxy_pass http://localhost:8889;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=stackcodesy:10m rate=10r/s;
    limit_req zone=stackcodesy burst=20 nodelay;
}
```

Enable and reload:

```bash
sudo ln -s /etc/nginx/sites-available/stackcodesy-staging /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Production Deployment

### Step 1: Prepare Environment

Create `.env.production`:

```bash
# User identification (from your auth system)
STACKCODESY_USER_ID=${USER_ID}
STACKCODESY_USER_NAME=${USER_NAME}
STACKCODESY_USER_EMAIL=${USER_EMAIL}

# Authentication (REQUIRED)
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_AUTH_TOKEN=${AUTH_TOKEN}
STACKCODESY_AUTH_API=https://api.yourplatform.com/auth

# Session tracking
STACKCODESY_SESSION_ID=$(uuidgen)

# Maximum security
STACKCODESY_TERMINAL_MODE=disabled
STACKCODESY_EXTENSION_MODE=whitelist
STACKCODESY_EXTENSION_WHITELIST=dbaeumer.vscode-eslint,esbenp.prettier-vscode

# Strict resource limits
STACKCODESY_DISK_QUOTA_MB=5120
STACKCODESY_MAX_FILE_SIZE_MB=500

# No external network
STACKCODESY_BLOCK_ALL_OUTBOUND=true

# Full logging
STACKCODESY_ENABLE_AUDIT_LOG=true
STACKCODESY_ENABLE_CSP=true
```

### Step 2: Create Docker Secrets (if using Swarm)

```bash
# API endpoint
echo "https://api.yourplatform.com/auth" | \
  docker secret create stackcodesy_auth_api -

# Database password (if needed)
echo "your-secure-db-password" | \
  docker secret create stackcodesy_db_password -
```

### Step 3: Deploy

```bash
# Load environment
source .env.production

# Deploy
docker-compose -f docker-compose.prod.yml up -d

# Check status
docker-compose -f docker-compose.prod.yml ps

# Health check
curl -f http://localhost:8080/ || echo "Failed"
```

### Step 4: Production Reverse Proxy

#### Using Nginx with Let's Encrypt

```bash
# Install Certbot
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d editor.yourplatform.com

# Nginx config will be updated automatically
```

#### Using Caddy (Simpler)

```caddyfile
# /etc/caddy/Caddyfile

editor.yourplatform.com {
    reverse_proxy localhost:8080

    # Security headers
    header {
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
    }

    # Rate limiting
    rate_limit {
        zone stackcodesy {
            key {remote_host}
            events 10
            window 1s
        }
    }
}
```

## Docker Swarm Deployment

For high availability and scaling.

### Step 1: Initialize Swarm

```bash
# On manager node
docker swarm init --advertise-addr <MANAGER-IP>

# On worker nodes (run the command shown by swarm init)
docker swarm join --token <TOKEN> <MANAGER-IP>:2377
```

### Step 2: Create Overlay Network

```bash
docker network create \
  --driver overlay \
  --attachable \
  stackcodesy-network
```

### Step 3: Deploy Stack

```bash
# Deploy
docker stack deploy -c docker-compose.prod.yml stackcodesy

# List services
docker stack services stackcodesy

# Scale service
docker service scale stackcodesy_stackcodesy-prod=5

# View logs
docker service logs -f stackcodesy_stackcodesy-prod

# Update service
docker service update \
  --image stackcodesy:v2.0.0 \
  stackcodesy_stackcodesy-prod
```

### Step 4: Load Balancing

```nginx
# Nginx load balancer config

upstream stackcodesy_backend {
    least_conn;

    server swarm-node-1:8080 max_fails=3 fail_timeout=30s;
    server swarm-node-2:8080 max_fails=3 fail_timeout=30s;
    server swarm-node-3:8080 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name editor.yourplatform.com;

    # SSL config...

    location / {
        proxy_pass http://stackcodesy_backend;
        # proxy settings...
    }
}
```

## Monitoring and Logging

### Prometheus Metrics

Add to `docker-compose.prod.yml`:

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana-data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=secure-password
```

### Log Aggregation

Using Loki:

```yaml
services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./monitoring/loki-config.yml:/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log
      - ./monitoring/promtail-config.yml:/etc/promtail/config.yml
```

### Alerts

Example alert rules (`prometheus-alerts.yml`):

```yaml
groups:
  - name: stackcodesy
    rules:
      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{name="stackcodesy-prod"} > 1.5e9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage in StackCodeSy container"

      - alert: ContainerDown
        expr: up{job="stackcodesy"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "StackCodeSy container is down"
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs stackcodesy

# Common issues:
# 1. Missing vscode-reh-web tarball
# 2. Port 8080 already in use
# 3. Insufficient memory

# Fix: Check if tarball exists
ls -lh vscode-reh-web-*.tar.gz

# Fix: Check port
sudo lsof -i :8080
```

### Authentication Failures

```bash
# Check environment variables
docker-compose exec stackcodesy env | grep STACKCODESY

# Test auth API
curl -X POST https://api.yourplatform.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'

# Check logs
docker-compose logs | grep -i auth
```

### Performance Issues

```bash
# Check resource usage
docker stats stackcodesy-prod

# Check disk usage
docker exec stackcodesy-prod df -h

# Check for disk quota
docker exec stackcodesy-prod /usr/local/bin/check-disk-quota
```

### Network Issues

```bash
# Check network connectivity
docker exec stackcodesy-prod ping -c 3 github.com

# Check iptables rules
docker exec stackcodesy-prod iptables -L -n

# Check DNS
docker exec stackcodesy-prod nslookup github.com
```

### Security Audit

```bash
# View audit logs
docker exec stackcodesy-prod tail -f /var/log/stackcodesy/audit.log

# Check security configuration
docker exec stackcodesy-prod cat /tmp/stackcodesy-terminal-security.log
docker exec stackcodesy-prod cat /tmp/stackcodesy-extension-security.log
```

## Backup and Recovery

### Backup Workspace

```bash
# Backup user workspace
docker run --rm \
  -v stackcodesy-workspace:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/workspace-backup-$(date +%Y%m%d).tar.gz /data
```

### Restore Workspace

```bash
# Restore user workspace
docker run --rm \
  -v stackcodesy-workspace:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/workspace-backup-20231201.tar.gz -C /
```

## Scaling Considerations

### Horizontal Scaling

- Use Docker Swarm or Kubernetes
- Implement session affinity (sticky sessions)
- Use shared storage for workspaces (NFS, Ceph, etc.)

### Vertical Scaling

- Increase CPU/memory limits in docker-compose
- Use dedicated instances for power users
- Consider GPU instances for ML workloads

## Security Best Practices

1. **Always use HTTPS** in production
2. **Enable audit logging** for compliance
3. **Regularly update** base images and VSCode
4. **Scan images** for vulnerabilities
5. **Use secrets management** (Vault, Docker secrets)
6. **Implement rate limiting** at reverse proxy
7. **Enable fail2ban** for brute force protection
8. **Monitor audit logs** for suspicious activity

## Next Steps

- Set up monitoring with Prometheus + Grafana
- Configure automated backups
- Implement CI/CD pipeline
- Set up log aggregation
- Configure automated security scanning
- Create runbooks for common issues

---

For more information, see:
- [Main README](../README.md)
- [Security Documentation](../SECURITY.md)
- [Context and History](../CONTEXT.md)
