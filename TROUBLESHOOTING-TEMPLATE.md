# Troubleshooting Guide Template

**For projects using universal-container-manager infrastructure**

> 💡 **Note:** This is a template. Customize with your project-specific:
> - Service names
> - Port numbers
> - Error messages
> - Technology stack issues

---

## Quick Diagnostics

Run these commands first to gather information:

```bash
# Check environment status
env-status

# Health check current environment
env-health

# View recent logs
env-logs [service-name]

# Check Docker
docker ps
docker network ls
```

---

## Common Issues

### Issue: env-local Fails on Host (Outside Dev Container)

**Symptoms:**
- Command works in dev container but not on host
- Silent failures or network errors
- "Network not found" errors

**Root Cause:**
Docker networks declared as `external: true` in compose files don't exist on host system.

**Solutions:**

**Option 1: Create Networks Manually (Quick Fix)**
```bash
# Replace with your project's network names
docker network create your-project-network-local
docker network create your-project-network-staging
docker network create your-project-network-prod

# If using external networks
docker network create redis_admin_network
docker network create traefik-proxy

# Try again
env-local
```

**Option 2: Run Bootstrap Script (If Available)**
```bash
.devcontainer/scripts/host-bootstrap.sh
```

**Option 3: Update Compose Files (Permanent Fix)**
Change `external: true` to let Docker create networks:
```yaml
# docker-compose.local.yml
networks:
  your-project-network-local:
    driver: bridge
    name: your-project-network-local
    # Remove or comment: external: true
```

**Verify Fix:**
```bash
docker network ls | grep your-project
env-local
env-status
```

---

### Issue: Cannot Connect to Debug Port

**Symptoms:**
- VSCode shows "Cannot connect to debugpy/node debugger"
- Timeout errors when attaching
- Debug panel shows disconnected

**Root Causes & Solutions:**

**1. Service Not Running**
```bash
# Check service status
env-status
docker ps | grep YOUR_SERVICE

# If not running, start it
env-local  # or env-staging/env-prod
```

**2. Debug Port Not Exposed**
```bash
# Check if port is exposed
docker ps
# Look for port mapping like: 0.0.0.0:7711->5678/tcp

# If missing, check docker-compose file
cat docker/docker-compose.local.yml | grep -A 10 "YOUR_SERVICE"
```

**3. Service Not in Debug Mode**
```bash
# Check if debug command is running
docker logs YOUR_CONTAINER | grep -i debug

# Restart with debug mode
env-stop
env-local --debug  # Explicitly enable debug
```

**4. Firewall Blocking Port**
```bash
# Check if port is listening
ss -tlnp | grep 7711  # Replace with your debug port

# If not found, check Docker networking
docker inspect CONTAINER_NAME | grep -A 20 NetworkSettings
```

**Verify Fix:**
```bash
# Test port connection
nc -zv localhost 7711  # Replace with your debug port

# Try attaching debugger in VSCode
# Press F5 → Select configuration → Should connect
```

---

### Issue: Breakpoints Not Working

**Symptoms:**
- Breakpoints appear hollow/gray
- "Breakpoint ignored" message
- Code executes without stopping

**Root Causes & Solutions:**

**1. Source Maps Missing (Frontend)**
```bash
# Check if source maps are generated
cd frontend
ls -la .next/  # Next.js
ls -la dist/   # Other frameworks

# Rebuild with source maps
npm run build  # or pnpm/yarn
```

**2. Path Mappings Incorrect**
```jsonc
// Check .vscode/launch.json
{
  "pathMappings": [{
    // Local path must match your workspace structure
    "localRoot": "${workspaceFolder}/backend",  // ✓ Correct
    // Not: "${workspaceFolder}/src/backend"     // ✗ Wrong

    // Remote path must match container structure
    "remoteRoot": "/app"  // ✓ Check Dockerfile WORKDIR
  }]
}
```

**3. JustMyCode Filtering (Python)**
```jsonc
// .vscode/launch.json
{
  "name": "Backend Debug",
  "type": "debugpy",
  "justMyCode": false,  // Set to false to debug libraries
}
```

**4. Source Files Changed**
```bash
# Restart service to reload code
docker-compose -f docker/docker-compose.local.yml restart YOUR_SERVICE

# Or full rebuild
env-stop
env-local --build
```

**Verify Fix:**
```bash
# Add test breakpoint
# In VSCode: Click left of line number (red dot should appear)
# Press F5 → Trigger code → Should stop at breakpoint
```

---

### Issue: Worktrees Don't Exist

**Symptoms:**
- `env-prod --debug` fails with path errors
- "No such file or directory" for worktree
- Debug configurations can't find source

**Root Cause:**
Worktrees are created on-demand but haven't been set up yet.

**Solution:**
```bash
# Create worktrees
universal-container-manager setup-worktrees

# Verify creation
ls -la /workspaces/
# Should see: your-project-production/ and your-project-staging/

# Try debug mode again
env-prod --debug
```

**Manual Creation (Alternative):**
```bash
cd /workspaces/your-project

# Production worktree
git worktree add --detach ../your-project-production main

# Staging worktree
git worktree add --detach ../your-project-staging develop

# Add to gitignore
echo "your-project-production/" >> .gitignore
echo "your-project-staging/" >> .gitignore
```

---

### Issue: Source Maps Not Resolving

**Symptoms:**
- Debugger shows wrong line numbers
- Can't step through code correctly
- Variables show incorrect values

**Solutions:**

**For Next.js:**
```javascript
// next.config.js
module.exports = {
  // Enable source maps in development (default)
  // Disable in production for performance
  productionBrowserSourceMaps: false,
}
```

**For TypeScript:**
```json
// tsconfig.json
{
  "compilerOptions": {
    "sourceMap": true,  // Enable source maps
    "inlineSourceMap": false,  // Separate .map files
  }
}
```

**For Python:**
```python
# Generally not needed, but ensure code is up-to-date
# Restart service after code changes
```

**Clear Build Cache:**
```bash
# Frontend
cd frontend
rm -rf .next node_modules/.cache
npm run build

# Backend (Python)
cd backend
find . -type d -name __pycache__ -exec rm -rf {} +
```

---

### Issue: Port Conflicts

**Symptoms:**
- "Port already in use" errors
- Services fail to start
- Cannot bind to port

**Solutions:**

**1. Identify Conflicting Process**
```bash
# Find what's using the port
sudo lsof -i :7700  # Replace with your port
# or
ss -tlnp | grep 7700

# Kill if needed
kill -9 PID
```

**2. Stop Other Environments**
```bash
# Stop all environments
env-stop all

# Or specific environment
env-stop staging
```

**3. Change Port Configuration**
```json
// .container-config.json
{
  "environments": {
    "local": {
      "ports": {
        "frontend": 7700,  // Change to available port
        "backend": 7710
      }
    }
  }
}
```

---

### Issue: Volume Permission Errors

**Symptoms:**
- "Permission denied" in container logs
- Cannot write files
- Build fails with access errors

**Solutions:**

**1. Check File Ownership**
```bash
# Check directory ownership
ls -la /path/to/mounted/volume

# Fix ownership (replace with your user)
sudo chown -R $USER:$USER /path/to/volume
```

**2. Check Directory Permissions**
```bash
# Make writable
chmod -R 755 /path/to/volume
```

**3. Docker User ID Mismatch**
```dockerfile
# In Dockerfile, match host user ID
ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g ${GROUP_ID} appuser && \
    useradd -u ${USER_ID} -g appuser -s /bin/bash appuser

USER appuser
```

---

### Issue: Health Check Failing

**Symptoms:**
- Container restarts continuously
- "unhealthy" status in `docker ps`
- Services unavailable

**Solutions:**

**1. Check Health Check Logs**
```bash
# View health check output
docker inspect CONTAINER_NAME | grep -A 20 Health

# Check service logs
docker logs CONTAINER_NAME | tail -50
```

**2. Adjust Health Check Timing**
```yaml
# docker-compose.local.yml
services:
  backend:
    healthcheck:
      interval: 60s        # Increase if slow startup
      timeout: 30s         # Increase if slow response
      retries: 5           # Allow more retries
      start_period: 120s   # Wait longer before checking
```

**3. Test Health Check Manually**
```bash
# Enter container
docker exec -it CONTAINER_NAME bash

# Run health check command manually
curl -f http://localhost:8000/health

# Or for script-based checks
/path/to/healthcheck.sh
```

---

### Issue: Environment Variable Not Set

**Symptoms:**
- "Environment variable not found" errors
- Configuration missing
- Service behaves incorrectly

**Solutions:**

**1. Check .env File**
```bash
# Verify .env file exists
ls -la .env.development .env.production

# Check variable is present
cat .env.development | grep VARIABLE_NAME
```

**2. Verify Compose File Loads It**
```yaml
# docker-compose.local.yml
services:
  backend:
    env_file:
      - ../.env.development  # Correct path?
    environment:
      - VARIABLE_NAME=${VARIABLE_NAME}
```

**3. Check Variable Inside Container**
```bash
# Enter container
docker exec -it CONTAINER_NAME bash

# Check environment
env | grep VARIABLE_NAME
echo $VARIABLE_NAME
```

---

### Issue: Git Worktree Corrupted

**Symptoms:**
- "Worktree is locked" errors
- Cannot sync or update worktree
- Git commands fail in worktree

**Solutions:**

**1. Check Worktree Status**
```bash
cd /workspaces/your-project
git worktree list
```

**2. Remove Lock**
```bash
# If locked, remove lock file
rm -f .git/worktrees/your-project-production/locked
```

**3. Prune and Recreate**
```bash
# Prune invalid worktrees
git worktree prune

# Delete directory
rm -rf ../your-project-production

# Recreate
universal-container-manager setup-worktrees
```

---

## Advanced Debugging

### Enable Verbose Logging

**Universal Container Manager:**
```bash
# Add debug flag to script
bash -x .devcontainer/scripts/universal-container-manager.sh switch local 2>&1 | tee /tmp/debug.log
```

**Docker Compose:**
```bash
# Verbose output
docker-compose --verbose -f docker-compose.local.yml up
```

**Service Logs:**
```bash
# Follow all logs
docker-compose -f docker-compose.local.yml logs -f

# Specific service
docker-compose -f docker-compose.local.yml logs -f backend

# Last N lines
docker logs CONTAINER_NAME --tail 100
```

### Inspect Container Configuration

```bash
# Full container details
docker inspect CONTAINER_NAME

# Network configuration
docker inspect CONTAINER_NAME | jq '.[0].NetworkSettings'

# Environment variables
docker inspect CONTAINER_NAME | jq '.[0].Config.Env'

# Mounts/volumes
docker inspect CONTAINER_NAME | jq '.[0].Mounts'
```

### Test Docker Networking

```bash
# List networks
docker network ls

# Inspect network
docker network inspect your-project-network-local

# Test connectivity between containers
docker exec CONTAINER1 ping CONTAINER2
docker exec CONTAINER1 curl http://CONTAINER2:PORT/health
```

### Check Resource Usage

```bash
# Overall stats
docker stats

# Specific container
docker stats CONTAINER_NAME

# Disk usage
docker system df

# Clean up if needed
docker system prune -a
```

---

## Emergency Recovery

### Nuclear Option: Complete Reset

```bash
# 1. Stop everything
env-stop all
docker stop $(docker ps -aq)

# 2. Remove all project containers
docker rm $(docker ps -aq | grep your-project)

# 3. Remove volumes (⚠️ destroys data!)
docker volume prune -f

# 4. Remove networks
docker network prune -f

# 5. Clean system
docker system prune -a -f

# 6. Start fresh
env-local
```

### Restore VSCode Configuration

```bash
# If launch.json/tasks.json are broken
cd .vscode
git checkout HEAD -- launch.json tasks.json

# Or restore from backup (if you have one)
cp .vscode/launch.json.backup .vscode/launch.json
```

### Reset Git Worktrees

```bash
# Remove all worktrees
rm -rf /workspaces/your-project-production
rm -rf /workspaces/your-project-staging

# Prune git references
cd /workspaces/your-project
git worktree prune

# Recreate fresh
universal-container-manager setup-worktrees
```

---

## Getting More Help

### Before Asking for Help

Collect this information:

```bash
# 1. Environment status
env-status > /tmp/debug-status.txt

# 2. Docker state
docker ps -a > /tmp/debug-containers.txt
docker network ls > /tmp/debug-networks.txt

# 3. Recent logs
env-logs backend > /tmp/debug-backend.log
env-logs frontend > /tmp/debug-frontend.log

# 4. System info
uname -a > /tmp/debug-system.txt
docker version >> /tmp/debug-system.txt

# 5. Git state
git status > /tmp/debug-git.txt
git branch -a >> /tmp/debug-git.txt
```

### Useful Commands for Support

```bash
# Check Docker daemon
docker info

# Check Docker Compose version
docker-compose --version

# Check Git version
git --version

# Check shell environment
echo $SHELL
env | grep -E '(DOCKER|GIT|USER)'
```

### Documentation References

- Universal Container Manager: `.devcontainer/scripts/universal-container-manager.sh`
- Debugging Guide: `.devcontainer/DEBUGGING-GUIDE-TEMPLATE.md`
- Worktree Guide: `.devcontainer/WORKTREE-GUIDE-TEMPLATE.md`
- Project Configuration: `.container-config.json`

---

## Preventive Maintenance

### Regular Checks

```bash
# Weekly
env-status                    # Verify environments
docker system df              # Check disk usage
git worktree prune            # Clean worktrees

# Monthly
docker system prune -a        # Clean unused resources
env-stop all                  # Stop everything
env-local --build             # Rebuild from scratch
```

### Keep Things Updated

```bash
# Update Docker images
docker-compose pull

# Update dependencies
cd frontend && npm update
cd backend && poetry update  # or pip, etc.

# Update dev container
git pull origin main  # Pull latest dotfiles/config
```

---

**Last Updated:** [Your Date]  
**Template Version:** 1.0.0  
**Need Help?** Check project documentation or reach out to your team.
