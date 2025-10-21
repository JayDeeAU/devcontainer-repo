# Debugging Guide Template

**For projects using universal-container-manager and multi-environment setup**

> 💡 **Note:** This is a template. Copy to your project and customize with your specific:
> - Project name
> - Service names
> - Port numbers
> - Technology stack details

---

## Quick Start

### Start Development Environment
```bash
# Start your local development environment
env-local

# Check status
env-status

# View logs
env-logs [service-name]
```

### Attach Debugger
1. Ensure environment is running: `env-status`
2. Open VS Code Run & Debug panel (F5)
3. Select appropriate debug configuration
4. Press F5 or click green play button

---

## Environment Overview

This project uses three isolated environments:

| Environment | Port Range | Branch Pattern | Purpose |
|-------------|-----------|----------------|---------|
| **Local** | 7700-7799 | `feature/*`, `hotfix/*` | Active development |
| **Staging** | 7600-7699 | `develop` | Pre-production testing |
| **Production** | 7500-7599 | `main` | Deployment monitoring |

### Common Commands

```bash
# Environment Management
env-local              # Start local development
env-staging            # Start staging environment
env-prod               # Start production environment

# Debug Modes
env-local-debug        # Local with debuggers in wait state

# Debug Branch Workflow
git switch main        # Switch to branch you want to debug
dbs issue-name         # Create debug branch from current branch
dbl                    # List active debug branches
dbf                    # End debug session, return to parent branch

# Utilities
env-status             # Show all environments
env-health             # Health check current environment
env-stop [env]         # Stop specific or all environments
env-logs [service]     # View service logs
```

---

## Debug Port Reference

Update this table with your project's actual debug ports:

| Service | Local Port | Staging Port | Production Port |
|---------|------------|--------------|-----------------|
| Backend API Debug | 7711 | 7611 | 7511 |
| Frontend Debug | 9229 | 9229 | 9229 |
| Worker Debug | 7712 | 7612 | 7512 |

---

## VS Code Debugging

### Launch Configurations

Your `.vscode/launch.json` should include configurations for:

1. **Backend Debugging** (Python, Node.js, etc.)
   ```jsonc
   {
     "name": "Local: Backend Service",
     "type": "debugpy",  // or "node" for Node.js
     "request": "attach",
     "connect": {
       "host": "localhost",
       "port": 7711
     },
     "pathMappings": [{
       "localRoot": "${workspaceFolder}/backend",
       "remoteRoot": "/app"
     }]
   }
   ```

2. **Frontend Debugging** (React, Next.js, etc.)
   ```jsonc
   {
     "name": "Local: Frontend Service",
     "type": "node",
     "request": "attach",
     "port": 9229,
     "restart": true,
     "localRoot": "${workspaceFolder}/frontend",
     "remoteRoot": "/app"
   }
   ```

3. **Compound Configurations** (Full Stack)
   ```jsonc
   {
     "name": "Full Stack Debug",
     "configurations": [
       "Local: Backend Service",
       "Local: Frontend Service"
     ]
   }
   ```

### Simplifying Configurations with Variables

To reduce duplication across environments, use configuration variables:

```jsonc
// .vscode/settings.json
{
  "yourProject.environment": "local",
  "yourProject.debugPorts": {
    "local": { "backend": 7711, "frontend": 9229 },
    "staging": { "backend": 7611, "frontend": 9229 },
    "prod": { "backend": 7511, "frontend": 9229 }
  }
}

// .vscode/launch.json
{
  "name": "Backend (${config:yourProject.environment})",
  "port": "${config:yourProject.debugPorts.${config:yourProject.environment}.backend}"
}
```

---

## Debug Branch Workflow

### Concept
Debug branches are **temporary scratch branches** for investigating production/staging issues with full source mounting in local environment.

### When to Use
- Investigating production bugs
- Testing staging issues locally
- Reproducing specific version behavior
- Testing hotfix before creating official hotfix branch

### Usage Workflow
```bash
# 1. Switch to the branch you want to debug
git switch main           # For production issues
git switch develop        # For staging issues
git switch feature/auth   # For feature branch issues

# 2. Create debug branch from current branch
dbs payment-timeout
# Creates: debug/main-payment-timeout-20251021-143022

# 3. Environment auto-starts with source mounting
# Make changes, add debug prints, test fixes

# 4. List active debug branches
dbl

# 5. When done, end debug session
dbf
# Returns to parent branch (main/develop/feature/*)
# Deletes debug branch
```

### Debug Branch Rules
- ✅ Temporary branches for testing only
- ✅ Auto-deleted by dbf command
- ✅ Full source mounting in local environment
- ✅ Can commit changes if needed (optional)
- ❌ Not for long-term development
- ❌ Use feature branches for actual development

---

## Technology-Specific Debugging

### Next.js / React (Frontend)

**Next.js 15+ Recommended Setup:**

1. **Enable debugging in package.json:**
   ```json
   {
     "scripts": {
       "dev": "NODE_OPTIONS='--inspect=0.0.0.0:9229' next dev --port 8080",
       "dev:no-debug": "next dev --port 8080"
     }
   }
   ```

2. **Simple attach configuration:**
   ```jsonc
   {
     "name": "Next.js Server",
     "type": "node",
     "request": "attach",
     "port": 9229,
     "restart": true
   }
   ```

3. **Full stack with browser:**
   ```jsonc
   {
     "name": "Next.js Full Stack",
     "type": "node",
     "request": "attach",
     "port": 9229,
     "serverReadyAction": {
       "pattern": "ready - started server.*http://localhost:([0-9]+)",
       "uriFormat": "http://localhost:%s",
       "action": "debugWithChrome"
     }
   }
   ```

**Breakpoint Tips:**
- Server Components: Breakpoints work in `.tsx` files
- API Routes: Breakpoints work in `route.ts` files
- Client Components: Use Chrome DevTools or attach browser debugger

### Python / FastAPI (Backend)

**Enable debugpy:**
```yaml
# docker-compose.local-debug.yml
services:
  backend:
    command: python -m debugpy --listen 0.0.0.0:5678 --wait-for-client -m uvicorn api.asgi:api --host 0.0.0.0 --port 8000 --reload
```

**VS Code configuration:**
```jsonc
{
  "name": "Python Backend",
  "type": "debugpy",
  "request": "attach",
  "connect": {
    "host": "localhost",
    "port": 7711
  },
  "pathMappings": [{
    "localRoot": "${workspaceFolder}/backend",
    "remoteRoot": "/app"
  }],
  "justMyCode": false  // Debug into libraries if needed
}
```

### Node.js / Express (Backend)

**Enable inspector:**
```json
{
  "scripts": {
    "dev": "NODE_OPTIONS='--inspect=0.0.0.0:9229' nodemon server.js"
  }
}
```

**VS Code configuration:**
```jsonc
{
  "name": "Node.js Backend",
  "type": "node",
  "request": "attach",
  "port": 9229,
  "restart": true,
  "skipFiles": ["<node_internals>/**"]
}
```

---

## Troubleshooting

### "Cannot connect to debug port"

**Symptoms:** VSCode can't attach to debugger

**Solutions:**
1. Check service is running: `env-status`
2. Check debug port is exposed: `docker ps | grep YOUR_SERVICE`
3. Check logs: `env-logs backend`
4. Restart with debug mode: `env-stop && env-local --debug`

### "Breakpoints not working"

**Symptoms:** Breakpoints appear hollow/not binding

**Solutions:**
1. Verify source maps enabled (frontend)
2. Check path mappings match container structure:
   ```jsonc
   "localRoot": "${workspaceFolder}/backend",  // Your local path
   "remoteRoot": "/app"  // Container path
   ```
3. Ensure `justMyCode: false` for library debugging
4. Try restarting debugger (Ctrl+Shift+F5)

### "env-local fails on host"

**Symptoms:** Command works in dev container but not on host

**Solutions:**
1. Create required Docker networks:
   ```bash
   docker network create your-project-network-local
   docker network create redis_admin_network  # if used
   ```
2. Check `.container-config.json` for network requirements

### "Debug branch won't delete"

**Symptoms:** Cannot delete debug branch

**Solutions:**
```bash
# If you're on the debug branch, switch first
git switch main

# Force delete
git branch -D debug/main-issue-name-timestamp

# Use dbf for clean automated cleanup
dbf
```

### "Source maps not resolving"

**Symptoms:** Debugger shows wrong line numbers

**Solutions:**
1. **Frontend:** Ensure Next.js generates source maps:
   ```js
   // next.config.js
   module.exports = {
     productionBrowserSourceMaps: false,  // Production
     // Dev mode generates them by default
   }
   ```
2. **Backend:** Check compiler settings (TypeScript/Babel)
3. Clear build cache: `rm -rf .next` (frontend) or `__pycache__` (Python)

---

## Best Practices

### Development Workflow
1. ✅ Always work in **feature branches**, not main/develop
2. ✅ Use `env-local` for active development
3. ✅ Test in `env-staging` before merging
4. ✅ Use debug branches only for investigating issues

### Debugging Workflow
1. ✅ Start environment before attaching debugger
2. ✅ Use compound configurations for full-stack debugging
3. ✅ Check health endpoints before debugging
4. ✅ Add breakpoints in VSCode, not `debugger;` statements

### Debug Branch Workflow
1. ✅ Use for **investigation only**, not development
2. ✅ Switch to parent branch first (git switch main/develop)
3. ✅ Create debug branch (dbs issue-name)
4. ✅ Clean up when done (dbf)
5. ❌ **Don't use for long-term feature development**

---

## Performance Tips

### Reduce Debug Overhead

**Frontend:**
- Use `dev:no-debug` script for performance testing
- Disable source maps in production
- Use Chrome DevTools for client-side only

**Backend:**
- Set `justMyCode: true` to skip library code
- Use conditional breakpoints instead of many breakpoints
- Disable auto-restart for heavy operations

### Speed Up Container Startup

1. Use Docker layer caching effectively
2. Pre-build images for staging/prod: `env-staging --build`
3. Use volumes for node_modules and build artifacts
4. Adjust health check intervals if too aggressive

---

## Advanced Configuration

### Custom Debug Ports

If default ports conflict, update in `.container-config.json`:

```json
{
  "environments": {
    "local": {
      "ports": {
        "backend_debug": 7711,
        "frontend_debug": 9229
      }
    }
  }
}
```

### Multi-Service Debugging

For microservices, create compound configurations:

```jsonc
{
  "compounds": [
    {
      "name": "All Microservices",
      "configurations": [
        "Service A",
        "Service B",
        "Service C"
      ],
      "stopAll": true
    }
  ]
}
```

### Remote Debugging

For debugging on remote servers:

```jsonc
{
  "name": "Remote Production",
  "type": "debugpy",
  "request": "attach",
  "connect": {
    "host": "192.168.1.100",  // Remote host
    "port": 7511
  },
  "pathMappings": [{
    "localRoot": "${workspaceFolder}/../your-project-production",
    "remoteRoot": "/app"
  }]
}
```

---

## Health Check Endpoints

Document your project's health endpoints:

| Service | Endpoint | Expected Response |
|---------|----------|-------------------|
| Backend | `http://localhost:7710/health` | `{"status": "healthy"}` |
| Frontend | `http://localhost:7700/api/health` | `200 OK` |
| Database | Redis ping | `PONG` |

---

## Useful VS Code Extensions

Recommended extensions for debugging:

- **Python:** `ms-python.python`
- **JavaScript/TypeScript:** `ms-vscode.js-debug`
- **Docker:** `ms-azuretools.vscode-docker`
- **GitLens:** `eamodio.gitlens` (for worktree management)
- **Remote Containers:** `ms-vscode-remote.remote-containers`

---

## Getting Help

### Debug Information Commands
```bash
# Check everything
env-status
env-health

# Service-specific
env-logs backend
env-logs frontend

# Docker inspection
docker ps
docker logs CONTAINER_NAME
```

### Common Log Locations
- Container logs: `docker logs CONTAINER_NAME`
- Application logs: `/app/logs` (inside container)
- Host logs: Check your volume mount configuration

### Support Channels
- Internal docs: `.devcontainer/*.md`
- Team chat: [Your team channel]
- Issue tracker: [Your project issues]

---

## Appendix: Configuration Files Reference

### Key Files
```
.devcontainer/
├── devcontainer.json              # Dev container configuration
├── scripts/
│   ├── universal-container-manager.sh  # Environment management
│   └── version-manager.sh              # Version synchronization

.vscode/
├── launch.json                    # Debug configurations
├── tasks.json                     # Task automation
└── settings.json                  # Project settings

docker/
├── docker-compose.local.yml       # Local environment
├── docker-compose.local-debug.yml # Local debug overlay
├── docker-compose.staging.yml     # Staging environment
└── docker-compose.prod.yml        # Production environment

.container-config.json             # Project container configuration
```

### Customization Points

1. **Port Numbers:** `.container-config.json` → `environments.[env].ports`
2. **Debug Flags:** `docker-compose.*-debug.yml` → service commands
3. **Health Checks:** `docker-compose.*.yml` → healthcheck sections
4. **Path Mappings:** `.vscode/launch.json` → pathMappings arrays

---

**Last Updated:** [Your Date]  
**Template Version:** 1.0.0  
**Maintained By:** [Your Team]

> 💡 **Tip:** Keep this document updated as your debugging setup evolves!
