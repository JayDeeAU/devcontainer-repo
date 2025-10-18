# 🎭 Development Workflows - Quick Reference

> **📌 Universal Guide**: This workflow guide works identically for any project using the devcontainer system.  
> Project-specific configuration is handled via `.container-config.json` (see [PROJECT-SETUP.md](PROJECT-SETUP.md)).

---

## 📚 **Quick Scenario Navigation**

| Scenario | Key Command | Environment | Duration | When to Use |
|----------|-------------|-------------|----------|-------------|
| [🌟 Feature Development](#-feature-development) | `gffs` → `gfff` | Local → Staging | Days-Weeks | Building new functionality |
| [🚨 Production Hotfix](#-production-hotfix) | `ghfs` → `ghff` | Local → Production | Hours | Critical production issues |
| [🚀 Release Preparation](#-release-preparation) | `grs` → `grf` | Local → Production | Days | Promoting staging to production |
| [⚡ Team Integration](#-team-feature-integration) | Manual merges | Staging | Hours | Multiple completed features |
| [🔄 Hotfix Distribution](#-hotfix-distribution) | `git rebase develop` | Local | Hours | Applying hotfixes to features |
| [🧪 Multi-Environment Testing](#-multi-environment-testing) | `env-*` commands | All | Hours | Cross-environment validation |
| [🔍 Production Investigation](#-production-investigation) | `env-prod-debug` | Production Debug | Hours | Source-level debugging |
| [📊 Container Management](#-container-management) | `env-*` commands | Various | Minutes | Environment maintenance |
| [🗑️ Feature Abandonment](#-feature-abandonment) | `git revert` / cleanup | Various | Hours | Removing unwanted features |
| [⚠️ Hotfix Abandonment](#-hotfix-abandonment) | Branch cleanup | Various | Minutes | Canceling hotfix development |
| [🔄 Emergency Switching](#-emergency-switching) | Multiple commands | Multiple | Minutes | Rapid scenario changes |
| [📋 Pull Request Workflows](#-pull-request-workflows) | `gh pr` commands | Various | Days | Team collaboration |
| [🏷️ Release Management](#-release-management) | `grs` → `grf` + `gh` | All | Days-Weeks | Comprehensive releases |

---

## 🌟 **Feature Development**

### **Quick Start**
```bash
gffs user-dashboard         # Start feature + local env (7700)
feat "add dashboard layout" # Make commits
gfff                       # Finish → develop + staging env (7600)
```

### **Environment Flow**
- **Start:** `develop` → `feature/name` + Local (7700)
- **Working:** Local environment with full source mounting
- **Finish:** Merge to `develop` + Staging (7600)

### **Key Commands**
```bash
# Development cycle
gffs <name>                # git-enhanced-feature-start
feat/fix/docs "message"    # Conventional commits  
gp origin feature/name     # git-safe-push (backup)
gfff                       # git-enhanced-feature-finish

# Testing
curl http://localhost:7710/health    # Local testing
curl http://localhost:7610/health    # Staging testing after finish
```

---

## 🚨 **Production Hotfix**

### **Quick Start**
```bash
feat "WIP: save work"      # Save current work
ghfs 1.2.3                # Start hotfix + local env (7700)
fix "critical issue"      # Fix and commit
ghff 1.2.3                # Finish → production env (7500)
```

### **Environment Flow**
- **Start:** `main` → `hotfix/version` + Local (7700)
- **Working:** Local environment with production code
- **Finish:** Merge to `main` + `develop` + Production (7500)

### **Key Commands**
```bash
# Emergency workflow
ghfs <version>             # git-enhanced-hotfix-start
fix "emergency fix"        # Fix critical issue
gp origin hotfix/version   # git-safe-push (backup)
ghff <version>             # git-enhanced-hotfix-finish

# Return to previous work
gco feature/previous-work  # git-safe-checkout + auto env switch
git rebase develop         # Include hotfix in feature
```

---

## 🚀 **Release Preparation**

### **Quick Start**
```bash
env-staging               # Verify staging ready
grs 2.0.0                # Start release + local env (7700)
chore "bump version"     # Prepare release
grf 2.0.0                # Finish → production env (7500)
```

### **Environment Flow**
- **Start:** `develop` → `release/version` + Local (7700)
- **Working:** Local environment for final preparation
- **Finish:** Merge to `main` + `develop` + Production (7500)

### **Key Commands**
```bash
# Release workflow
grs <version>              # git-enhanced-release-start
chore "bump version"       # Update version numbers
docs "update changelog"    # Document changes
gp origin release/version  # git-safe-push (backup)
grf <version>              # git-enhanced-release-finish

# GitHub integration
gh release create v2.0.0 --title "Release v2.0.0"
```

---

## ⚡ **Team Feature Integration**

### **Quick Start**
```bash
env-staging                      # Switch to staging
git merge feature/one --no-ff    # Integrate features manually
git merge feature/two --no-ff    # Test between each
gp origin develop               # git-safe-push final state
```

### **When to Use**
- Features completed outside `gfff`
- PR-based workflow integration
- Multiple features ready simultaneously

### **Key Commands**
```bash
# Integration process
env-staging                    # Staging environment (7600)
git merge feature/name --no-ff # Manual feature integration
curl http://localhost:7610/api/test   # Test integration
gp origin develop             # git-safe-push
git branch -d feature/name     # Clean up local
gp origin --delete feature/name # git-safe-push delete remote
```

---

## 🔄 **Hotfix Distribution**

### **Quick Start**
```bash
env-staging                # Verify hotfix in develop
gco feature/my-work       # git-safe-checkout your feature
git rebase develop        # Pull hotfix into feature
gp --force-with-lease origin feature/my-work  # Update remote
```

### **When to Use**
- After `ghff` completes
- Multiple active feature branches exist
- Need to sync hotfix across development work

### **Key Commands**
```bash
# Update your features
gco feature/branch         # git-safe-checkout + auto env switch
git rebase develop         # Include hotfix (no custom alias)
gp --force-with-lease origin feature/branch  # git-safe-push

# Team coordination script
./update-all-features.sh   # Update all team branches
```

---

## 🧪 **Multi-Environment Testing**

### **Quick Start**
```bash
# Terminal 1: env-prod      # Production (7500)
# Terminal 2: env-staging   # Staging (7600)  
# Terminal 3: env-local     # Local (7700)
env-health                  # Check all environments
```

### **When to Use**
- Comparing behavior across environments
- Validating deployments
- Performance testing
- Bug investigation

### **Key Commands**
```bash
# Environment setup
env-prod                   # Production environment (7500)
env-staging               # Staging environment (7600)
env-local                 # Local environment (7700)

# Cross-environment testing
curl http://localhost:7510/health    # Production
curl http://localhost:7610/health    # Staging
curl http://localhost:7710/health    # Local

# Health monitoring
env-health                # All environments health check
env-status               # Current environment status
```

---

## 🔍 **Production Investigation**

### **Quick Start**
```bash
env-prod-debug            # Production with source mounting
# Investigate with source access (read-only)
env-prod                 # Return to normal production
ghfs 1.2.4              # Create hotfix with findings
```

### **When to Use**
- Production bugs need source investigation
- Performance debugging required
- Understanding production behavior

### **⚠️ Important Notes**
- **Investigation only** - don't make changes in debug mode
- Use local hotfix branches for actual fixes
- Temporarily replaces production environment

### **Key Commands**
```bash
# Investigation workflow
env-prod-debug           # Production debug mode (source mounted)
vim backend/api/file.py  # Investigate source (read-only)
env-logs backend         # Monitor logs with source context
env-prod                 # Exit debug mode

# Implement fix separately
ghfs 1.2.4              # Create proper hotfix
vim backend/api/file.py  # Implement fix in local env
ghff 1.2.4              # Deploy fix to production
```

---

## 📊 **Container Management**

### **Quick Start**
```bash
env-status               # Overall environment status
env-health              # Health check all environments
env-logs backend        # View specific service logs
env-stop staging        # Stop specific environment
```

### **When to Use**
- Container troubleshooting
- Resource management
- Environment cleanup
- Health monitoring

### **Key Commands**
```bash
# Environment control
env-status               # Show all environment status
env-health              # Health check all environments
env-stop [env]          # Stop specific/all environments
env-logs [service]      # View container logs

# Resource management
docker system df        # Check disk usage
docker system prune -f  # Clean unused resources
env-logs backend --follow  # Live log monitoring
```

---

## 🗑️ **Feature Abandonment**

### **Quick Start**
```bash
# Local only: git branch -D feature/name
# Remote: gp origin --delete feature/name
# In staging: git revert <merge-commit> -m 1
# In production: ghfs 1.2.4 → remove feature → ghff 1.2.4
```

### **Abandonment by Stage**

#### **Local Only**
```bash
gco develop              # git-safe-checkout away from feature
git branch -D feature/unwanted  # Delete local branch
```

#### **Remote but Not Merged**
```bash
gco develop              # git-safe-checkout
git branch -D feature/unwanted           # Delete local
gp origin --delete feature/unwanted      # git-safe-push delete remote
gh pr close 123          # Close PR if exists
```

#### **Already in Staging**
```bash
env-staging              # Switch to staging
git revert abc123d -m 1  # Revert merge commit
feat "remove unwanted feature - requirements changed"
gp origin develop        # git-safe-push
```

#### **Already in Production**
```bash
ghfs 1.2.4              # Emergency removal hotfix
# Remove feature code
fix "emergency removal of problematic feature"
ghff 1.2.4              # Deploy removal
```

---

## ⚠️ **Hotfix Abandonment**

### **Quick Start**
```bash
gco main                 # git-safe-checkout away from hotfix
git branch -D hotfix/1.2.3  # Delete local branch
gp origin --delete hotfix/1.2.3  # git-safe-push delete remote (if pushed)
gh pr close 456 --comment "Alternative solution found"
```

### **When to Use**
- Alternative solution found
- Issue resolved by other means
- Hotfix approach incorrect

### **Key Commands**
```bash
# Simple abandonment
gco main                 # git-safe-checkout to main
git branch -D hotfix/version  # Delete hotfix branch
env-prod                 # Return to production environment

# With documentation
feat "abandon hotfix - alternative solution deployed"
gp origin hotfix/version # git-safe-push final commit
# Then clean up branches
```

---

## 🔄 **Emergency Switching**

### **Quick Start**
```bash
feat "WIP: emergency save"  # Save current work
ghfs 1.2.4                 # Emergency hotfix
fix "critical issue"       # Fix immediately
ghff 1.2.4                 # Deploy fix
gco feature/previous-work   # Return to previous work
git rebase develop          # Include emergency fix
```

### **Common Patterns**

#### **Feature → Hotfix → Feature**
```bash
feat "WIP: checkpoint"     # Save feature work
ghfs 1.2.4                # Emergency hotfix
# Fix emergency
ghff 1.2.4                # Deploy fix
gco feature/work          # Return to feature + auto env switch
git rebase develop        # Include hotfix
```

#### **Multiple Concurrent Emergencies**
```bash
# Terminal 1: ghfs 1.2.5   # Handle hotfix
# Terminal 2: env-prod-debug  # Investigate production
# Terminal 3: env-staging     # Test in staging
# Terminal 4: gco feature/work  # Continue feature work
```

---

## 📋 **Pull Request Workflows**

### **Quick Start**
```bash
gffs feature             # Develop feature
gp origin feature/name   # git-safe-push
gh pr create --title "feat: description" --base develop
gh pr merge --squash     # After approval
```

### **Workflow Strategies**

#### **Feature-First (Complete then PR)**
```bash
gffs feature-name        # Complete feature locally
gfff                     # Finish to develop
gh pr create --base main --head develop  # Document PR
gh pr merge --merge      # Deploy to production
```

#### **PR-First (Collaborative)**
```bash
gffs feature-name        # Start feature
feat "initial structure" # Initial commit
gp origin feature/name   # git-safe-push
gh pr create --draft     # Create draft PR
# Collaborate...
gh pr ready              # Mark ready for review
gh pr merge --squash     # After approval
```

---

## 🏷️ **Release Management**

### **Quick Start**
```bash
grs 2.2.0               # Start release
chore "bump version"    # Prepare release
docs "update changelog" # Document changes
gp origin release/2.2.0 # git-safe-push
gh pr create --base main --head release/2.2.0  # Release PR
gh pr merge --merge     # After approval
grf 2.2.0              # Complete release
gh release create v2.2.0  # GitHub release
```

### **Release Workflow**
1. **Prepare:** `grs` → version updates → documentation
2. **Review:** Push release branch → create PR → stakeholder review
3. **Deploy:** Merge PR → `grf` → create GitHub release
4. **Monitor:** Track metrics → monitor health → support users

### **Key Commands**
```bash
# Release preparation
grs <version>            # git-enhanced-release-start
chore "bump version to X.Y.Z"  # Update versions
docs "update changelog"  # Document changes

# GitHub integration
gh pr create --title "Release vX.Y.Z" --base main
gh pr merge --merge      # Preserve history
gh release create vX.Y.Z --notes-file CHANGELOG.md

# Post-release
env-prod && env-health   # Monitor production
```

---

## 🎯 **Environment Quick Reference**

| Environment | Port Range | Access | Source Mount | Use Case |
|-------------|------------|--------|--------------|----------|
| **Production** | 7500-7599 | http://localhost:7500 | ❌ Built images | Live system testing |
| **Staging** | 7600-7699 | http://localhost:7600 | ❌ Built images | Integration testing |
| **Local** | 7700-7799 | http://localhost:7700 | ✅ Full source | Development work |
| **Prod Debug** | 7500-7599 | http://localhost:7500 | ✅ Investigation | Source debugging |
| **Stage Debug** | 7600-7699 | http://localhost:7600 | ✅ Investigation | Source debugging |

---

## ⚡ **Emergency Command Reference**

### **Critical Production Issue**
```bash
feat "WIP: save"         # Save current work
ghfs 1.2.X              # Emergency hotfix
fix "critical fix"      # Implement fix
ghff 1.2.X              # Deploy immediately
```

### **Environment Failure**
```bash
env-stop all            # Stop all environments
env-health              # Check status
env-prod                # Restart production
env-status              # Verify recovery
```

### **Branch Cleanup Emergency**
```bash
gco develop             # Safe branch
git branch -D problem-branch  # Delete problematic branch
gp origin --delete problem-branch  # Clean remote
```

### **Investigation Emergency**
```bash
env-prod-debug          # Source access to production
# Investigate issue
env-prod                # Return to normal
ghfs 1.2.X              # Implement fix properly
```

---

## 💡 **Pro Tips**

### **Daily Workflow**
```bash
gffs daily-work         # Start work + local env
feat "implement feature" # Work with commits
gp origin feature/name   # Regular backups
gfff                    # Finish → staging env
```

### **Team Coordination**
```bash
git rebase develop      # Keep features updated with hotfixes
gp --force-with-lease   # Safe force push after rebase
gh pr create --draft    # Early collaboration
```

### **Environment Management**
```bash
env-health              # Regular health checks
env-logs backend        # Monitor specific services
env-stop local          # Clean up when done
env-status              # Overall system status
```

**All scenarios work together seamlessly with automatic environment switching and proper Git history management!**