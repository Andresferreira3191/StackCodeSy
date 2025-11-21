# StackCodeSy - Additional Security Hardening Guide

## Overview

This guide covers additional security measures beyond the core features already implemented (authentication, terminal control, Docker Swarm). These are optional but **highly recommended** for production environments.

---

## Table of Contents

1. [Extension Marketplace Security](#extension-marketplace-security)
2. [File System Security](#file-system-security)
3. [Network Security Controls](#network-security-controls)
4. [Resource Quotas and Rate Limiting](#resource-quotas-and-rate-limiting)
5. [Audit Logging and Monitoring](#audit-logging-and-monitoring)
6. [Secrets Management](#secrets-management)
7. [Container Image Security](#container-image-security)
8. [Runtime Protection (AppArmor/SELinux)](#runtime-protection)
9. [Content Security Policy](#content-security-policy)
10. [DDoS Protection](#ddos-protection)

---

## 1. Extension Marketplace Security

### Risk Level: 🔴 CRITICAL

**Problem:** Users can install malicious extensions that execute arbitrary code.

### Solution 1: Disable Extension Marketplace Completely

**Implementation:**

Create `resources/server/web/security/disable-marketplace.sh`:

```bash
#!/bin/bash
# Disable VSCode extension marketplace

CONFIG_DIR="/home/stackcodesy/.stackcodesy/User"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

mkdir -p "$CONFIG_DIR"

# Append to settings
jq '. + {
  "extensions.autoCheckUpdates": false,
  "extensions.autoUpdate": false,
  "extensions.ignoreRecommendations": true,
  "extensions.showRecommendationsOnlyOnDemand": true,
  "workbench.enableExperiments": false
}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "Extension marketplace disabled"
```

**Update `product.json`:**

```json
{
  "extensionsGallery": {
    "serviceUrl": "",
    "itemUrl": "",
    "controlUrl": "",
    "recommendationsUrl": ""
  }
}
```

### Solution 2: Private Extension Registry

**For organizations that need extensions:**

```yaml
# docker-compose.yml
services:
  stackcodesy:
    environment:
      # Point to your private extension registry
      - VSCODE_GALLERY_SERVICE_URL=https://extensions.yourcompany.com/api
      - VSCODE_GALLERY_ITEM_URL=https://extensions.yourcompany.com/item
```

**Whitelist approved extensions only:**

```bash
# Create whitelist
APPROVED_EXTENSIONS="dbaeumer.vscode-eslint,esbenp.prettier-vscode,ms-python.python"

# Block installation of non-approved extensions
# This requires modifying extension installation logic
```

### Solution 3: Environment Variable Control

**Add to configuration:**

```yaml
# New environment variable
- STACKCODESY_DISABLE_EXTENSIONS=${STACKCODESY_DISABLE_EXTENSIONS:-false}

# When true:
# - Disables extension marketplace
# - Prevents extension installation
# - Only built-in extensions available
```

---

## 2. File System Security

### Risk Level: 🟡 HIGH

### 2.1 Disk Quotas

**Prevent users from filling disk:**

```yaml
# docker-compose.yml
services:
  stackcodesy:
    volumes:
      - type: volume
        source: stackcodesy-workspace
        target: /workspace
        volume:
          nocopy: true

volumes:
  stackcodesy-workspace:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
      o: size=5G,uid=1000,gid=1000  # 5GB max
```

**Or use storage driver limits:**

```yaml
services:
  stackcodesy:
    storage_opt:
      size: '10G'  # Maximum 10GB per container
```

### 2.2 Read-Only Sensitive Directories

```yaml
services:
  stackcodesy:
    volumes:
      # Read-only system directories
      - /etc/ssl:/etc/ssl:ro
      - /etc/ca-certificates:/etc/ca-certificates:ro

      # Writable workspace
      - stackcodesy-workspace:/workspace:rw

      # Writable temp (with size limit)
    tmpfs:
      - /tmp:size=1G,mode=1777
      - /home/stackcodesy/.stackcodesy:size=500M,mode=0755
```

### 2.3 File Type Restrictions

**Block executable uploads:**

```bash
#!/bin/bash
# resources/server/web/security/file-monitor.sh

# Monitor for suspicious file types
inotifywait -m -r -e create,modify /workspace |
while read path action file; do
    # Block executable files
    if [[ "$file" =~ \.(exe|sh|bin|elf)$ ]]; then
        echo "[SECURITY] Blocked executable file: $file"
        rm -f "$path$file"
    fi

    # Block scripts with shebang
    if head -n 1 "$path$file" | grep -q '^#!'; then
        if [[ ! "$file" =~ \.(js|py|rb)$ ]]; then
            echo "[SECURITY] Blocked script file: $file"
            rm -f "$path$file"
        fi
    fi
done
```

### 2.4 Filesystem Monitoring

```yaml
# Add environment variable
- STACKCODESY_MONITOR_FILESYSTEM=${STACKCODESY_MONITOR_FILESYSTEM:-false}

# When enabled:
# - Monitors file creation/modification
# - Blocks suspicious files
# - Logs all file operations
```

---

## 3. Network Security Controls

### Risk Level: 🟡 HIGH

### 3.1 Egress Filtering (Firewall Rules)

**Block all outbound except approved:**

```bash
#!/bin/bash
# resources/server/web/security/setup-firewall.sh

# Default: DROP all outbound
iptables -P OUTPUT DROP

# Allow DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow HTTPS to specific domains (npm registry, github, etc.)
iptables -A OUTPUT -p tcp --dport 443 -d registry.npmjs.org -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -d github.com -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -d raw.githubusercontent.com -j ACCEPT

# Allow established connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Log blocked attempts
iptables -A OUTPUT -j LOG --log-prefix "BLOCKED_OUTBOUND: "

echo "Firewall rules applied"
```

### 3.2 Domain Whitelist

```yaml
# Environment variable
- STACKCODESY_ALLOWED_DOMAINS=${STACKCODESY_ALLOWED_DOMAINS:-registry.npmjs.org,github.com,pypi.org}

# Implement in restricted shell
if [ "$BLOCK_NETWORK" = "true" ]; then
    # Block all wget/curl
    BLOCKED_COMMANDS="$BLOCKED_COMMANDS,wget,curl,nc,telnet,ssh"
fi
```

### 3.3 Network Namespace Isolation

```yaml
# docker-compose.yml
services:
  stackcodesy:
    networks:
      stackcodesy-internal:
        internal: true  # No external internet access

  # Proxy service for controlled external access
  proxy:
    image: squid:latest
    networks:
      - stackcodesy-internal
      - external

networks:
  stackcodesy-internal:
    internal: true
  external:
```

### 3.4 DNS Filtering

```yaml
services:
  stackcodesy:
    dns:
      - 1.1.1.2  # Cloudflare malware blocking DNS
      - 1.0.0.2
    dns_search:
      - yourcompany.internal
```

---

## 4. Resource Quotas and Rate Limiting

### Risk Level: 🟡 MEDIUM

### 4.1 CPU and Memory Hard Limits

```yaml
services:
  stackcodesy:
    deploy:
      resources:
        limits:
          cpus: '1.0'      # Max 1 CPU core
          memory: 2G       # Max 2GB RAM
          pids: 100        # Max 100 processes
        reservations:
          cpus: '0.25'
          memory: 512M

    # Additional ulimits
    ulimits:
      nproc: 100           # Max processes
      nofile:
        soft: 1024         # Max open files
        hard: 2048
      cpu: 60              # Max CPU time (seconds)
      fsize: 1073741824    # Max file size (1GB)
```

### 4.2 I/O Limits

```yaml
services:
  stackcodesy:
    # Block I/O limits
    blkio_config:
      weight: 500                    # I/O priority (100-1000)
      weight_device:
        - path: /dev/sda
          weight: 400
      device_read_bps:
        - path: /dev/sda
          rate: '50mb'               # Max read 50MB/s
      device_write_bps:
        - path: /dev/sda
          rate: '25mb'               # Max write 25MB/s
```

### 4.3 Request Rate Limiting (Nginx)

```nginx
# nginx.conf
http {
    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=editor_login:10m rate=5r/s;
    limit_req_zone $binary_remote_addr zone=editor_api:10m rate=30r/s;
    limit_req_zone $binary_remote_addr zone=editor_ws:10m rate=50r/s;

    # Connection limits
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    server {
        # Login endpoint
        location /api/auth {
            limit_req zone=editor_login burst=10 nodelay;
            proxy_pass http://stackcodesy:8080;
        }

        # API endpoints
        location /api/ {
            limit_req zone=editor_api burst=50;
            proxy_pass http://stackcodesy:8080;
        }

        # WebSocket
        location /ws {
            limit_req zone=editor_ws burst=100;
            limit_conn addr 10;  # Max 10 connections per IP

            proxy_pass http://stackcodesy:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Rate limit exceeded response
        error_page 429 /rate_limit.html;
    }
}
```

### 4.4 Per-User Resource Tracking

```bash
#!/bin/bash
# Monitor per-user resource usage

USER_ID="$STACKCODESY_USER_ID"
CONTAINER_ID=$(hostname)

# Check CPU usage
CPU_USAGE=$(ps aux | awk '{sum+=$3} END {print sum}')
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "[WARNING] User $USER_ID high CPU usage: $CPU_USAGE%"
    # Could throttle or alert
fi

# Check memory usage
MEM_USAGE=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -gt 85 ]; then
    echo "[WARNING] User $USER_ID high memory usage: $MEM_USAGE%"
fi

# Check disk usage
DISK_USAGE=$(df /workspace | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "[CRITICAL] User $USER_ID disk quota exceeded: $DISK_USAGE%"
fi
```

---

## 5. Audit Logging and Monitoring

### Risk Level: 🟡 MEDIUM (Essential for compliance)

### 5.1 Comprehensive Audit Logging

```bash
#!/bin/bash
# resources/server/web/security/audit-logger.sh

AUDIT_LOG="/var/log/stackcodesy/audit.log"
USER_ID="${STACKCODESY_USER_ID}"
SESSION_ID="${STACKCODESY_SESSION_ID:-$(uuidgen)}"

log_event() {
    local event_type="$1"
    local event_data="$2"

    echo "$(date -Iseconds)|$USER_ID|$SESSION_ID|$event_type|$event_data" >> "$AUDIT_LOG"
}

# Log session start
log_event "SESSION_START" "User logged in"

# Log terminal commands (if enabled)
if [ "$STACKCODESY_TERMINAL_MODE" != "disabled" ]; then
    # Hook into bash history
    export PROMPT_COMMAND='log_event "TERMINAL_CMD" "$(history 1 | sed "s/^[ ]*[0-9]*[ ]*//")"'
fi

# Log file operations
inotifywait -m -r -e create,modify,delete /workspace --format '%e|%w%f' |
while IFS='|' read event file; do
    log_event "FILE_$event" "$file"
done &

# Log network connections
netstat -tunapl | grep ESTABLISHED |
while read line; do
    log_event "NETWORK_CONNECTION" "$line"
done &
```

### 5.2 Centralized Logging (ELK Stack)

```yaml
# docker-compose.yml
services:
  stackcodesy:
    logging:
      driver: "fluentd"
      options:
        fluentd-address: "logs.yourcompany.com:24224"
        tag: "stackcodesy.{{.Name}}"
        labels: "user_id,session_id"

    labels:
      user_id: "${STACKCODESY_USER_ID}"
      session_id: "${STACKCODESY_SESSION_ID}"
```

### 5.3 Security Event Alerts

```bash
#!/bin/bash
# Monitor security log and send alerts

tail -f /tmp/stackcodesy-terminal-security.log |
while read line; do
    if echo "$line" | grep -q "BLOCKED"; then
        # Send alert (Slack, email, webhook)
        curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"🚨 Security Alert: $line\"}"
    fi
done
```

---

## 6. Secrets Management

### Risk Level: 🔴 CRITICAL

### 6.1 Docker Secrets (Swarm)

```bash
# Create secrets
echo "https://api.yourplatform.com/auth" | docker secret create stackcodesy_auth_api -
echo "your-db-password" | docker secret create stackcodesy_db_password -

# Use in compose
services:
  stackcodesy:
    secrets:
      - stackcodesy_auth_api
      - stackcodesy_db_password
    environment:
      # Reference secrets via files
      - STACKCODESY_AUTH_API_FILE=/run/secrets/stackcodesy_auth_api

secrets:
  stackcodesy_auth_api:
    external: true
  stackcodesy_db_password:
    external: true
```

### 6.2 Vault Integration

```yaml
services:
  stackcodesy:
    environment:
      - VAULT_ADDR=https://vault.yourcompany.com
      - VAULT_TOKEN_FILE=/run/secrets/vault_token

    # Use vault agent for secret injection
    volumes:
      - vault-agent-config:/vault/config
```

### 6.3 Environment Variable Filtering

```bash
#!/bin/bash
# Filter sensitive env vars from logs

# Redact passwords, tokens, keys
filter_env() {
    env | grep -v -i 'password\|token\|secret\|key\|auth' | sort
}

# Use in logging
filter_env >> /var/log/stackcodesy/startup.log
```

---

## 7. Container Image Security

### Risk Level: 🟡 HIGH

### 7.1 Image Scanning

```bash
# Scan image for vulnerabilities
docker scan stackcodesy:latest

# Or use Trivy
trivy image stackcodesy:latest

# Fail build if critical vulnerabilities found
trivy image --severity CRITICAL,HIGH --exit-code 1 stackcodesy:latest
```

### 7.2 Multi-Stage Build Hardening

```dockerfile
# Minimize attack surface
FROM node:22.20.0-bookworm-slim AS production

# Remove unnecessary packages
RUN apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* /var/tmp/*

# Remove package manager to prevent runtime installs
RUN rm -f /usr/bin/apt /usr/bin/apt-get /usr/bin/dpkg
```

### 7.3 Image Signing (Docker Content Trust)

```bash
# Enable DCT
export DOCKER_CONTENT_TRUST=1

# Build and push signed image
docker build -t stackcodesy:latest .
docker push stackcodesy:latest

# Verify signatures on pull
docker pull stackcodesy:latest
```

### 7.4 Base Image Verification

```dockerfile
# Use official images with digest
FROM node:22.20.0-bookworm-slim@sha256:abc123...

# Verify checksum
RUN echo "expected-checksum  /path/to/file" | sha256sum -c -
```

---

## 8. Runtime Protection

### Risk Level: 🟡 HIGH

### 8.1 AppArmor Profile

Create `stackcodesy-apparmor-profile`:

```
#include <tunables/global>

profile stackcodesy flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Allow network
  network inet tcp,
  network inet udp,

  # Deny dangerous capabilities
  deny capability sys_admin,
  deny capability sys_module,
  deny capability sys_rawio,

  # Allow only necessary files
  /workspace/** rw,
  /home/stackcodesy/.stackcodesy/** rw,
  /tmp/** rw,
  /usr/bin/** ix,
  /usr/lib/** mr,

  # Deny sensitive paths
  deny /etc/shadow r,
  deny /etc/passwd w,
  deny /root/** rw,
}
```

**Use in Docker:**

```yaml
services:
  stackcodesy:
    security_opt:
      - apparmor=stackcodesy-apparmor-profile
```

### 8.2 Seccomp Profile

Create `stackcodesy-seccomp.json`:

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close", "stat",
        "fstat", "lstat", "poll", "lseek", "mmap",
        "mprotect", "munmap", "brk", "rt_sigaction",
        "rt_sigprocmask", "rt_sigreturn", "ioctl",
        "pread64", "pwrite64", "readv", "writev",
        "access", "pipe", "select", "sched_yield",
        "mremap", "msync", "mincore", "madvise",
        "shmget", "shmat", "shmctl", "dup", "dup2",
        "pause", "nanosleep", "getitimer", "alarm",
        "setitimer", "getpid", "sendfile", "socket",
        "connect", "accept", "sendto", "recvfrom",
        "sendmsg", "recvmsg", "shutdown", "bind",
        "listen", "getsockname", "getpeername",
        "socketpair", "setsockopt", "getsockopt",
        "clone", "fork", "vfork", "execve", "exit",
        "wait4", "kill", "uname", "fcntl", "flock",
        "fsync", "fdatasync", "truncate", "ftruncate",
        "getdents", "getcwd", "chdir", "fchdir",
        "rename", "mkdir", "rmdir", "creat", "link",
        "unlink", "symlink", "readlink", "chmod",
        "fchmod", "chown", "fchown", "lchown", "umask",
        "gettimeofday", "getrlimit", "getrusage",
        "sysinfo", "times", "ptrace", "getuid",
        "syslog", "getgid", "setuid", "setgid",
        "geteuid", "getegid", "setpgid", "getppid",
        "getpgrp", "setsid", "setreuid", "setregid",
        "getgroups", "setgroups", "setresuid",
        "getresuid", "setresgid", "getresgid",
        "getpgid", "setfsuid", "setfsgid", "getsid",
        "capget", "capset", "rt_sigpending",
        "rt_sigtimedwait", "rt_sigqueueinfo",
        "rt_sigsuspend", "sigaltstack", "utime",
        "mknod", "uselib", "personality", "ustat",
        "statfs", "fstatfs", "sysfs", "getpriority",
        "setpriority", "sched_setparam",
        "sched_getparam", "sched_setscheduler",
        "sched_getscheduler", "sched_get_priority_max",
        "sched_get_priority_min", "sched_rr_get_interval",
        "mlock", "munlock", "mlockall", "munlockall",
        "vhangup", "modify_ldt", "pivot_root",
        "_sysctl", "prctl", "arch_prctl", "adjtimex",
        "setrlimit", "chroot", "sync", "acct",
        "settimeofday", "mount", "umount2", "swapon",
        "swapoff", "reboot", "sethostname",
        "setdomainname", "iopl", "ioperm",
        "create_module", "init_module", "delete_module",
        "get_kernel_syms", "query_module", "quotactl",
        "nfsservctl", "getpmsg", "putpmsg", "afs_syscall",
        "tuxcall", "security", "gettid", "readahead",
        "setxattr", "lsetxattr", "fsetxattr", "getxattr",
        "lgetxattr", "fgetxattr", "listxattr",
        "llistxattr", "flistxattr", "removexattr",
        "lremovexattr", "fremovexattr", "tkill",
        "time", "futex", "sched_setaffinity",
        "sched_getaffinity", "set_thread_area",
        "io_setup", "io_destroy", "io_getevents",
        "io_submit", "io_cancel", "get_thread_area",
        "lookup_dcookie", "epoll_create", "epoll_ctl_old",
        "epoll_wait_old", "remap_file_pages", "getdents64",
        "set_tid_address", "restart_syscall", "semtimedop",
        "fadvise64", "timer_create", "timer_settime",
        "timer_gettime", "timer_getoverrun", "timer_delete",
        "clock_settime", "clock_gettime", "clock_getres",
        "clock_nanosleep", "exit_group", "epoll_wait",
        "epoll_ctl", "tgkill", "utimes", "vserver",
        "mbind", "set_mempolicy", "get_mempolicy",
        "mq_open", "mq_unlink", "mq_timedsend",
        "mq_timedreceive", "mq_notify", "mq_getsetattr",
        "kexec_load", "waitid", "add_key", "request_key",
        "keyctl", "ioprio_set", "ioprio_get", "inotify_init",
        "inotify_add_watch", "inotify_rm_watch", "migrate_pages",
        "openat", "mkdirat", "mknodat", "fchownat",
        "futimesat", "newfstatat", "unlinkat", "renameat",
        "linkat", "symlinkat", "readlinkat", "fchmodat",
        "faccessat", "pselect6", "ppoll", "unshare",
        "set_robust_list", "get_robust_list", "splice",
        "tee", "sync_file_range", "vmsplice", "move_pages",
        "utimensat", "epoll_pwait", "signalfd", "timerfd_create",
        "eventfd", "fallocate", "timerfd_settime",
        "timerfd_gettime", "accept4", "signalfd4", "eventfd2",
        "epoll_create1", "dup3", "pipe2", "inotify_init1",
        "preadv", "pwritev", "rt_tgsigqueueinfo",
        "perf_event_open", "recvmmsg", "fanotify_init",
        "fanotify_mark", "prlimit64", "name_to_handle_at",
        "open_by_handle_at", "clock_adjtime", "syncfs",
        "sendmmsg", "setns", "getcpu", "process_vm_readv",
        "process_vm_writev", "kcmp", "finit_module",
        "sched_setattr", "sched_getattr", "renameat2",
        "seccomp", "getrandom", "memfd_create", "kexec_file_load",
        "bpf", "execveat", "userfaultfd", "membarrier",
        "mlock2", "copy_file_range", "preadv2", "pwritev2"
      ],
      "action": "SCMP_ACT_ALLOW"
    },
    {
      "names": ["mount", "umount2", "reboot", "swapon", "swapoff"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

**Use in Docker:**

```yaml
services:
  stackcodesy:
    security_opt:
      - seccomp=./stackcodesy-seccomp.json
```

---

## 9. Content Security Policy

### Risk Level: 🟡 MEDIUM

### 9.1 HTTP Security Headers

```nginx
# nginx.conf
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' wss: https:; frame-ancestors 'none';" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

---

## 10. DDoS Protection

### Risk Level: 🟡 MEDIUM

### 10.1 Cloudflare Integration

```yaml
# Use Cloudflare in front of your service
# Benefits:
# - DDoS protection
# - WAF (Web Application Firewall)
# - Bot mitigation
# - Rate limiting
# - Caching
```

### 10.2 Fail2Ban

```bash
# Monitor failed authentication attempts
# /etc/fail2ban/jail.d/stackcodesy.conf

[stackcodesy-auth]
enabled = true
port = 8080
filter = stackcodesy-auth
logpath = /var/log/stackcodesy/access.log
maxretry = 5
bantime = 3600
findtime = 600
```

---

## Implementation Priority

### 🔴 CRITICAL (Implement First)

1. **Extension Marketplace Security** - Disable or restrict
2. **Secrets Management** - Never store secrets in env vars
3. **Image Scanning** - Scan for vulnerabilities before deployment

### 🟡 HIGH (Implement Soon)

4. **Network Egress Filtering** - Control outbound connections
5. **Resource Quotas** - Prevent resource exhaustion
6. **Audit Logging** - Track all user actions

### 🟢 MEDIUM (Implement Later)

7. **AppArmor/Seccomp** - Runtime protection
8. **Content Security Policy** - Browser security
9. **DDoS Protection** - Infrastructure protection

---

## Quick Implementation Script

```bash
#!/bin/bash
# quick-security-hardening.sh

# 1. Disable extension marketplace
sed -i 's/"extensionsGallery": {/"extensionsGallery": {"serviceUrl": "","itemUrl": "","controlUrl": "",/' product.json

# 2. Apply resource limits
cat >> docker-compose.yml <<EOF
    ulimits:
      nproc: 100
      nofile: 1024
      fsize: 1073741824
EOF

# 3. Enable audit logging
mkdir -p /var/log/stackcodesy
chmod 755 /var/log/stackcodesy

# 4. Apply firewall rules
./resources/server/web/security/setup-firewall.sh

# 5. Scan image
trivy image stackcodesy:latest

echo "Basic hardening complete!"
```

---

## Monitoring Checklist

```
Daily:
- [ ] Review audit logs
- [ ] Check resource usage
- [ ] Verify no security alerts

Weekly:
- [ ] Scan images for vulnerabilities
- [ ] Review blocked command attempts
- [ ] Check firewall logs

Monthly:
- [ ] Update base images
- [ ] Review security policies
- [ ] Penetration testing
```

---

## Additional Resources

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Container Security](https://owasp.org/www-project-docker-top-10/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

---

**See also:**
- [SECURITY_REPORT.md](SECURITY_REPORT.md) - Core security analysis
- [DOCKER_SWARM_DEPLOYMENT.md](DOCKER_SWARM_DEPLOYMENT.md) - Deployment guide
