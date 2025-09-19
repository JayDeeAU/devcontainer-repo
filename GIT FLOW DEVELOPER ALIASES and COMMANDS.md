# 📚 Complete Custom Commands & Aliases Reference

## 🎯 **Conventional Commit Commands (Custom Aliases)**

These are **custom aliases** that create properly formatted conventional commits:

### **Primary Commit Types**
```bash
feat "description"           # New feature
fix "description"            # Bug fix  
docs "description"           # Documentation changes
test "description"           # Adding or updating tests
chore "description"          # Maintenance tasks
```

### **Additional Commit Types**
```bash
style "description"          # Code style/formatting (no logic change)
refactor "description"       # Code refactoring (no feature/fix)
perf "description"           # Performance improvements
ci "description"             # CI/CD related changes
build "description"          # Build system changes
revert "description"         # Reverting previous commits
```

### **Usage Examples**
```bash
# Basic usage (most common)
feat "add user authentication system"
fix "resolve payment processing timeout"
docs "update API documentation"
test "add unit tests for login component"
chore "update dependencies to latest versions"

# With scope (optional)
feat auth "add OAuth2 integration"  
fix ui "resolve button alignment issue"
docs api "update authentication endpoints"

# Real development examples
feat "implement dashboard analytics"
fix "resolve memory leak in data processing"
refactor "extract payment logic into service"
perf "optimize database queries for user lookup"
style "format code according to ESLint rules"
chore "bump version to 2.1.0"
```

---

## 🌊 **Git Flow Commands (Enhanced Versions)**

### **Feature Management**
```bash
gffs <feature-name>         # git-enhanced-feature-start
gfff                        # git-enhanced-feature-finish

# Examples:
gffs user-authentication    # Creates feature/user-authentication + local env
gffs dashboard-redesign     # Creates feature/dashboard-redesign + local env
gfff                        # Finishes current feature → merges to develop
```

### **Hotfix Management**
```bash
ghfs <version>              # git-enhanced-hotfix-start  
ghff <version>              # git-enhanced-hotfix-finish

# Examples:
ghfs 1.2.1                  # Creates hotfix/1.2.1 from main + local env
ghff 1.2.1                  # Finishes hotfix → merges to main + develop
```

### **Release Management**
```bash
grs <version>               # git-enhanced-release-start
grf <version>               # git-enhanced-release-finish

# Examples:
grs 2.0.0                   # Creates release/2.0.0 from develop + local env
grf 2.0.0                   # Finishes release → merges to main + develop + tags
```

### **Standard Git Flow (if you prefer)**
```bash
gff                         # git flow feature (opens Git Flow menu)
gfr                         # git flow release (opens Git Flow menu)  
gfh                         # git flow hotfix (opens Git Flow menu)
```

---

## 🐳 **Environment Management Commands**

### **Environment Switching**
```bash
env-prod                    # Checkout main + start production containers (7500)
env-staging                 # Checkout develop + start staging containers (7600)  
env-local                   # Start local development containers (7700)
env-health                  # Check health of all environments
```

### **Container Management**
```bash
./docker/scripts/enhanced-container-manager.sh switch   # Auto-detect and switch
./docker/scripts/enhanced-container-manager.sh health   # Health checks
./docker/scripts/enhanced-container-manager.sh status   # Container status
./docker/scripts/enhanced-container-manager.sh stop     # Stop all containers
./docker/scripts/enhanced-container-manager.sh logs     # Show container logs
```

---

## 📊 **Quick Git Status Commands**

### **Enhanced Status**
```bash
gs                          # git status (enhanced)
gl                          # git log --oneline
git-enhanced-status         # Detailed repository status with branch info
```

### **Branch Information**
```bash
git branch -a               # Show all branches (local + remote)
git branch -v               # Show branches with last commit
git branch --merged         # Show branches merged to current branch
git branch --no-merged      # Show branches not yet merged
```

---

## 🛠️ **Advanced Custom Functions**

### **Conventional Commit Helper**
```bash
git-conventional-commit <type> [scope] <description>

# Examples:
git-conventional-commit feat auth "add user authentication" 
git-conventional-commit fix "" "resolve login bug"
git-conventional-commit docs api "update endpoint documentation"
```

### **Enhanced Branch Management**
```bash
git-enhanced-feature-start <name>    # Validates name, creates branch, switches env
git-enhanced-feature-finish         # Runs checks, merges, switches env
git-enhanced-hotfix-start <version>  # Creates hotfix with validation
git-enhanced-hotfix-finish <version> # Merges to both main and develop
```

---

## 📋 **Complete Command Cheat Sheet**

### **Daily Development Workflow**
```bash
# Start new feature
gffs user-dashboard         # → feature/user-dashboard + local env (7700)

# Make changes and commit
feat "add dashboard layout"
fix "resolve responsive issues"
docs "update component documentation"

# Push work
git push origin feature/user-dashboard

# Finish feature
gfff                        # → merge to develop + staging env (7600)

# Test in staging
curl http://localhost:7610/health
```

### **Production Hotfix Workflow**
```bash
# Create hotfix
ghfs 1.2.1                  # → hotfix/1.2.1 + local env (7700)

# Fix critical issue  
fix "resolve payment timeout"
git push origin hotfix/1.2.1

# Finish hotfix
ghff 1.2.1                  # → merge to main + develop + production env (7500)

# Update feature branches
git checkout feature/my-work
git rebase develop          # Pull hotfix into feature
```

### **Environment Testing**
```bash
# Test all environments
env-prod                    # Production testing (7500)
env-staging                 # Staging testing (7600)  
env-local                   # Development testing (7700)

# Health monitoring
env-health                  # Check all environment status
```

---

## 🎨 **VSCode Integration Commands**

Available via **Ctrl+Shift+P → "Tasks: Run Task"**:

```bash
🚀 Switch to Production Environment      # env-prod
🧪 Switch to Staging Environment         # env-staging  
🌿 Start New Feature                     # gffs (prompts for name)
✅ Finish Feature                        # gfff
🚨 Start Hotfix                          # ghfs (prompts for version)
🏥 Health Check                          # env-health
📦 Build Local Containers               # Docker build
```

---

## 🔧 **Configuration Commands**

### **Git Configuration**
```bash
# View current Git config
git config --list

# Set up conventional commits template
git config commit.template .gitmessage

# Configure merge tool
git config merge.tool vscode
```

### **GitHub CLI Integration**
```bash
# Create pull requests
gh pr create --title "feat: user auth" --base develop --head feature/user-auth

# Merge pull requests  
gh pr merge --squash
gh pr merge --merge
gh pr merge --rebase

# View repository info
gh repo view
gh pr list
gh issue list
```

---

## 📚 **Command Categories Summary**

| Category | Commands | Purpose |
|----------|----------|---------|
| **Commits** | `feat`, `fix`, `docs`, `test`, `chore`, `style`, `refactor`, `perf`, `ci`, `build`, `revert` | Conventional commits |
| **Features** | `gffs`, `gfff` | Feature development workflow |
| **Hotfixes** | `ghfs`, `ghff` | Production hotfix workflow |
| **Releases** | `grs`, `grf` | Release preparation workflow |
| **Environments** | `env-prod`, `env-staging`, `env-local`, `env-health` | Container environment management |
| **Status** | `gs`, `gl`, `git-enhanced-status` | Repository status and information |
| **GitHub** | `gh pr create`, `gh pr merge`, `gh repo view` | GitHub integration |

---

## 💡 **Pro Tips**

### **Efficient Commit Workflow**
```bash
# Quick commits during development
feat "WIP: dashboard structure"
feat "WIP: API integration"  
feat "WIP: styling updates"

# Clean up before finishing feature
git rebase -i HEAD~3       # Squash WIP commits
gfff                       # Finish with clean history
```

### **Environment Switching Workflow**  
```bash
# Work on feature
gffs new-dashboard         # Local env (7700)

# Test in staging
env-staging                # Staging env (7600)

# Verify in production  
env-prod                   # Production env (7500)

# Back to development
git checkout feature/new-dashboard  # Auto-switches to local (7700)
```

### **Multi-Branch Development**
```bash
# Save current work
feat "WIP: dashboard progress"

# Switch to hotfix
ghfs 1.2.1
fix "critical payment issue"
ghff 1.2.1

# Return to feature (with hotfix included)
git checkout feature/dashboard
git rebase develop         # Pull in hotfix
# Continue development
```

**All these commands work together to give you a seamless development workflow with automatic environment switching and proper Git history management!**