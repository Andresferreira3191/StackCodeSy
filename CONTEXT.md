# StackCodeSy - Documento de Contexto

## Fecha de Inicio
2025-11-21

## Objetivo del Proyecto

Crear **StackCodeSy**, un fork personalizado de VSCode web con:

### Funcionalidades Core Requeridas
1. **Editor VSCode Web** - Última versión (1.107.0) ejecutándose en navegador
2. **Puerto configurable** - Puerto 8889 (externo) → 8080 (interno)
3. **Autenticación custom** - Sistema de autenticación integrado con plataforma existente
4. **Branding personalizado** - StackCodeSy en lugar de VSCode
5. **Despliegue Docker** - Contenedores para diferentes entornos
6. **Soporte multi-arquitectura** - AMD64 y ARM64 (Mac M1/M2/M3)

### Funcionalidades de Seguridad Implementadas

#### 1. Control de Terminal (3 modos)
- **Disabled**: Terminal completamente deshabilitado
- **Restricted**: Terminal con comandos limitados (whitelist)
- **Full**: Acceso completo al terminal (modo desarrollo)

Archivos: `resources/server/web/security/terminal-security.sh`

#### 2. Control de Extensions Marketplace
- **Disabled**: Sin acceso al marketplace
- **Whitelist**: Solo extensiones aprobadas
- **Full**: Acceso completo al marketplace oficial

Archivos: `resources/server/web/security/extension-marketplace.sh`

#### 3. Seguridad de Sistema de Archivos
- **Disk Quotas**: Límite de espacio en disco por usuario
- **File Size Limits**: Tamaño máximo de archivo
- **Blocked File Types**: Bloqueo de extensiones peligrosas (.exe, .dll, etc.)
- **File System Monitoring**: Monitoreo de cambios en tiempo real

Archivos: `resources/server/web/security/filesystem-security.sh`

#### 4. Seguridad de Red
- **Egress Filtering**: Control de tráfico saliente
- **Domain Whitelist**: Solo dominios permitidos
- **Port Restrictions**: Control de puertos permitidos
- **Block All Outbound**: Modo sin conexión externa

Archivos: `resources/server/web/security/network-security.sh`

#### 5. Audit Logging
- Sistema de logging de todas las acciones
- Registros de: autenticación, terminal, cambios de archivos, instalación de extensiones

Archivos: `resources/server/web/security/audit-log.sh`

#### 6. Content Security Policy (CSP)
- Headers de seguridad HTTP
- Protección contra XSS y clickjacking

Archivos: `resources/server/web/security/csp-config.sh`

### Entrypoint de Seguridad
`resources/server/web/security/entrypoint.sh` - Orquesta todos los sistemas de seguridad

### Configuraciones de Entorno

#### Docker Compose para Desarrollo (`docker-compose.dev.yml`)
```yaml
STACKCODESY_REQUIRE_AUTH=false
STACKCODESY_TERMINAL_MODE=full
STACKCODESY_EXTENSION_MODE=full
STACKCODESY_DISK_QUOTA_MB=0  # Sin límite
STACKCODESY_EGRESS_FILTER=false
```

#### Docker Compose para Staging (`docker-compose.staging.yml`)
```yaml
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_TERMINAL_MODE=restricted
STACKCODESY_EXTENSION_MODE=whitelist
STACKCODESY_DISK_QUOTA_MB=10240  # 10GB
STACKCODESY_EGRESS_FILTER=true
```

#### Docker Compose para Production (`docker-compose.prod.yml`)
```yaml
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_TERMINAL_MODE=disabled
STACKCODESY_EXTENSION_MODE=whitelist
STACKCODESY_DISK_QUOTA_MB=5120  # 5GB
STACKCODESY_EGRESS_FILTER=true
STACKCODESY_BLOCK_ALL_OUTBOUND=true
```

---

## Extensión de Autenticación Custom

### Ubicación
`extensions/stackcodesy-auth/`

### Funcionalidad
- Implementa `AuthenticationProvider` de VSCode
- Integración con API de autenticación externa (sin JWT)
- Sistema de tokens custom
- Validación de sesión en tiempo real

### Archivos Principales
- `package.json` - Configuración de la extensión
- `src/extension.ts` - Lógica de autenticación
- `tsconfig.json` - Configuración TypeScript

### Problemas Resueltos
1. **Error de versión**: VSCode @types 1.107.0 no disponible → bajado a 1.106.0
2. **TypeScript errors**: Signature de `getSessions()` incorrecta → agregado parámetro `options`
3. **Type assertions**: Datos de API con tipo `unknown` → agregados type assertions

---

## Intentos de Implementación del Servidor Web

### ❌ Intento 1: @vscode/test-web (Desarrollo)
**Approach**: Usar el servidor de desarrollo de VSCode

**Problema**: 404 errors para archivos del workbench
- `/out/vs/code/browser/workbench/workbench.css` → 404
- `/out/nls.messages.js` → 404

**Razón del fallo**: @vscode/test-web está diseñado para desarrollo local, no para Docker en producción

**Archivos**: `scripts/code-web.sh`, `scripts/code-web.js`

---

### ❌ Intento 2: Servidor Express Custom con Pre-compilación
**Approach**: Crear servidor Express custom que sirva archivos pre-compilados

**Pasos intentados**:
1. Compilar con `gulp compile` → Falló
2. Compilar con `gulp compile-client` → Falló
3. Compilar con `gulp compile-web` → Falló
4. Compilar con `gulp compile-client compile-web compile-extension-media` → Falló

**Problemas encontrados**:
- Missing dependencies: `esbuild`, `morphdom`, `lodash.throttle`
- Invalid glob arguments en algunos tasks
- Directorios `/stackcodesy/out/` nunca se generaban
- Extensiones sin archivos `dist/`

**Archivos**:
- `scripts/code-web-prod.js` - Servidor Express custom
- `scripts/code-web-prod.sh` - Launcher
- `Dockerfile` (versión con multi-stage build)

---

### ❌ Intento 3: vscode-reh-web (Servidor Oficial de Producción)
**Approach**: Compilar `vscode-reh-web` - el servidor oficial de VSCode para web

**Descubrimiento**: Code-server usa este approach
- `vscode-reh-web` = Remote Extension Host for Web
- Es el mismo servidor que usa vscode.dev
- Servidor oficial de Microsoft para producción

**Problema 1 - Instalación de Dependencias**:
```
Error: spawnSync /bin/sh ENOENT
npm postinstall failed
```

**Solución**: Usar `--ignore-scripts` para omitir postinstall

**Problema 2 - Compilación en Docker**:
```
ResourceExhausted: cannot allocate memory
Killed
```

**Razón**: Compilar VSCode requiere 8-16GB de RAM. Docker no tiene suficiente.

**Archivos**:
- `Dockerfile.rehweb` - Docker que compila vscode-reh-web
- `docker-compose.rehweb.yml` - Compose para rehweb

---

### ❌ Intento 4: Pre-compilar Fuera de Docker
**Approach**: Compilar vscode-reh-web en el HOST, luego copiar binarios a Docker

**Inspiración**: Code-server hace exactamente esto:
1. Compilan en CI/CD (no en Docker)
2. Crean paquetes .deb
3. Docker solo instala los paquetes

**Script creado**: `build-vscode-web.sh`

**Problemas encontrados en Mac**:
1. Node.js v24 (VSCode requiere v22)
2. C++20 compiler errors en tree-sitter
3. Directorios `remote/`, `extensions/` no encontrados (error en el script)
4. Script npm `download-builtin-extensions` no existe (es un gulp task)

**Archivos**:
- `build-vscode-web.sh` - Script de compilación local
- `Dockerfile.prebuilt` - Docker que copia binarios pre-compilados
- `docker-compose.prebuilt.yml` - Compose para prebuilt
- `BUILD.md` - Instrucciones (incompletas/no funcionales)

---

## Archivos Dockerfile Creados

### 1. `Dockerfile` (Multi-stage con compilación)
**Estado**: ❌ No funciona - problemas de memoria

**Características**:
- Builder stage: Compila VSCode
- Production stage: Copia solo lo necesario
- Intenta compilar `gulp compile-client`

### 2. `Dockerfile.simple` (Single-stage)
**Estado**: ❌ No funciona - mismo problema npm postinstall

**Características**:
- Sin multi-stage
- Usa @vscode/test-web
- Single stage más simple

### 3. `Dockerfile.rehweb` (Compilación vscode-reh-web)
**Estado**: ❌ No funciona - out of memory

**Características**:
- Compila vscode-reh-web-linux-{arch}
- Servidor oficial de producción
- Falla por falta de RAM

### 4. `Dockerfile.prebuilt` (Binarios pre-compilados)
**Estado**: ⚠️ No probado - script de compilación no funciona

**Características**:
- Asume binarios ya compilados
- Solo copia y ejecuta
- Más ligero y rápido

---

## Archivos Docker Compose Creados

### 1. `docker-compose.dev.yml`
**Entorno**: Desarrollo
**Puerto**: 8889:8080
**Seguridad**: Mínima (full access)

### 2. `docker-compose.staging.yml`
**Entorno**: Staging
**Puerto**: 8889:8080
**Seguridad**: Moderada (restricted terminal, whitelist extensions)

### 3. `docker-compose.prod.yml`
**Entorno**: Producción
**Puerto**: 8889:8080
**Seguridad**: Máxima (terminal disabled, strict whitelist)

### 4. `docker-compose.simple.yml`
**Uso**: Testing approach simple
**Estado**: ❌ No funcional

### 5. `docker-compose.rehweb.yml`
**Uso**: Testing vscode-reh-web compilation
**Estado**: ❌ Falla por memoria

### 6. `docker-compose.prebuilt.yml`
**Uso**: Usar binarios pre-compilados
**Estado**: ⚠️ No probado

---

## Problemas Técnicos Encontrados

### 1. Permisos en Docker
**Error**: `mkdir: cannot create directory: Permission denied`

**Causa**: Dockerfile tenía `USER stackcodesy` antes del ENTRYPOINT

**Solución**:
- Remover `USER stackcodesy` del Dockerfile
- Entrypoint ejecuta como root
- Usa `chown` para arreglar permisos
- Cambia a usuario `stackcodesy` con `su` antes de iniciar servidor

### 2. Argumentos Desconocidos
**Error**: `Unknown argument --without-connection-token`

**Causa**: @vscode/test-web no soporta ese flag

**Solución**: Removido del CMD en Dockerfile

### 3. 404s para Archivos del Workbench
**Error**:
```
GET /out/vs/code/browser/workbench/workbench.css 404
GET /out/nls.messages.js 404
```

**Causa**: Archivos no compilados o servidor buscando en path incorrecto

**Intentos de solución**:
- Compilar con diversos gulp tasks → Todos fallaron
- Verificar directorio `/stackcodesy/out/` → No existe
- Servidor Express custom → Mismos 404s

**Estado**: ❌ No resuelto

### 4. Dependencias Faltantes
**Errors**:
- `Cannot find package 'esbuild'`
- `Could not resolve 'morphdom'`
- `Could not resolve 'lodash.throttle'`

**Soluciones aplicadas**:
- Agregado `esbuild` a devDependencies
- Agregado `express` a dependencies
- Intentado instalar deps de todas las extensiones
- Actualizado `package-lock.json`

**Estado**: ✅ Parcialmente resuelto (esbuild agregado)

### 5. npm postinstall Fails
**Error**: `ERR Failed to spawn process: Error: spawnSync /bin/sh ENOENT`

**Causa**: Script postinstall complejo intenta instalar deps en test/automation

**Solución**: Usar `npm install --ignore-scripts`

**Estado**: ✅ Resuelto

### 6. Out of Memory Durante Compilación
**Error**: `ResourceExhausted: cannot allocate memory`

**Causa**: Compilar VSCode requiere 8-16GB RAM, Docker no tiene suficiente

**Soluciones intentadas**:
- Aumentar `--max-old-space-size` → No ayudó
- Compilar solo partes específicas → Igual falla
- Multi-stage build → Mismo problema

**Estado**: ❌ No resuelto en Docker

### 7. Versión de @types/vscode
**Error**: `No matching version found for @types/vscode@^1.107.0`

**Causa**: VSCode 1.107.0 pero @types solo hasta 1.106.1

**Solución**: Cambiar a `@types/vscode@^1.106.0` en extensión auth

**Estado**: ✅ Resuelto

### 8. TypeScript Errors en Extensión Auth
**Error**:
```
Property 'getSessions' in type 'StackCodeSyAuthenticationProvider'
is not assignable to the same property in base type 'AuthenticationProvider'
```

**Solución**: Actualizar signature para incluir parámetro `options`

**Estado**: ✅ Resuelto

---

## Estado Actual del Proyecto

### ✅ Completado
1. **Sistema de seguridad completo** - Scripts para todas las capas de seguridad
2. **Extensión de autenticación** - Implementada y compilable
3. **Configuraciones de entorno** - Dev, staging, prod con diferentes niveles de seguridad
4. **Entrypoint orquestador** - Maneja inicialización de todos los sistemas
5. **Docker Compose configs** - Para diferentes entornos
6. **Documentación de seguridad** - Scripts comentados y explicados

### ⚠️ Parcialmente Completado
1. **Dockerfiles** - Múltiples versiones creadas pero ninguna funcional
2. **package.json** - Actualizado con dependencias necesarias
3. **Build scripts** - Creados pero no funcionales

### ❌ No Funcional
1. **Servidor VSCode Web** - No logra servir correctamente
2. **Compilación** - No genera archivos necesarios
3. **Docker build** - Falla por memoria o dependencias
4. **Build local** - Script tiene errores

---

## Análisis de Code-Server

### Cómo lo Hacen Ellos

1. **VSCode como Submodule**
   - No es un fork completo
   - Se mantiene actualizable

2. **Patches con Quilt**
   - Modificaciones mínimas aplicadas como patches
   - Fácil de actualizar cuando VSCode lanza nueva versión

3. **Compilación en CI/CD**
   - No compilan en Docker
   - Usan GitHub Actions u otro CI
   - Máquinas con recursos suficientes

4. **Distribución de Binarios**
   - Crean paquetes .deb, .rpm, tarballs
   - Docker solo instala paquetes pre-compilados

5. **Dockerfile Simple**
   ```dockerfile
   # Copia paquetes pre-compilados
   COPY packages/*.deb /tmp/
   # Instala con dpkg
   RUN dpkg -i /tmp/code-server*.deb
   ```

### Por Qué Su Approach Funciona

- ✅ No compilan en Docker (evita problemas de memoria)
- ✅ Distribuyen binarios (instalación rápida)
- ✅ Patches mínimos (fácil mantenimiento)
- ✅ Proceso de build profesional (CI/CD robusto)

---

## Lecciones Aprendidas

### 1. @vscode/test-web NO es para Producción
Es una herramienta de **desarrollo** que compila TypeScript on-demand. No está diseñada para servir VSCode en producción.

### 2. vscode-reh-web ES el Servidor Correcto
Es el servidor oficial que Microsoft usa para vscode.dev. Es la opción correcta para producción web.

### 3. Compilar VSCode es Complejo
- Requiere 8-16GB RAM
- Toma 10-20 minutos
- Tiene muchas dependencias
- Scripts de build frágiles

### 4. Docker Tiene Limitaciones de Recursos
No se puede compilar VSCode dentro de Docker en máquinas normales. Code-server lo hace en CI/CD con máquinas potentes.

### 5. Pre-compilar es la Estrategia Correcta
Compilar una vez, distribuir binarios. Es cómo lo hacen los proyectos profesionales.

### 6. La Documentación de VSCode es Limitada
No hay guías claras para compilar y servir VSCode web en producción. Code-server tuvo que descubrirlo por ensayo y error durante años.

---

## Próximos Pasos Recomendados

### Opción A: Adoptar Code-Server (Más Rápido)

**Ventajas**:
- ✅ Funciona inmediatamente
- ✅ Mantenido profesionalmente
- ✅ Se actualiza con cada versión de VSCode
- ✅ Documentación completa
- ✅ Comunidad activa

**Adaptaciones necesarias**:
1. Integrar tu sistema de autenticación con code-server
2. Aplicar branding de StackCodeSy
3. Configurar las mismas políticas de seguridad
4. Usar variables de entorno de code-server

**Tiempo estimado**: 1-2 semanas

### Opción B: Pipeline CI/CD para Compilar vscode-reh-web

**Pasos**:
1. Crear GitHub Actions workflow
2. Usar runners con 16GB+ RAM
3. Compilar vscode-reh-web-linux-{arch}
4. Crear paquetes .deb o tarballs
5. Subir a GitHub Releases
6. Dockerfile solo descarga e instala paquetes

**Ventajas**:
- ✅ Tu propio fork
- ✅ Control total
- ✅ Última versión de VSCode

**Desventajas**:
- ❌ Requiere configurar CI/CD
- ❌ Mantenimiento continuo
- ❌ Más complejo

**Tiempo estimado**: 3-4 semanas

### Opción C: Investigación Profunda (Más Lento pero Más Educativo)

**Pasos**:
1. Instalar VSCode localmente con Node.js v22
2. Estudiar scripts de build detalladamente
3. Compilar vscode-reh-web localmente paso a paso
4. Documentar cada paso que funciona
5. Crear script de build robusto
6. Probar en Docker

**Ventajas**:
- ✅ Entendimiento profundo
- ✅ Documentación detallada
- ✅ Solución custom

**Desventajas**:
- ❌ Tiempo significativo
- ❌ Curva de aprendizaje empinada
- ❌ Puede no funcionar al final

**Tiempo estimado**: 1-2 meses

---

## Recomendación Personal

**Usar code-server como base** y personalizarlo:

1. **Fase 1** (1 semana): Integrar autenticación custom
   - Modificar code-server para usar tu API de auth
   - Eliminar su sistema de passwords

2. **Fase 2** (1 semana): Branding y seguridad
   - Aplicar branding de StackCodeSy
   - Configurar políticas de seguridad
   - Adaptar los scripts de seguridad ya creados

3. **Fase 3** (1-2 semanas): Optimización
   - Docker Swarm deployment
   - Testing exhaustivo
   - Documentación de uso

**Resultado**: Producto funcional en 3-4 semanas vs meses de investigación.

---

## Archivos del Proyecto

### Scripts de Seguridad
```
resources/server/web/security/
├── entrypoint.sh                 # Orquestador principal
├── terminal-security.sh          # Control de terminal
├── extension-marketplace.sh      # Control de marketplace
├── filesystem-security.sh        # Seguridad de archivos
├── network-security.sh           # Seguridad de red
├── audit-log.sh                  # Sistema de logging
└── csp-config.sh                 # Content Security Policy
```

### Extensión de Autenticación
```
extensions/stackcodesy-auth/
├── package.json
├── tsconfig.json
└── src/
    └── extension.ts
```

### Dockerfiles
```
Dockerfile                 # Multi-stage (no funcional)
Dockerfile.simple         # Single-stage (no funcional)
Dockerfile.rehweb         # vscode-reh-web (no funcional - memoria)
Dockerfile.prebuilt       # Pre-compiled binaries (no probado)
```

### Docker Compose
```
docker-compose.dev.yml        # Desarrollo
docker-compose.staging.yml    # Staging
docker-compose.prod.yml       # Producción
docker-compose.simple.yml     # Testing (no funcional)
docker-compose.rehweb.yml     # Testing reh-web (no funcional)
docker-compose.prebuilt.yml   # Prebuilt binaries (no probado)
```

### Scripts de Build
```
build-vscode-web.sh       # Build local (no funcional)
scripts/code-web.sh       # Launcher @vscode/test-web
scripts/code-web.js       # Wrapper @vscode/test-web
scripts/code-web-prod.sh  # Launcher Express (no usado)
scripts/code-web-prod.js  # Servidor Express custom (no usado)
```

### Documentación
```
BUILD.md                  # Instrucciones de build (incompletas)
CONTEXT.md               # Este documento
```

---

## Commits Importantes

### Branch: `claude/vscode-fork-setup-01AxuDtK1BkoiVKWXt5ncjkE`

1. `7ba94527` - Add simple single-stage Dockerfile - no pre-compilation
2. `9b363093` - Fix npm install in Dockerfile.simple
3. `49b021e1` - Update package-lock.json with esbuild and express dependencies
4. `a6a0681c` - Add vscode-reh-web approach - OFFICIAL VSCode web server
5. `efbb3da8` - Fix npm install by skipping postinstall scripts
6. `eaa648d8` - Add pre-build approach - compile OUTSIDE Docker

### Historial Completo
Ver `git log` para historial completo de intentos, fixes, y experimentos.

---

## Variables de Entorno Documentadas

### Autenticación
```bash
STACKCODESY_REQUIRE_AUTH=true|false
STACKCODESY_USER_ID=
STACKCODESY_USER_NAME=
STACKCODESY_USER_EMAIL=
STACKCODESY_AUTH_TOKEN=
STACKCODESY_AUTH_API=
```

### Terminal
```bash
STACKCODESY_TERMINAL_MODE=disabled|restricted|full
STACKCODESY_TERMINAL_ALLOWED_COMMANDS=  # Lista separada por comas
```

### Extensions
```bash
STACKCODESY_EXTENSION_MODE=disabled|whitelist|full
STACKCODESY_EXTENSION_WHITELIST=  # Lista separada por comas
```

### Filesystem
```bash
STACKCODESY_DISK_QUOTA_MB=0           # 0 = sin límite
STACKCODESY_MAX_FILE_SIZE_MB=1000
STACKCODESY_BLOCK_FILE_TYPES=.exe,.dll
STACKCODESY_ENABLE_FS_MONITORING=true|false
```

### Network
```bash
STACKCODESY_EGRESS_FILTER=true|false
STACKCODESY_BLOCK_ALL_OUTBOUND=true|false
STACKCODESY_ALLOWED_PORTS=80,443
STACKCODESY_ALLOWED_DOMAINS=github.com,npmjs.org
```

### Logging y CSP
```bash
STACKCODESY_ENABLE_AUDIT_LOG=true|false
STACKCODESY_ENABLE_CSP=true|false
```

### Servidor
```bash
HOST=0.0.0.0
PORT=8080
NODE_ENV=production|development
```

---

## Contacto y Soporte

**Desarrollado para**: StackCodeSy Platform
**Framework base**: VSCode (Microsoft) - MIT License
**Inspiración**: code-server (Coder.com)
**Fecha**: Noviembre 2025

---

## Conclusión

Este proyecto ha implementado exitosamente:
- ✅ Sistema completo de seguridad multi-capa
- ✅ Extensión de autenticación custom
- ✅ Configuraciones para diferentes entornos
- ✅ Scripts de orquestación y control

**Pendiente**:
- ❌ Servidor web funcional de VSCode
- ❌ Compilación exitosa de vscode-reh-web
- ❌ Docker build que complete exitosamente

**Recomendación**: Adoptar code-server como base y aplicar las personalizaciones de seguridad y autenticación ya desarrolladas. Esto proporcionará un producto funcional en semanas en lugar de meses de desarrollo experimental.
