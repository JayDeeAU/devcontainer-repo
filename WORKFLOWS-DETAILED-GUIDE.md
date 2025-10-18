# 🎭 Complete Development Workflow Guide

> **📌 Universal Guide**: These workflow scenarios work identically for any project using the devcontainer system.  
> Project-specific settings (ports, services, branches) are configured via `.container-config.json` (see [PROJECT-SETUP.md](PROJECT-SETUP.md)).

---

## 📚 **Quick Navigation Index**

### **Core Development Scenarios**
- [🌟 Scenario 1: Feature Development](#scenario-1-feature-development)
- [🚨 Scenario 2: Production Hotfix](#scenario-2-production-hotfix)  
- [🚀 Scenario 3: Release Preparation](#scenario-3-release-preparation)
- [⚡ Scenario 4: Team Feature Integration](#scenario-4-team-feature-integration)
- [🔄 Scenario 5: Hotfix Distribution](#scenario-5-hotfix-distribution)

### **Testing & Environment Scenarios**
- [🧪 Scenario 6: Multi-Environment Testing](#scenario-6-multi-environment-testing)
- [🔍 Scenario 7: Production Investigation (Debug Mode)](#scenario-7-production-investigation-debug-mode)
- [📊 Scenario 8: Container Management](#scenario-8-container-management)

### **Cleanup & Abandonment Scenarios**
- [🗑️ Scenario 9: Feature Abandonment](#scenario-9-feature-abandonment)
- [⚠️ Scenario 10: Hotfix Abandonment](#scenario-10-hotfix-abandonment)
- [🔄 Scenario 11: Emergency Scenario Switching](#scenario-11-emergency-scenario-switching)

### **GitHub Integration Scenarios**
- [📋 Scenario 12: Pull Request Workflows](#scenario-12-pull-request-workflows)
- [🏷️ Scenario 13: Release Management](#scenario-13-release-management)

---

## 🎯 **Custom Commands Quick Reference**

### **Conventional Commit Commands**
```bash
feat "description"           # git commit -m "feat: description"
fix "description"            # git commit -m "fix: description"  
docs "description"           # git commit -m "docs: description"
test "description"           # git commit -m "test: description"
chore "description"          # git commit -m "chore: description"
style "description"          # git commit -m "style: description"
refactor "description"       # git commit -m "refactor: description"
perf "description"           # git commit -m "perf: description"
ci "description"             # git commit -m "ci: description"
build "description"          # git commit -m "build: description"
revert "description"         # git commit -m "revert: description"
```

### **Enhanced Git Flow Commands**
```bash
gffs <feature-name>          # git-enhanced-feature-start + environment switch
gfff                         # git-enhanced-feature-finish + environment switch
ghfs <version>               # git-enhanced-hotfix-start + environment switch
ghff <version>               # git-enhanced-hotfix-finish + environment switch
grs <version>                # git-enhanced-release-start + environment switch
grf <version>                # git-enhanced-release-finish + environment switch
```

### **Container Environment Commands**
```bash
env-prod                     # Production environment (7500 ports)
env-prod-debug               # Production debug mode (source mounted)
env-staging                  # Staging environment (7600 ports)
env-staging-debug            # Staging debug mode (source mounted)
env-local                    # Local development (7700 ports)
env-health                   # Health check all environments
env-status                   # Show environment status
env-stop [env]               # Stop specific/all environments
env-logs [service]           # Show container logs
```

### **Git Safety Commands**
```bash
gp                           # git-safe-push (enhanced git push)
gco                          # git-safe-checkout (enhanced git checkout)
gs                           # Enhanced git status with branch info
gl                           # git log --oneline -10
ga                           # git-safe-add (enhanced git add)
```

---

# 🎭 **Detailed Scenario Workflows**

## 🌟 **Scenario 1: Feature Development**

**Purpose:** Develop new functionality in isolation with live development environment

### **When to Use:**
- Building new features
- Adding functionality
- Implementing user stories
- Experimental development

### **Prerequisites:**
- Clean develop branch
- No uncommitted changes

### **Entry Point:**
```bash
# Ensure clean starting state
gco develop                  # git-safe-checkout develop
gp origin develop           # git-safe-push (pull latest)

# Start new feature
gffs user-dashboard          # git-enhanced-feature-start
```

**What `gffs user-dashboard` does:**
1. Validates feature name format (lowercase-with-hyphens)
2. Executes `git flow feature start user-dashboard`
3. Creates `feature/user-dashboard` branch from develop
4. Switches to **local environment** (port 7700)
5. Enables full source mounting (frontend + backend)
6. Provides development tips

**Environment State After Entry:**
- **Branch:** `feature/user-dashboard`
- **Environment:** Local development (port 7700)
- **Source Mounting:** ✅ Full (instant code changes)
- **Access Points:** 
  - Frontend: http://localhost:7700
  - Backend: http://localhost:7710
  - Redis: http://localhost:7730

### **Working in Scenario:**

#### **Development Workflow:**
```bash
# Make changes - they appear instantly due to source mounting
vim frontend/components/Dashboard.tsx
vim backend/api/dashboard.py

# Changes are live immediately:
# - Frontend hot reloads at http://localhost:7700
# - Backend auto-reloads at http://localhost:7710
```

#### **Commit Workflow:**
```bash
# Commit frequently with conventional commits
feat "add dashboard layout structure"
feat "implement dashboard data fetching"
fix "resolve dashboard responsive design issues"
test "add unit tests for dashboard components"
docs "update dashboard API documentation"
style "format dashboard code with prettier"
```

#### **Backup/Collaboration:**
```bash
# Push work regularly for backup and collaboration
gp origin feature/user-dashboard    # git-safe-push
```

#### **Testing:**
```bash
# Test your feature in the local environment
curl http://localhost:7710/api/dashboard
curl http://localhost:7710/health

# Frontend testing
# Visit http://localhost:7700/dashboard

# Monitor logs
env-logs backend             # Show backend logs
env-logs frontend            # Show frontend logs
```

### **Scenario Completion:**

#### **Pre-completion Checks:**
```bash
# Ensure all work is committed
gs                           # Check status (should be clean)

# Optional: Clean up commit history
git rebase -i HEAD~5         # Squash WIP commits (no custom alias)
```

#### **Finish Feature:**
```bash
gfff                         # git-enhanced-feature-finish
```

**What `gfff` does:**
1. Validates you're on a feature branch
2. Checks for uncommitted changes
3. Runs optional tests if available
4. Executes `git flow feature finish user-dashboard`
5. Merges feature → develop branch
6. Deletes feature branch
7. Switches to **staging environment** (port 7600)
8. Provides next steps guidance

**Environment State After Completion:**
- **Branch:** `develop`
- **Environment:** Staging (port 7600)
- **Feature:** Integrated and ready for release
- **Access Points:**
  - Frontend: http://localhost:7600 (with your feature)
  - Backend: http://localhost:7610 (with your feature)

#### **Post-completion Actions:**
```bash
# Push completed feature to GitHub
gp origin develop            # git-safe-push

# Optional: Create documentation PR
gh pr create --title "feat: user dashboard completed" \
  --body "Feature implemented and tested" \
  --base develop --head develop
```

### **Exit State:**
- **Location:** develop branch, staging environment
- **Status:** Feature integrated and ready for release
- **Next Options:** Start new feature, prepare release, or test in staging

### **Common Issues & Solutions:**

#### **Issue: Merge Conflicts During `gfff`**
```bash
# If conflicts occur during feature finish:
git status                   # See conflicted files
vim conflicted-file.py       # Resolve conflicts manually
ga conflicted-file.py        # git-safe-add
git commit                   # Complete merge (no custom alias needed)
gfff                         # Retry finish
```

#### **Issue: Tests Fail Before Finish**
```bash
# Fix tests first
npm test                     # Or pytest, etc.
fix "resolve failing tests"
gfff                         # Retry finish
```

---

## 🚨 **Scenario 2: Production Hotfix**

**Purpose:** Fix critical production issues with minimal disruption

### **When to Use:**
- Production bugs affecting users
- Security vulnerabilities
- Critical performance issues
- Data corruption fixes

### **Prerequisites:**
- Production issue identified
- Impact assessment completed

### **Entry Point:**

#### **Save Current Work:**
```bash
# If working on something else, save it first
feat "WIP: checkpoint before emergency hotfix"
gp origin feature/current-work   # git-safe-push for backup
```

#### **Start Hotfix:**
```bash
ghfs 1.2.3                  # git-enhanced-hotfix-start
```

**What `ghfs 1.2.3` does:**
1. Validates version format (semantic versioning)
2. Executes `git flow hotfix start 1.2.3`
3. Creates `hotfix/1.2.3` branch from main (production)
4. Switches to **local environment** (port 7700)
5. Enables full source mounting for rapid development
6. Provides hotfix guidelines

**Environment State After Entry:**
- **Branch:** `hotfix/1.2.3`
- **Environment:** Local development (port 7700)
- **Code Base:** Production code + live editing capability
- **Source Mounting:** ✅ Full (for rapid hotfix development)

### **Working in Scenario:**

#### **Fix Development:**
```bash
# Identify and fix the issue - changes are live
vim backend/api/payments.py
vim frontend/components/PaymentForm.tsx

# Test fix immediately
curl http://localhost:7710/api/payments/test
# Visit http://localhost:7700 to test UI changes
```

#### **Commit Hotfix:**
```bash
fix "resolve payment processing timeout in production API"
```

#### **Backup Hotfix:**
```bash
gp origin hotfix/1.2.3      # git-safe-push for backup
```

#### **Optional: Create Emergency PR:**
```bash
gh pr create --title "HOTFIX: payment processing timeout" \
  --body "Critical production fix for payment failures" \
  --base main --head hotfix/1.2.3
```

### **Testing Options:**

#### **Option A: Test in Staging First (Recommended):**
```bash
# Temporarily merge to develop for staging testing
gco develop                  # git-safe-checkout
git merge hotfix/1.2.3 --no-ff    # Test merge (no custom alias)
env-staging                  # Switch to staging environment (port 7600)

# Test hotfix in staging
curl http://localhost:7610/api/payments/test
# Visit http://localhost:7600 for full testing

# Return to hotfix if satisfied
gco hotfix/1.2.3            # git-safe-checkout
```

#### **Option B: Direct to Production (Emergency):**
```bash
# Skip staging testing for critical issues
# Proceed directly to completion
```

### **Scenario Completion:**

```bash
ghff 1.2.3                  # git-enhanced-hotfix-finish
```

**What `ghff 1.2.3` does:**
1. Validates you're on hotfix branch
2. Checks for uncommitted changes
3. Requests confirmation for critical operation
4. Executes `git flow hotfix finish 1.2.3`
5. Merges hotfix → main (production)
6. Merges hotfix → develop (staging)
7. Creates tag v1.2.3
8. Deletes hotfix branch
9. Switches to **production environment** (port 7500)

**Environment State After Completion:**
- **Branch:** `main`
- **Environment:** Production (port 7500)
- **Hotfix:** Applied to both production and staging
- **Access Points:**
  - Frontend: http://localhost:7500 (with hotfix)
  - Backend: http://localhost:7510 (with hotfix)

#### **Post-completion Actions:**
```bash
# Push everything to GitHub
gp origin main develop --tags    # git-safe-push

# Create GitHub release
gh release create v1.2.3 \
  --title "Hotfix v1.2.3: Payment Processing Fix" \
  --notes "Critical fix for payment timeout issues"
```

### **Return to Previous Work:**
```bash
# Go back to your previous feature
gco feature/current-work     # git-safe-checkout (auto-switches to local env)

# Pull hotfix into your feature branch
git rebase develop           # Include hotfix in your feature (no custom alias)

# Continue feature development with hotfix included
```

### **Exit State:**
- **Production:** Fixed and stable
- **Staging:** Updated with hotfix
- **Feature Branches:** Need manual update with `git rebase develop`

---

## 🚀 **Scenario 3: Release Preparation**

**Purpose:** Prepare staging features for production deployment

### **When to Use:**
- Multiple features completed in staging
- Ready for version bump (v1.x → v2.0)
- Scheduled release window
- Feature freeze period

### **Prerequisites:**
- Features completed and tested in staging
- Staging environment stable
- Release planning completed

### **Entry Point:**

#### **Verify Staging Readiness:**
```bash
env-staging                  # Switch to staging environment (port 7600)
env-health                   # Check environment health

# Test all features in staging
curl http://localhost:7610/health
curl http://localhost:7610/api/dashboard
curl http://localhost:7610/api/analytics
# Visit http://localhost:7600 for full UI testing
```

#### **Start Release:**
```bash
grs 2.0.0                   # git-enhanced-release-start
```

**What `grs 2.0.0` does:**
1. Validates version format (semantic versioning)
2. Executes `git flow release start 2.0.0`
3. Creates `release/2.0.0` branch from develop
4. Switches to **local environment** (port 7700)
5. Enables source mounting for release preparation
6. Provides release checklist

**Environment State After Entry:**
- **Branch:** `release/2.0.0`
- **Environment:** Local development (port 7700)
- **Code Base:** All staging features + live editing for final prep
- **Source Mounting:** ✅ Full (for release preparation tasks)

### **Working in Scenario:**

#### **Version Management:**
```bash
# Update version numbers
vim package.json             # "version": "2.0.0"
vim backend/api/config.py    # VERSION = "2.0.0"
vim pyproject.toml           # version = "2.0.0"
```

#### **Documentation Updates:**
```bash
# Update release documentation
vim CHANGELOG.md             # Document all v2.0.0 changes
vim README.md                # Update installation/usage docs
vim docs/api.md              # Update API documentation
```

#### **Release Preparation Commits:**
```bash
chore "bump version to 2.0.0 across all packages"
docs "update changelog for v2.0.0 release"
docs "update README with v2.0.0 features"
```

#### **Release Candidate Testing:**
```bash
# Test release candidate in local environment
curl http://localhost:7710/health
curl http://localhost:7710/api/version    # Should return 2.0.0

# Full application testing
# Visit http://localhost:7700 for comprehensive testing
```

#### **Team Collaboration:**
```bash
# Push release branch for team review
gp origin release/2.0.0      # git-safe-push

# Create release PR for approval
gh pr create --title "Release v2.0.0: Dashboard & Analytics Platform" \
  --body "Production release containing:\n- User Dashboard\n- Analytics System\n- Authentication\n- Performance Improvements" \
  --base main --head release/2.0.0
```

### **Release Checklist:**
```bash
# Verify all components
echo "📋 Release Checklist for v2.0.0:"
echo "□ Version numbers updated"
echo "□ Changelog documented" 
echo "□ API documentation updated"
echo "□ Security review completed"
echo "□ Performance testing passed"
echo "□ Breaking changes documented"
echo "□ Migration guides created"
echo "□ Team approval received"
```

### **Scenario Completion:**

#### **Final Release:**
```bash
grf 2.0.0                   # git-enhanced-release-finish
```

**What `grf 2.0.0` does:**
1. Validates you're on release branch
2. Checks for uncommitted changes
3. Requests final confirmation for production deployment
4. Executes `git flow release finish 2.0.0`
5. Merges release → main (production)
6. Merges release → develop (staging)
7. Creates tag v2.0.0
8. Deletes release branch
9. Switches to **production environment** (port 7500)

**Environment State After Completion:**
- **Branch:** `main`
- **Environment:** Production (port 7500)
- **Release:** v2.0.0 live in production
- **Access Points:**
  - Frontend: http://localhost:7500 (v2.0.0)
  - Backend: http://localhost:7510 (v2.0.0)

#### **Post-release Actions:**
```bash
# Push everything to GitHub
gp origin main develop --tags    # git-safe-push

# Create GitHub release with assets
gh release create v2.0.0 \
  --title "MagmaBI v2.0.0 - Dashboard & Analytics Platform" \
  --notes-file CHANGELOG.md \
  --latest

# Notify stakeholders
echo "🎉 v2.0.0 deployed to production!"
```

### **Exit State:**
- **Production:** Running v2.0.0
- **Staging:** Updated for v3.0.0 development
- **Ready for:** New feature development on develop branch

---

## ⚡ **Scenario 4: Team Feature Integration**

**Purpose:** Integrate multiple completed features that weren't finished using `gfff`

### **When to Use:**
- Features completed by external developers
- PR-based workflow integration
- Features finished outside enhanced Git Flow
- Mixed development workflow cleanup

### **Prerequisites:**
- Multiple feature branches exist but aren't in develop
- Features have been completed and tested individually

### **Entry Point:**

#### **Assess Integration Needs:**
```bash
env-staging                  # Switch to staging environment
gl                          # Check what's currently in develop

# Check available feature branches
git branch -r | grep feature/
# Example output:
# origin/feature/user-dashboard (Developer A)
# origin/feature/analytics-reports (Developer B)
# origin/feature/user-authentication (Developer C)
```

#### **Prepare for Integration:**
```bash
# Ensure develop is current
gp origin develop           # git-safe-push (pulls latest)
```

### **Working in Scenario:**

#### **Integration Process (Sequential):**

##### **Feature 1: User Dashboard**
```bash
# Integrate first feature
git merge origin/feature/user-dashboard --no-ff
# Note: No custom alias - need specific merge control

# Test integration in staging
curl http://localhost:7610/api/dashboard
# Visit http://localhost:7600/dashboard for UI testing

# If integration successful
gp origin develop           # git-safe-push
git branch -d feature/user-dashboard           # Clean up local
gp origin --delete feature/user-dashboard      # git-safe-push delete remote
```

##### **Feature 2: Analytics Reports**
```bash
# Integrate second feature
git merge origin/feature/analytics-reports --no-ff

# Test with first feature (integration testing)
curl http://localhost:7610/api/analytics
curl http://localhost:7610/api/dashboard    # Ensure still works
# Visit http://localhost:7600 for full testing

# If conflicts occur
git status                   # See conflicted files
vim conflicted-file.py       # Resolve conflicts
ga conflicted-file.py        # git-safe-add
git commit                   # Complete merge

# If integration successful
gp origin develop           # git-safe-push
# Clean up branches...
```

##### **Feature 3: User Authentication**
```bash
# Integrate third feature
git merge origin/feature/user-authentication --no-ff

# Comprehensive testing (all features together)
curl http://localhost:7610/api/auth/login
curl http://localhost:7610/api/dashboard
curl http://localhost:7610/api/analytics
# Visit http://localhost:7600 for complete user flow testing

# Final integration
gp origin develop           # git-safe-push
# Clean up branches...
```

#### **Alternative: PR-Based Integration**
```bash
# If using GitHub PRs instead of direct merges
gh pr merge 123 --squash     # user-dashboard PR
gh pr merge 124 --squash     # analytics-reports PR  
gh pr merge 125 --squash     # user-authentication PR

# Pull integrated changes
gp origin develop           # git-safe-push (pulls merged changes)
```

### **Integration Testing:**
```bash
# Full system testing with all features
env-health                   # Check environment health
env-logs backend             # Monitor backend logs
env-logs frontend            # Monitor frontend logs

# Performance testing
curl -X POST http://localhost:7610/api/load-test
```

### **Scenario Completion:**
```bash
# All features now integrated in staging
gp origin develop           # git-safe-push final state

# Document integration
feat "integrate user dashboard, analytics, and authentication features"
```

### **Exit State:**
- **Branch:** develop (staging environment)
- **Features:** All integrated and tested together
- **Next Step:** Ready for release preparation (Scenario 3)

---

## 🔄 **Scenario 5: Hotfix Distribution**

**Purpose:** Apply completed hotfixes to all active feature branches

### **When to Use:**
- Hotfix completed using `ghff`
- Multiple developers have active feature branches
- Need to sync hotfix across all development work

### **Prerequisites:**
- Hotfix completed and in both main and develop
- Multiple active feature branches exist

### **Entry Point:**

#### **Verify Hotfix Distribution:**
```bash
env-staging                  # Check develop has hotfix
gl                          # git log --oneline (verify hotfix exists)
# Should show: "Merge branch 'hotfix/1.2.3' into develop"
```

#### **Identify Active Branches:**
```bash
git branch -r | grep feature/
# Example output:
# origin/feature/user-profile (your work)
# origin/feature/reporting-system (teammate A)
# origin/feature/admin-panel (teammate B)
```

### **Working in Scenario:**

#### **Update Your Feature Branch:**
```bash
gco feature/user-profile     # git-safe-checkout (auto-switches to local env)

# Pull hotfix into your feature
git rebase develop           # Include hotfix (no custom alias available)
# Alternative: git merge develop (creates merge commit)

# Test your feature with hotfix
curl http://localhost:7710/health    # Should include hotfix
curl http://localhost:7710/api/user-profile

# Push updated feature
gp --force-with-lease origin feature/user-profile  # git-safe-push
```

#### **Coordinate Team Updates:**

##### **Create Update Script:**
```bash
cat > update-all-features.sh << 'EOF'
#!/bin/bash
echo "🔄 Updating all feature branches with hotfix v1.2.3..."

# List of active feature branches
FEATURE_BRANCHES=(
    "feature/reporting-system"
    "feature/admin-panel" 
    "feature/data-export"
)

for branch in "${FEATURE_BRANCHES[@]}"; do
    if git show-ref --verify --quiet refs/heads/$branch; then
        echo "📝 Updating $branch..."
        git checkout $branch
        git rebase develop
        git push --force-with-lease origin $branch
        echo "✅ $branch updated"
    else
        echo "⚠️  $branch not found locally"
    fi
done

echo "🎉 All feature branches updated with hotfix"
EOF

chmod +x update-all-features.sh
```

##### **Execute Team Updates:**
```bash
# Run the update script
./update-all-features.sh

# Or manually update each branch
gco feature/reporting-system   # git-safe-checkout
git rebase develop
gp --force-with-lease origin feature/reporting-system

gco feature/admin-panel        # git-safe-checkout  
git rebase develop
gp --force-with-lease origin feature/admin-panel
```

#### **Notify Team:**
```bash
# Create notification
echo "📢 Team Notification: Hotfix v1.2.3 Distribution"
echo ""
echo "Hotfix v1.2.3 has been applied to production and staging."
echo "Please update your feature branches:"
echo ""
echo "  git checkout your-feature-branch"
echo "  git rebase develop"
echo "  git push --force-with-lease origin your-feature-branch"
echo ""
echo "Alternatively, run: ./update-all-features.sh"
```

### **Verification:**
```bash
# Verify all branches have hotfix
for branch in feature/user-profile feature/reporting-system feature/admin-panel; do
    echo "🔍 Checking $branch for hotfix..."
    git checkout $branch
    if git log --oneline | grep -q "resolve payment"; then
        echo "✅ $branch: Has hotfix"
    else
        echo "❌ $branch: Missing hotfix"
    fi
done
```

### **Scenario Completion:**
```bash
# Return to your main work
gco feature/user-profile     # git-safe-checkout

# All feature branches now include hotfix
# Development can continue normally
```

### **Exit State:**
- **All Active Features:** Updated with hotfix
- **Production:** Stable with hotfix
- **Staging:** Updated with hotfix
- **Development:** Can continue normally

---

## 🧪 **Scenario 6: Multi-Environment Testing**

**Purpose:** Test functionality across production, staging, and local environments

### **When to Use:**
- Comparing behavior across environments
- Validating deployments
- Performance testing
- Bug investigation
- Version comparison

### **Prerequisites:**
- Multiple environments available
- Features to test deployed

### **Entry Point:**

#### **Setup Multiple Terminals:**

##### **Terminal 1: Production Testing**
```bash
env-prod                     # Production environment (port 7500)
env-health                   # Verify production health
```

##### **Terminal 2: Staging Testing**
```bash
env-staging                  # Staging environment (port 7600)
env-health                   # Verify staging health
```

##### **Terminal 3: Local Development**
```bash
gco feature/your-work        # git-safe-checkout (auto-switches to local 7700)
env-health                   # Verify local health
```

### **Working in Scenario:**

#### **Comparative Testing:**

##### **Health Checks:**
```bash
# Terminal 1 (Production)
curl http://localhost:7510/health

# Terminal 2 (Staging)  
curl http://localhost:7610/health

# Terminal 3 (Local)
curl http://localhost:7710/health
```

##### **Feature Testing:**
```bash
# Test same endpoint across environments
# Production (stable version)
curl -X POST http://localhost:7510/api/analytics/report

# Staging (next version)
curl -X POST http://localhost:7610/api/analytics/report

# Local (development version)
curl -X POST http://localhost:7710/api/analytics/report
```

##### **Performance Comparison:**
```bash
# Performance testing script
cat > test-performance.sh << 'EOF'
#!/bin/bash
echo "🚀 Performance Testing Across Environments"
echo "=========================================="

for env in 7510 7610 7710; do
    echo ""
    echo "Testing port $env:"
    for i in {1..5}; do
        response_time=$(curl -w "%{time_total}" -s -o /dev/null "http://localhost:$env/health")
        echo "  Request $i: ${response_time}s"
    done
done
EOF

chmod +x test-performance.sh
./test-performance.sh
```

#### **Environment Status Monitoring:**
```bash
# Check all environments simultaneously
env-status                   # Overall status display

# Monitor logs across environments
# Terminal 1: env-logs backend  (production logs)
# Terminal 2: env-logs backend  (staging logs)  
# Terminal 3: env-logs backend  (local logs)
```

#### **Data Consistency Testing:**
```bash
# Test data flow and consistency
# Create test data in local
curl -X POST http://localhost:7710/api/test-data -d '{"test": true}'

# Check if it appears correctly in staging
curl http://localhost:7610/api/test-data

# Verify production remains unaffected
curl http://localhost:7510/api/test-data
```

### **Issue Investigation:**

#### **Bug Reproduction:**
```bash
# Reproduce issue in production
curl -X POST http://localhost:7510/api/problematic-endpoint

# Test fix in staging
curl -X POST http://localhost:7610/api/problematic-endpoint

# Develop fix in local
curl -X POST http://localhost:7710/api/problematic-endpoint
```

#### **Environment-Specific Debugging:**
```bash
# Check environment-specific configurations
env-logs backend | grep "ENVIRONMENT="
# Should show: production, staging, development
```

### **Scenario Completion:**
```bash
# Document findings
cat > test-results-$(date +%Y%m%d).md << 'EOF'
# Multi-Environment Test Results

## Environment Status
- Production (7500): ✅ Stable, v1.2.3
- Staging (7600): ✅ Good, v2.0.0-rc  
- Local (7700): 🔄 Development, feature in progress

## Performance Results
- Production: 0.15s average response
- Staging: 0.18s average response  
- Local: 0.25s average response (with debugging)

## Issues Found
- None critical
- Minor: Staging has verbose logging enabled

## Recommendations
- Production ready for normal operation
- Staging ready for release promotion
- Local development proceeding normally
EOF

# Return to single environment
gco feature/your-work        # Back to local development
```

### **Exit State:**
- **Production:** Verified stable
- **Staging:** Tested and validated
- **Local:** Ready for continued development

---

## 🔍 **Scenario 7: Production Investigation (Debug Mode)**

**Purpose:** Investigate production issues with source code access

### **When to Use:**
- Production bugs need source-level investigation
- Need to trace through production code
- Performance debugging required
- Understanding production behavior

### **⚠️ Important Notes:**
- Debug mode is for **investigation only**
- Don't make code changes in production debug mode
- Use local hotfix branches for actual fixes
- Temporarily replaces production environment

### **Prerequisites:**
- Production issue identified
- Investigation required at source level
- Understanding that this replaces production temporarily

### **Entry Point:**

#### **Enable Production Debug Mode:**
```bash
env-prod-debug              # Production with source mounting enabled
```

**What `env-prod-debug` does:**
1. Warns about replacing production environment
2. Requests confirmation
3. Stops production containers
4. Starts production containers with source mounting
5. Uses production configuration but development builds
6. Enables live source code access

**Environment State After Entry:**
- **Branch:** `main` (production code)
- **Environment:** Production debug mode (port 7500)
- **Source Mounting:** ✅ Enabled (for investigation)
- **Configuration:** Production settings
- **Build:** Development build with source access

### **Working in Scenario:**

#### **Issue Investigation:**
```bash
# Investigate production issue with source access
# View logs with source context
env-logs backend

# Trace through actual production code
vim backend/api/payments.py     # Read-only investigation
vim frontend/components/PaymentForm.tsx

# Add debugging statements for investigation (temporary)
echo "console.log('Debug: Payment processing')" >> frontend/components/PaymentForm.tsx
echo "print('Debug: API called')" >> backend/api/payments.py

# Test with debug statements
curl -X POST http://localhost:7510/api/payments/test
# Monitor real-time logs
env-logs backend
```

#### **Performance Investigation:**
```bash
# Monitor resource usage in production debug
env-status                   # Check container resources

# Test performance with source access
curl -w "%{time_total}" http://localhost:7510/api/slow-endpoint

# Investigate bottlenecks
vim backend/api/slow_endpoint.py    # Find performance issues
```

#### **Configuration Investigation:**
```bash
# Check production configuration with source access
cat backend/api/config.py    # View production settings
env-logs backend | grep "ENVIRONMENT=production"

# Verify environment variables
docker exec -it magmabi_backend-prod env | grep API_
```

### **Investigation Best Practices:**

#### **Document Findings:**
```bash
# Create investigation log
cat > investigation-$(date +%Y%m%d-%H%M).md << 'EOF'
# Production Investigation Log

## Issue
- Description: Payment timeout in production
- Started: $(date)
- Environment: Production debug mode

## Findings
- Line 45 in payments.py has blocking call
- Frontend timeout set to 30s, backend takes 45s
- Production database has higher latency

## Root Cause
- Missing async handling in payment processor
- No timeout configuration for external API

## Recommended Fix
- Add async/await to payment processing
- Configure timeout for external calls
- Add retry logic for failed payments
EOF
```

#### **Prepare Fix Strategy:**
```bash
# Document the fix approach (don't implement here)
echo "🔧 Fix Strategy:" >> investigation-$(date +%Y%m%d-%H%M).md
echo "1. Create hotfix branch in local environment" >> investigation-$(date +%Y%m%d-%H%M).md
echo "2. Implement async payment processing" >> investigation-$(date +%Y%m%d-%H%M).md
echo "3. Add proper timeout handling" >> investigation-$(date +%Y%m%d-%H%M).md
echo "4. Test in local, then staging" >> investigation-$(date +%Y%m%d-%H%M).md
echo "5. Deploy via standard hotfix process" >> investigation-$(date +%Y%m%d-%H%M).md
```

### **Scenario Completion:**

#### **Exit Debug Mode:**
```bash
env-prod                     # Return to normal production mode
```

**What this does:**
1. Stops production debug containers
2. Starts normal production containers (built images)
3. Removes source mounting
4. Restores production security

#### **Implement Fix (Separate Process):**
```bash
# Now create proper hotfix in local environment
ghfs 1.2.4                  # Start hotfix in local environment

# Implement the fix based on investigation
vim backend/api/payments.py  # Add async handling
vim backend/api/config.py    # Add timeout config

# Test fix in local environment (port 7700)
curl -X POST http://localhost:7710/api/payments/test

# Complete standard hotfix process
fix "implement async payment processing with timeout handling"
ghff 1.2.4                  # Deploy hotfix to production
```

### **Exit State:**
- **Production:** Restored to normal operation
- **Investigation:** Completed with documented findings
- **Fix:** Implemented via proper hotfix process

---

## 📊 **Scenario 8: Container Management**

**Purpose:** Manage container environments, health, and resources

### **When to Use:**
- Container troubleshooting
- Resource management
- Environment cleanup
- Health monitoring
- Log analysis

### **Prerequisites:**
- Basic container understanding
- Access to container management commands

### **Entry Point:**

#### **Environment Assessment:**
```bash
env-status                   # Overall environment status
```

**What `env-status` shows:**
- Running environments and ports
- Container health status
- Resource usage
- Available commands

### **Working in Scenario:**

#### **Health Management:**

##### **Comprehensive Health Check:**
```bash
env-health                   # Check all environments
```

**What `env-health` does:**
1. Tests all environment endpoints
2. Checks container status
3. Verifies port accessibility
4. Reports resource usage
5. Identifies issues

##### **Individual Environment Health:**
```bash
# Check specific environment
env-prod && env-health       # Production health
env-staging && env-health    # Staging health  
env-local && env-health      # Local health
```

#### **Log Management:**

##### **View Container Logs:**
```bash
env-logs                     # All services current environment
env-logs backend             # Specific service logs
env-logs frontend            # Frontend logs
env-logs redis               # Redis logs
env-logs celery_worker       # Celery worker logs
```

##### **Monitor Live Logs:**
```bash
# Follow logs in real-time
env-logs backend --follow    # Live backend logs
env-logs frontend --follow   # Live frontend logs

# Filter logs
env-logs backend | grep ERROR        # Error messages only
env-logs backend | grep "API called" # Specific log pattern
```

#### **Environment Control:**

##### **Stop Environments:**
```bash
env-stop                     # Stop all environments (with confirmation)
env-stop prod               # Stop production only
env-stop staging            # Stop staging only  
env-stop local              # Stop local only
env-stop all                # Stop all (forced)
```

##### **Restart Environments:**
```bash
# Restart current environment
env-staging                  # Restarts staging
env-prod                    # Restarts production
env-local                   # Restarts local
```

##### **Resource Management:**
```bash
# Check Docker resources
docker system df            # Disk usage
docker stats               # Live resource usage

# Clean up unused resources
docker system prune -f     # Remove unused containers/images
docker volume prune -f     # Remove unused volumes
```

#### **Troubleshooting:**

##### **Container Issues:**
```bash
# Check container status
docker ps -a | grep magmabi

# Inspect specific container
docker inspect magmabi_backend-prod

# Execute commands in container
docker exec -it magmabi_backend-prod bash
```

##### **Network Issues:**
```bash
# Test container networking
docker network ls | grep magmabi

# Test port accessibility
curl -v http://localhost:7510/health    # Production
curl -v http://localhost:7610/health    # Staging
curl -v http://localhost:7710/health    # Local
```

##### **Volume Issues:**
```bash
# Check volume mounts
docker volume ls | grep magmabi

# Inspect volume contents
docker run --rm -v magmabi_redis_data_prod:/data alpine ls -la /data
```

#### **Environment Switching Management:**

##### **Force Environment Switch:**
```bash
# When automatic switching fails
env-stop all               # Stop everything
env-prod                   # Start fresh production
```

##### **Debug Environment Issues:**
```bash
# Check environment detection
git branch --show-current  # Current branch
docker ps                  # Running containers

# Manual container management
cd docker
docker compose -f docker-compose.prod.yml ps       # Production status
docker compose -f docker-compose.staging.yml ps    # Staging status
docker compose -f docker-compose.local.yml ps      # Local status
```

#### **Performance Monitoring:**

##### **Resource Usage:**
```bash
# Monitor container resources
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check environment performance
for port in 7510 7610 7710; do
    echo "Testing port $port:"
    curl -w "Time: %{time_total}s\n" -s -o /dev/null "http://localhost:$port/health"
done
```

##### **Health Trends:**
```bash
# Create health monitoring script
cat > monitor-health.sh << 'EOF'
#!/bin/bash
while true; do
    echo "$(date): Health Check"
    env-health
    echo "---"
    sleep 300  # Check every 5 minutes
done
EOF

chmod +x monitor-health.sh
# Run in background: ./monitor-health.sh > health.log 2>&1 &
```

### **Scenario Completion:**
```bash
# Document environment state
env-status > environment-status-$(date +%Y%m%d).txt

# Return to development work
gco feature/your-work        # Resume development
```

### **Exit State:**
- **Containers:** Healthy and optimized
- **Resources:** Cleaned and monitored  
- **Logs:** Analyzed and documented
- **Environment:** Ready for development

---

## 🗑️ **Scenario 9: Feature Abandonment**

**Purpose:** Remove unwanted features at different stages of development

### **When to Use:**
- Feature requirements changed
- Feature no longer needed
- Feature implementation flawed
- Strategic direction changed

### **Prerequisites:**
- Decision to abandon feature confirmed
- Understanding of feature's current state

### **Entry Point:**

#### **Assess Feature State:**
```bash
# Check where the feature exists
git branch -a | grep feature/unwanted-feature
git log --oneline --grep="unwanted-feature"
```

### **Working in Scenario:**

#### **Case 1: Feature Only Exists Locally**

**When:** Feature never pushed to remote, only local development

```bash
# Simple local cleanup
gco develop                  # git-safe-checkout away from feature
git branch -D feature/unwanted-feature    # Delete local branch
```

**Result:** ✅ Feature completely removed, no trace

#### **Case 2: Feature Pushed but Not Merged**

**When:** Feature exists on GitHub but not merged to develop/main

```bash
# Clean up local and remote
gco develop                  # git-safe-checkout to safe branch
git branch -D feature/unwanted-feature           # Delete local branch
gp origin --delete feature/unwanted-feature      # git-safe-push delete remote

# Close any associated PRs
gh pr list --head feature/unwanted-feature       # Check for PRs
gh pr close 123              # Close PR if exists
```

**Result:** ✅ Feature removed from everywhere, PRs closed

#### **Case 3: Feature Already in Staging (develop)**

**When:** Feature merged to develop and in staging environment

##### **Preparation:**
```bash
env-staging                  # Switch to staging environment
gl                          # git log --oneline (find merge commit)

# Test current staging state
curl http://localhost:7610/api/unwanted-endpoint
# Visit http://localhost:7600 to see feature in staging
```

##### **Revert the Feature:**
```bash
# Find the merge commit
git log --oneline --grep="unwanted-feature"
# Example output: abc123d Merge branch 'feature/unwanted-feature' into develop

# Revert the merge commit
git revert abc123d -m 1     # Revert to parent 1 (develop branch)
feat "remove unwanted feature - requirements changed"
```

##### **Test Removal:**
```bash
# Verify feature removed from staging
curl http://localhost:7610/api/unwanted-endpoint    # Should return 404
# Visit http://localhost:7600 to verify UI changes removed

# Push removal
gp origin develop           # git-safe-push
```

##### **Cleanup:**
```bash
# Remove feature branches if they still exist
gp origin --delete feature/unwanted-feature      # git-safe-push delete remote
git branch -D feature/unwanted-feature           # Delete local if exists
```

**Result:** ✅ Feature functionality removed from staging, history preserved

#### **Case 4: Feature Already in Production (main)**

**When:** Feature is live and causing production issues

⚠️ **Critical Process - Use Emergency Hotfix:**

##### **Emergency Removal Hotfix:**
```bash
ghfs 1.2.4                  # git-enhanced-hotfix-start for removal
```

##### **Remove Feature from Production:**
```bash
# Remove feature functionality (in local hotfix environment)
vim backend/api/routes.py        # Remove unwanted endpoints
vim frontend/components/App.tsx  # Remove unwanted components
vim backend/database/models.py   # Remove unwanted database changes

# Test removal locally
curl http://localhost:7710/api/unwanted-endpoint    # Should return 404
# Visit http://localhost:7700 to verify feature removed
```

##### **Document Removal:**
```bash
fix "emergency removal of problematic feature causing production issues"
docs "document feature removal and migration steps for users"
```

##### **Deploy Removal:**
```bash
ghff 1.2.4                  # git-enhanced-hotfix-finish
# Applies removal to both main (production) and develop (staging)

# Push everything
gp origin main develop --tags    # git-safe-push

# Create emergency release documentation
gh release create v1.2.4 \
  --title "Emergency Release: Remove Problematic Feature" \
  --notes "Emergency removal of feature causing production instability"
```

**Result:** ✅ Feature removed from production and staging, proper hotfix process followed

#### **Case 5: Feature in Release Branch**

**When:** Feature in release preparation but needs removal

```bash
# Switch to release branch
gco release/2.0.0           # git-safe-checkout

# Remove feature from release
git revert <feature-merge-commit> -m 1
feat "remove feature from v2.0.0 release - deferred to v2.1.0"

# Test release without feature
curl http://localhost:7710/api/unwanted-endpoint    # Should return 404

# Push updated release
gp origin release/2.0.0     # git-safe-push
```

### **Documentation and Communication:**

#### **Document Abandonment:**
```bash
# Create abandonment record
cat > ABANDONED-FEATURES.md << 'EOF'
# Abandoned Features Log

## Feature: Unwanted Feature System
- **Abandoned Date:** $(date)
- **Reason:** Requirements changed, no longer needed
- **Stage:** Staging/Production
- **Removal Method:** Git revert / Emergency hotfix
- **Impact:** None - feature was not widely used
- **Migration:** No user migration needed

## Cleanup Actions Taken
- [x] Removed from staging (develop)
- [x] Removed from production (main) 
- [x] Deleted feature branches
- [x] Closed related PRs
- [x] Updated documentation

## Related Issues/PRs
- Issue #123: Original feature request
- PR #456: Feature implementation (reverted)
- Issue #789: Feature removal request
EOF
```

#### **Team Communication:**
```bash
# Notify team of abandonment
echo "📢 Feature Abandonment Notice"
echo ""
echo "Feature 'unwanted-feature' has been removed from:"
echo "- ✅ Staging environment"
echo "- ✅ Production environment (if applicable)"
echo "- ✅ All remote branches"
echo ""
echo "Reason: Requirements changed"
echo "Impact: No user migration required"
echo ""
echo "Related branches cleaned up:"
echo "- feature/unwanted-feature (deleted)"
echo ""
echo "If you have local copies, please clean up with:"
echo "  git branch -D feature/unwanted-feature"
```

### **Scenario Completion:**
```bash
# Verify complete removal
git branch -a | grep unwanted    # Should return nothing
gh pr list --state all | grep unwanted    # Check PRs cleaned up

# Return to normal development
gco develop                  # git-safe-checkout
env-staging                  # Verify staging without feature
```

### **Exit State:**
- **Feature:** Completely removed from all relevant environments
- **Branches:** Cleaned up locally and remotely
- **Documentation:** Updated with abandonment record
- **Team:** Notified of changes

---

## ⚠️ **Scenario 10: Hotfix Abandonment**

**Purpose:** Abandon hotfix development when issue is resolved differently

### **When to Use:**
- Alternative solution found
- Issue resolved by other means
- Hotfix approach incorrect
- Emergency situation changed

### **Prerequisites:**
- Hotfix currently in development
- Decision to abandon confirmed

### **Entry Point:**

#### **Assess Hotfix State:**
```bash
# Check current hotfix status
git branch --show-current    # Should be hotfix/x.y.z
gl                          # Check commits in hotfix
```

### **Working in Scenario:**

#### **Case 1: Hotfix Not Yet Pushed**

**When:** Hotfix exists only locally

```bash
# Simple abandonment
gco main                     # git-safe-checkout to main
git branch -D hotfix/1.2.3   # Delete hotfix branch
env-prod                     # Return to production environment
```

#### **Case 2: Hotfix Pushed but Not Merged**

**When:** Hotfix branch exists on GitHub, possibly with PR

```bash
# Clean up local and remote
gco main                     # git-safe-checkout to main  
git branch -D hotfix/1.2.3               # Delete local branch
gp origin --delete hotfix/1.2.3          # git-safe-push delete remote

# Close hotfix PR if exists
gh pr list --head hotfix/1.2.3           # Check for PR
gh pr close 456 --comment "Alternative solution implemented"    # Close with reason

env-prod                     # Return to production environment
```

#### **Case 3: Alternative Solution Implemented**

**When:** Different hotfix or solution was deployed instead

```bash
# Document why hotfix abandoned
feat "abandon hotfix 1.2.3 - alternative solution deployed as 1.2.4"

# Push documentation
gp origin hotfix/1.2.3      # git-safe-push final commit

# Then clean up
gco main                     # git-safe-checkout
git branch -D hotfix/1.2.3   # Delete local
gp origin --delete hotfix/1.2.3  # git-safe-push delete remote
```

#### **Case 4: Issue Resolved by Other Team**

**When:** Another team/developer fixed the issue

```bash
# Check if issue actually resolved
env-prod                     # Check production environment
curl http://localhost:7510/api/problematic-endpoint    # Test issue

# If resolved, abandon hotfix
gco main                     # git-safe-checkout
git branch -D hotfix/1.2.3   # No longer needed
```

### **Documentation:**

#### **Record Abandonment:**
```bash
# Create abandonment record
cat > hotfix-abandonment-$(date +%Y%m%d).md << 'EOF'
# Hotfix Abandonment Record

## Hotfix Details
- **Version:** 1.2.3
- **Issue:** Payment processing timeout
- **Started:** $(date -d '1 hour ago')
- **Abandoned:** $(date)

## Abandonment Reason
- Alternative solution found
- Issue resolved by infrastructure team
- Different approach proved more effective

## Resolution
- Production issue resolved via database optimization
- No code changes required
- Hotfix branch cleaned up

## Actions Taken
- [x] Deleted hotfix/1.2.3 branch locally
- [x] Deleted hotfix/1.2.3 branch remotely  
- [x] Closed related PR #456
- [x] Verified production issue resolved
- [x] Notified stakeholders
EOF
```

#### **Stakeholder Communication:**
```bash
# Notify stakeholders
echo "📢 Hotfix Abandonment Notice"
echo ""
echo "Hotfix v1.2.3 for payment processing timeout has been abandoned."
echo ""
echo "✅ Issue Status: RESOLVED"
echo "🔧 Resolution: Database optimization by infrastructure team"
echo "📅 Resolved: $(date)"
echo ""
echo "No code deployment required."
echo "Production is stable and performing normally."
echo ""
echo "Hotfix branch hotfix/1.2.3 has been cleaned up."
```

### **Verification:**

#### **Confirm Issue Resolution:**
```bash
# Test production thoroughly
env-health                   # Overall production health
curl http://localhost:7510/api/payments/test    # Test problematic endpoint

# Monitor for stability
env-logs backend | tail -50  # Check recent logs
```

#### **Clean State Verification:**
```bash
# Verify hotfix completely removed
git branch -a | grep hotfix/1.2.3    # Should return nothing
gh pr list --state all | grep 1.2.3  # Check PRs

# Confirm production environment normal
env-status                   # Should show clean production state
```

### **Scenario Completion:**
```bash
# Return to normal operations
env-prod                     # Ensure production environment active

# Resume normal development
gco develop                  # git-safe-checkout to staging
# Ready for normal development workflow
```

### **Exit State:**
- **Hotfix:** Completely abandoned and cleaned up
- **Issue:** Resolved by alternative means
- **Production:** Stable and monitored
- **Team:** Informed of resolution

---

## 🔄 **Scenario 11: Emergency Scenario Switching**

**Purpose:** Rapidly switch between scenarios during emergencies

### **When to Use:**
- Production emergency during feature development
- Critical hotfix needed during release preparation
- Urgent testing required during normal development
- Multiple priority issues simultaneously

### **Prerequisites:**
- Current work can be safely paused
- Emergency situation confirmed

### **Entry Point:**

#### **Emergency Assessment:**
```bash
# Quick status check
gs                           # Current git status
env-status                   # Current environment status
git branch --show-current    # What you're working on
```

### **Working in Scenario:**

#### **Pattern 1: Feature Development → Emergency Hotfix**

**Current State:** Working on feature

##### **Emergency Save:**
```bash
# Rapid work preservation
feat "WIP: emergency checkpoint before critical hotfix"
gp origin feature/current-work    # git-safe-push backup
```

##### **Emergency Switch:**
```bash
ghfs 1.2.4                  # git-enhanced-hotfix-start (immediate switch)
# Environment automatically switches to local (port 7700)
# Can implement hotfix with full source mounting
```

##### **Emergency Fix:**
```bash
# Implement critical fix rapidly
vim backend/api/critical-endpoint.py
fix "emergency fix for critical production issue"

# Test immediately
curl http://localhost:7710/api/critical-endpoint

# Deploy immediately
ghff 1.2.4                  # git-enhanced-hotfix-finish (to production)
```

##### **Return to Feature:**
```bash
gco feature/current-work     # git-safe-checkout (auto-switches back to local)
git rebase develop           # Include emergency hotfix
# Continue feature development with fix included
```

#### **Pattern 2: Release Preparation → Production Investigation**

**Current State:** Preparing release

##### **Preserve Release State:**
```bash
# On release/2.0.0 branch
chore "pause release preparation for production investigation"
gp origin release/2.0.0     # git-safe-push backup
```

##### **Investigate Production:**
```bash
env-prod-debug              # Switch to production debug mode
# Investigate issue with source access

# Document findings
echo "Issue found in production..." > investigation-notes.txt
```

##### **Return to Release:**
```bash
env-prod                    # Exit debug mode
gco release/2.0.0           # git-safe-checkout back to release
env-local                   # Resume release preparation environment
# Continue release preparation
```

#### **Pattern 3: Multiple Concurrent Emergencies**

**Current State:** Multiple urgent issues

##### **Terminal Management:**
```bash
# Terminal 1: Handle hotfix
ghfs 1.2.5                  # Emergency hotfix

# Terminal 2: Monitor production  
env-prod-debug              # Production investigation

# Terminal 3: Test in staging
env-staging                 # Staging validation

# Terminal 4: Continue feature work
gco feature/important-work   # Local development
```

##### **Priority Management:**
```bash
# Focus on highest priority first
# Terminal 1: Complete critical hotfix
fix "resolve database connection leak"
ghff 1.2.5

# Terminal 2: Exit debug when hotfix deployed
env-prod                    # Return to normal production

# Terminal 3: Test hotfix in staging
gp origin develop           # git-safe-push updated develop

# Terminal 4: Update feature with hotfix
git rebase develop          # Include hotfix in feature
```

#### **Pattern 4: Environment Failure Recovery**

**Current State:** Environment failure during work

##### **Emergency Diagnosis:**
```bash
env-health                  # Check all environments
env-status                  # Identify failed environment
```

##### **Rapid Recovery:**
```bash
# Stop failed environment
env-stop local              # Stop problematic environment

# Switch to working environment
env-staging                 # Move to staging temporarily

# Restart failed environment
env-local                   # Restart local environment

# Verify recovery
env-health                  # Confirm all environments healthy
```

##### **Continue Work:**
```bash
gco feature/your-work       # Return to work (auto-switches to local)
# Resume development in recovered environment
```

#### **Pattern 5: Cross-Environment Emergency Testing**

**Current State:** Need to test fix across all environments rapidly

##### **Rapid Multi-Environment Setup:**
```bash
# Terminal 1: Deploy fix to production
ghff 1.2.6                  # Emergency hotfix deployment

# Terminal 2: Test in staging
env-staging
curl http://localhost:7610/api/fixed-endpoint

# Terminal 3: Verify in local
env-local
curl http://localhost:7710/api/fixed-endpoint

# Terminal 4: Monitor production
env-prod
env-logs backend --follow
```

##### **Coordinated Verification:**
```bash
# Script for rapid testing across environments
cat > emergency-test.sh << 'EOF'
#!/bin/bash
echo "🚨 Emergency Testing Across All Environments"
echo "============================================"

for port in 7510 7610 7710; do
    echo ""
    echo "Testing port $port:"
    response=$(curl -s "http://localhost:$port/api/fixed-endpoint")
    if [[ $? -eq 0 ]]; then
        echo "✅ Port $port: SUCCESS"
    else
        echo "❌ Port $port: FAILED"
    fi
done
EOF

chmod +x emergency-test.sh
./emergency-test.sh
```

### **Emergency Communication:**

#### **Stakeholder Updates:**
```bash
# Rapid status communication
cat > emergency-status.md << 'EOF'
# Emergency Response Status

## Issue
- Critical production endpoint failure
- Started: $(date -d '30 minutes ago')
- Impact: Payment processing affected

## Response Actions
- [x] Emergency hotfix deployed (v1.2.6)
- [x] Production verified stable
- [x] Staging updated and tested
- [x] Local development environment updated

## Current Status
- ✅ Production: Stable and operational
- ✅ Payments: Processing normally
- ✅ All environments: Healthy

## Next Steps
- Continue monitoring for 1 hour
- Update feature branches with hotfix
- Resume normal development operations
EOF
```

### **Emergency Recovery:**

#### **Return to Normal Operations:**
```bash
# Verify all environments stable
env-health                  # Comprehensive health check

# Update all active work with emergency fix
gco feature/current-work    # Return to feature work
git rebase develop          # Include emergency hotfix

# Resume normal development
feat "resume feature development after emergency fix"
```

#### **Post-Emergency Review:**
```bash
# Document emergency response
cat > emergency-response-review.md << 'EOF'
# Emergency Response Review

## Timeline
- Issue detected: $(date -d '1 hour ago')
- Response initiated: $(date -d '45 minutes ago')  
- Fix deployed: $(date -d '30 minutes ago')
- Recovery confirmed: $(date -d '15 minutes ago')

## Response Effectiveness
- ✅ Rapid scenario switching worked well
- ✅ Emergency commands functioned correctly
- ✅ Multi-environment testing was effective
- ✅ Minimal disruption to ongoing work

## Improvements Identified
- Consider automated emergency testing
- Enhance monitoring for early detection
- Document emergency response procedures

## Tools That Worked Well
- ghfs/ghff for rapid hotfix deployment
- env-prod-debug for production investigation
- Multi-terminal environment management
- Emergency testing scripts
EOF
```

### **Scenario Completion:**
```bash
# Full system verification
env-status                  # All environments status
git branch --show-current   # Confirm current work
gs                          # Working directory status

# Ready for normal operations
echo "🎉 Emergency response complete - systems normal"
```

### **Exit State:**
- **Emergency:** Resolved and deployed
- **Environments:** All stable and healthy
- **Development:** Resumed with emergency fix included
- **Documentation:** Emergency response recorded

---

## 📋 **Scenario 12: Pull Request Workflows**

**Purpose:** Manage GitHub Pull Request workflows with enhanced Git Flow

### **When to Use:**
- Team collaboration required
- Code review process needed
- External contributor integration
- Formal approval workflows

### **Prerequisites:**
- GitHub repository configured
- Team members have access
- GitHub CLI installed (`gh`)

### **Entry Point:**

#### **Choose PR Strategy:**

**Strategy A: Feature-First (Complete locally, then PR)**
**Strategy B: PR-First (Create PR early, develop collaboratively)**

### **Working in Scenario:**

#### **Strategy A: Feature-First PR Workflow**

##### **Complete Feature Locally:**
```bash
gffs user-authentication    # Start feature locally
feat "implement OAuth2 integration"
feat "add user session management"  
gfff                        # Complete feature → develop
```

##### **Create Documentation PR:**
```bash
# Push completed feature
gp origin develop           # git-safe-push

# Create PR for record keeping and deployment
gh pr create \
  --title "feat: user authentication system" \
  --body "## Summary
Complete OAuth2 authentication system with session management.

## Features Added
- OAuth2 provider integration
- Session management
- User profile endpoints
- Security middleware

## Testing
- ✅ Local testing complete
- ✅ Staging integration verified
- ✅ Security review passed

## Deployment
Ready for production deployment." \
  --base main \
  --head develop
```

##### **Immediate Merge (if approved):**
```bash
gh pr merge --merge         # Preserve commit history
# OR
gh pr merge --squash        # Single commit
```

#### **Strategy B: PR-First Collaborative Workflow**

##### **Create Early PR (Draft):**
```bash
gffs collaborative-feature  # Start feature
feat "initial structure for collaborative feature"
gp origin feature/collaborative-feature    # git-safe-push

# Create draft PR immediately
gh pr create \
  --title "WIP: collaborative feature development" \
  --body "## Work in Progress
Collaborative development of new feature.

## TODO
- [ ] Core functionality
- [ ] Unit tests
- [ ] Integration tests
- [ ] Documentation
- [ ] Security review

## Collaboration Welcome
Please review and contribute to this feature." \
  --base develop \
  --head feature/collaborative-feature \
  --draft
```

##### **Collaborative Development:**
```bash
# Continue development with team input
feat "implement core functionality based on team feedback"
gp origin feature/collaborative-feature    # git-safe-push updates PR

# Team members can contribute
# They can checkout the branch and add commits
```

##### **Ready for Review:**
```bash
# Mark PR as ready
gh pr ready                 # Remove draft status

# Request specific reviewers
gh pr edit --add-reviewer @teammate1,@teammate2
```

##### **Handle Review Feedback:**
```bash
# Address review comments
fix "resolve security concerns raised in PR review"
refactor "improve error handling as suggested by reviewer"
gp origin feature/collaborative-feature    # git-safe-push updates PR
```

##### **Merge After Approval:**
```bash
# After approvals received
gh pr merge --squash        # Squash commits for clean history
```

#### **Strategy C: Release PR Workflow**

##### **Create Release PR:**
```bash
grs 2.1.0                   # Start release preparation
chore "bump version to 2.1.0"
docs "update changelog for v2.1.0"
gp origin release/2.1.0     # git-safe-push

# Create release PR for stakeholder review
gh pr create \
  --title "Release v2.1.0: Enhanced Analytics & Performance" \
  --body "## Release Summary
Version 2.1.0 includes major analytics enhancements and performance improvements.

## New Features
- Advanced analytics dashboard
- Real-time performance monitoring
- Enhanced user authentication
- Mobile-responsive design improvements

## Performance Improvements
- 40% faster API response times
- Reduced memory usage by 25%
- Optimized database queries
- Enhanced caching strategies

## Bug Fixes
- Fixed payment processing timeout
- Resolved dashboard loading issues
- Corrected mobile layout problems

## Breaking Changes
- API endpoint `/v1/old-endpoint` deprecated (use `/v2/new-endpoint`)
- Configuration format updated (see migration guide)

## Migration Guide
Included in docs/MIGRATION-v2.1.0.md

## Testing
- ✅ Full regression testing complete
- ✅ Performance testing passed
- ✅ Security audit completed
- ✅ Staging deployment verified

Ready for production deployment." \
  --base main \
  --head release/2.1.0
```

##### **Stakeholder Review Process:**
```bash
# Stakeholders review in staging
env-staging                 # They can test at staging URLs

# Address any final concerns
fix "address final stakeholder feedback on analytics display"
gp origin release/2.1.0     # git-safe-push updates PR

# Get final approval
gh pr review --approve      # Self-approve if authorized
```

##### **Production Deployment:**
```bash
# After all approvals
gh pr merge --merge         # Preserve release history
grf 2.1.0                   # Complete release process (if not done by PR merge)
```

#### **Strategy D: Hotfix PR Workflow**

##### **Emergency Hotfix PR:**
```bash
ghfs 1.2.7                  # Emergency hotfix
fix "resolve critical security vulnerability"
gp origin hotfix/1.2.7     # git-safe-push

# Create emergency PR
gh pr create \
  --title "URGENT HOTFIX: Security vulnerability fix" \
  --body "## ⚠️ CRITICAL SECURITY FIX

**Issue:** SQL injection vulnerability in user input validation
**Impact:** HIGH - Potential data breach
**Urgency:** IMMEDIATE deployment required

## Fix Description
- Added proper input sanitization
- Implemented parameterized queries  
- Enhanced validation middleware

## Testing
- ✅ Local vulnerability testing passed
- ✅ Security scan clean
- ✅ No functional regression

## Deployment Required
This fix needs immediate production deployment.

**Security team approval:** @security-team
**Operations approval:** @ops-team" \
  --base main \
  --head hotfix/1.2.7 \
  --reviewer @security-team,@ops-team
```

##### **Fast-Track Approval:**
```bash
# Monitor for rapid approvals
gh pr checks               # Check status
gh pr status              # View review status

# Deploy immediately after approval
gh pr merge --squash      # Fast deployment
ghff 1.2.7               # Complete hotfix if not auto-triggered
```

### **Advanced PR Management:**

#### **PR Templates and Automation:**

##### **Create PR Templates:**
```bash
# Create PR template for features
mkdir -p .github/pull_request_template
cat > .github/pull_request_template/feature.md << 'EOF'
## Feature Description
Brief description of the feature and its purpose.

## Changes Made
- [ ] Core functionality implemented
- [ ] Unit tests added
- [ ] Integration tests added
- [ ] Documentation updated
- [ ] Security review completed

## Testing
- [ ] Local testing completed
- [ ] Staging deployment verified
- [ ] Performance impact assessed

## Breaking Changes
- [ ] No breaking changes
- [ ] Breaking changes documented in CHANGELOG.md

## Screenshots (if applicable)
<!-- Add screenshots for UI changes -->

## Related Issues
Closes #[issue-number]
EOF
```

##### **PR Automation with GitHub Actions:**
```bash
# Create PR automation workflow
mkdir -p .github/workflows
cat > .github/workflows/pr-automation.yml << 'EOF'
name: PR Automation

on:
  pull_request:
    branches: [main, develop]

jobs:
  validate-pr:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate PR Title
        run: |
          if [[ "${{ github.event.pull_request.title }}" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .+ ]]; then
            echo "✅ PR title follows conventional commits"
          else
            echo "❌ PR title must follow conventional commits format"
            exit 1
          fi
      
      - name: Check for Breaking Changes
        run: |
          if grep -q "BREAKING CHANGE" "${{ github.event.pull_request.body }}"; then
            echo "⚠️ Breaking changes detected - ensure proper documentation"
          fi

  auto-assign-reviewers:
    runs-on: ubuntu-latest
    steps:
      - name: Assign Reviewers
        uses: kentaro-m/auto-assign-action@v1.2.4
        with:
          configuration-path: .github/auto-assign.yml
EOF
```

#### **PR Review Management:**

##### **Review Assignment:**
```bash
# Auto-assign reviewers based on files changed
cat > .github/auto-assign.yml << 'EOF'
addReviewers: true
addAssignees: true

reviewers:
  - backend-team
  - frontend-team

assignees:
  - lead-developer

numberOfReviewers: 2
numberOfAssignees: 1

skipKeywords:
  - wip
  - draft

fileBasedReviewers:
  "backend/**": ["@backend-team"]
  "frontend/**": ["@frontend-team"]
  "docker/**": ["@devops-team"]
  "docs/**": ["@tech-writers"]
EOF
```

##### **Review Checklist:**
```bash
# Create review checklist template
cat > .github/PULL_REQUEST_TEMPLATE.md << 'EOF'
## Review Checklist

### Code Quality
- [ ] Code follows project conventions
- [ ] No code smells or anti-patterns
- [ ] Proper error handling implemented
- [ ] Performance considerations addressed

### Testing
- [ ] Unit tests cover new functionality
- [ ] Integration tests updated if needed
- [ ] Manual testing completed
- [ ] Edge cases considered

### Security
- [ ] No sensitive data exposed
- [ ] Input validation implemented
- [ ] Authentication/authorization correct
- [ ] No obvious security vulnerabilities

### Documentation
- [ ] Code is self-documenting or commented
- [ ] API documentation updated
- [ ] README updated if needed
- [ ] Migration guide provided for breaking changes

### Deployment
- [ ] Database migrations included if needed
- [ ] Environment variables documented
- [ ] Deployment notes provided
- [ ] Rollback plan considered
EOF
```

#### **Cross-Environment PR Testing:**

##### **PR Environment Setup:**
```bash
# Create PR-specific testing environment
gh pr checkout 123          # Checkout PR locally

# Test PR in local environment
env-local                   # Switch to local environment
curl http://localhost:7710/api/pr-feature

# Create PR testing branch for staging
git checkout develop
git merge --no-ff pr-branch-123    # Temporary merge for testing
env-staging                 # Test in staging environment
curl http://localhost:7610/api/pr-feature

# Clean up after testing
git reset --hard HEAD~1     # Remove temporary merge
```

##### **Automated PR Testing:**
```bash
# GitHub Actions for PR testing
cat > .github/workflows/pr-testing.yml << 'EOF'
name: PR Testing

on:
  pull_request:
    branches: [develop]

jobs:
  test-pr:
    runs-on: ubuntu-latest
    services:
      redis:
        image: redis
        ports:
          - 6379:6379
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
      
      - name: Install Dependencies
        run: |
          pip install poetry
          poetry install
      
      - name: Run Tests
        run: |
          poetry run pytest
          poetry run flake8
      
      - name: Build Docker Images
        run: |
          docker build -t pr-test-backend -f backend/Dockerfile.dev .
          docker build -t pr-test-frontend -f frontend/Dockerfile.dev .
      
      - name: Integration Testing
        run: |
          docker-compose -f docker-compose.test.yml up -d
          sleep 30
          curl http://localhost:8000/health
          docker-compose -f docker-compose.test.yml down
EOF
```

### **Scenario Completion:**

#### **PR Metrics and Reporting:**
```bash
# Generate PR statistics
gh pr list --state merged --limit 50 --json number,title,author,createdAt,mergedAt \
  --jq '.[] | {number, title, author: .author.login, days_open: (((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 86400 | floor)}' \
  > pr-metrics.json

# Create PR summary report
cat > pr-summary-$(date +%Y%m%d).md << 'EOF'
# Pull Request Summary Report

## Recent PR Activity (Last 30 days)
- Total PRs merged: $(gh pr list --state merged --limit 100 | wc -l)
- Average time to merge: X days
- Most active contributors: $(gh pr list --state merged --limit 50 --json author --jq '.[].author.login' | sort | uniq -c | sort -nr | head -5)

## PR Categories
- Features: $(gh pr list --state merged --search "feat" | wc -l)
- Bug fixes: $(gh pr list --state merged --search "fix" | wc -l)
- Documentation: $(gh pr list --state merged --search "docs" | wc -l)
- Hotfixes: $(gh pr list --state merged --search "hotfix" | wc -l)

## Review Process Health
- Average reviews per PR: X
- PRs requiring multiple rounds: X%
- Emergency PRs (hotfixes): $(gh pr list --state merged --search "hotfix urgent" | wc -l)
EOF
```

### **Exit State:**
- **PR Workflow:** Established and documented
- **Team Collaboration:** Streamlined with automation
- **Code Quality:** Maintained through review process
- **Deployment:** Coordinated with PR merging

---

## 🏷️ **Scenario 13: Release Management**

**Purpose:** Comprehensive release management with GitHub integration

### **When to Use:**
- Coordinating major version releases
- Managing release communications
- Automating release processes
- Tracking release metrics

### **Prerequisites:**
- Release ready in staging
- Stakeholder approval received
- Release documentation prepared

### **Entry Point:**

#### **Pre-Release Preparation:**
```bash
env-staging                 # Verify staging environment
env-health                  # Ensure staging is healthy

# Verify all features integrated
gl                          # Check recent commits in develop
```

### **Working in Scenario:**

#### **Release Branch Strategy:**

##### **Create Release Branch:**
```bash
grs 2.2.0                   # git-enhanced-release-start
```

##### **Release Preparation:**
```bash
# Version management across all files
find . -name "package.json" -exec sed -i 's/"version": ".*"/"version": "2.2.0"/' {} \;
find . -name "pyproject.toml" -exec sed -i 's/version = ".*"/version = "2.2.0"/' {} \;
find . -name "Dockerfile*" -exec sed -i 's/LABEL version=".*"/LABEL version="2.2.0"/' {} \;

# Update configuration files
vim backend/api/config.py   # Update VERSION constant
vim frontend/src/config.js  # Update version info

chore "bump version to 2.2.0 across all components"
```

##### **Release Documentation:**
```bash
# Comprehensive changelog
cat > CHANGELOG-2.2.0.md << 'EOF'
# Changelog v2.2.0

## 🚀 New Features
- **Advanced Analytics Dashboard** - Real-time data visualization with interactive charts
- **Mobile Responsive Design** - Full mobile optimization for all views
- **Enhanced User Authentication** - OAuth2 integration with popular providers
- **API Rate Limiting** - Intelligent request throttling for better performance

## 🐛 Bug Fixes
- Fixed payment processing timeout issues (#123)
- Resolved dashboard loading performance problems (#145)
- Corrected mobile layout inconsistencies (#167)
- Fixed memory leak in real-time data processing (#189)

## 🔧 Improvements
- 40% faster API response times through query optimization
- Reduced bundle size by 25% through code splitting
- Enhanced error handling and user feedback
- Improved accessibility compliance (WCAG 2.1 AA)

## 🔒 Security
- Updated all dependencies to latest secure versions
- Enhanced input validation and sanitization
- Improved authentication token handling
- Added rate limiting to prevent abuse

## 💔 Breaking Changes
- **API Endpoint Changes**: `/api/v1/analytics` moved to `/api/v2/analytics`
- **Configuration Format**: Database configuration format updated
- **Deprecated Features**: Legacy dashboard removed (use new analytics dashboard)

## 🔄 Migration Guide
See [MIGRATION-v2.2.0.md](./docs/MIGRATION-v2.2.0.md) for detailed upgrade instructions.

## 📊 Performance Metrics
- API Response Time: Improved from 200ms to 120ms average
- Memory Usage: Reduced by 25%
- Bundle Size: Reduced from 2.5MB to 1.9MB
- Test Coverage: Increased to 95%
EOF

docs "add comprehensive changelog for v2.2.0 release"
```

##### **Migration Guide Creation:**
```bash
mkdir -p docs
cat > docs/MIGRATION-v2.2.0.md << 'EOF'
# Migration Guide: v2.1.x → v2.2.0

## Overview
This guide helps you migrate from v2.1.x to v2.2.0, including breaking changes and new features.

## Breaking Changes

### 1. API Endpoint Updates
**Old:** `/api/v1/analytics`
**New:** `/api/v2/analytics`

**Migration:**
```javascript
// Before
fetch('/api/v1/analytics')

// After  
fetch('/api/v2/analytics')
```

### 2. Configuration Format Changes
**Old configuration (config.yml):**
```yaml
database:
  host: localhost
  port: 5432
  name: myapp
```

**New configuration (config.yml):**
```yaml
database:
  connection:
    host: localhost
    port: 5432
    database: myapp
  pool:
    min: 5
    max: 20
```

### 3. Deprecated Feature Removal
- Legacy dashboard (`/legacy-dashboard`) removed
- Old authentication endpoints (`/auth/legacy/*`) removed

## New Features Setup

### 1. Enable Advanced Analytics
Add to your configuration:
```yaml
analytics:
  enabled: true
  real_time: true
  retention_days: 90
```

### 2. Configure OAuth2 Providers
```yaml
auth:
  oauth2:
    google:
      client_id: your_google_client_id
      client_secret: your_google_client_secret
    github:
      client_id: your_github_client_id
      client_secret: your_github_client_secret
```

## Database Migrations
Run the following migrations in order:

```bash
# Backup your database first!
pg_dump myapp > backup-before-v2.2.0.sql

# Run migrations
./manage.py migrate analytics
./manage.py migrate auth_oauth2
./manage.py migrate performance_improvements
```

## Environment Variables
New required environment variables:
```bash
ANALYTICS_ENABLED=true
OAUTH2_GOOGLE_CLIENT_ID=your_client_id
OAUTH2_GOOGLE_CLIENT_SECRET=your_client_secret
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=100
```

## Testing Your Migration
1. **Backup everything** before starting
2. **Test in staging first** with production data copy
3. **Verify all integrations** work with new endpoints
4. **Check performance** meets expectations
5. **Validate new features** are working correctly

## Rollback Plan
If issues occur, you can rollback:

```bash
# Restore database
psql myapp < backup-before-v2.2.0.sql

# Deploy previous version
git checkout v2.1.x
./deploy.sh
```

## Support
- **Documentation**: https://docs.yourapp.com/v2.2.0
- **Support Email**: support@yourapp.com
- **GitHub Issues**: https://github.com/yourorg/yourapp/issues
EOF

docs "add detailed migration guide for v2.2.0"
```

#### **Release Testing:**

##### **Comprehensive Release Testing:**
```bash
# Test release candidate in local environment
curl http://localhost:7710/health
curl http://localhost:7710/api/v2/analytics
curl http://localhost:7710/api/auth/oauth2/providers

# Frontend testing
# Visit http://localhost:7700 for full UI testing

# Performance testing
cat > test-release-performance.sh << 'EOF'
#!/bin/bash
echo "🚀 Release Performance Testing"
echo "=============================="

echo "Testing API response times..."
for endpoint in health analytics auth/status; do
    echo "Testing /$endpoint:"
    for i in {1..10}; do
        time=$(curl -w "%{time_total}" -s -o /dev/null "http://localhost:7710/api/$endpoint")
        echo "  Request $i: ${time}s"
    done
    echo ""
done

echo "Testing concurrent requests..."
ab -n 100 -c 10 http://localhost:7710/api/health
EOF

chmod +x test-release-performance.sh
./test-release-performance.sh
```

##### **Security Testing:**
```bash
# Security validation
cat > test-release-security.sh << 'EOF'
#!/bin/bash
echo "🔒 Release Security Testing"
echo "=========================="

# Test rate limiting
echo "Testing rate limiting..."
for i in {1..150}; do
    response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:7710/api/analytics")
    if [[ $response == "429" ]]; then
        echo "✅ Rate limiting working - got 429 after $i requests"
        break
    fi
done

# Test authentication
echo "Testing OAuth2 endpoints..."
curl -s "http://localhost:7710/api/auth/oauth2/providers" | jq .

# Test input validation
echo "Testing input validation..."
curl -X POST -H "Content-Type: application/json" \
  -d '{"invalid": "<script>alert(1)</script>"}' \
  "http://localhost:7710/api/analytics"
EOF

chmod +x test-release-security.sh
./test-release-security.sh
```

#### **Release Finalization:**

##### **Create Release PR:**
```bash
# Push release branch
gp origin release/2.2.0     # git-safe-push

# Create comprehensive release PR
gh pr create \
  --title "Release v2.2.0: Advanced Analytics & Performance Enhancements" \
  --body-file CHANGELOG-2.2.0.md \
  --base main \
  --head release/2.2.0 \
  --reviewer @stakeholders,@security-team,@ops-team
```

##### **Stakeholder Review Process:**
```bash
# Provide stakeholder testing environment
echo "📋 Stakeholder Review Information"
echo "================================"
echo ""
echo "🧪 Testing Environment: http://staging.yourapp.com"
echo "📖 Release Notes: See PR description"
echo "🔄 Migration Guide: docs/MIGRATION-v2.2.0.md"
echo ""
echo "✅ Review Checklist:"
echo "- [ ] Feature functionality verified"
echo "- [ ] Performance improvements confirmed"
echo "- [ ] Security review completed"
echo "- [ ] Migration guide reviewed"
echo "- [ ] Rollback plan approved"
echo ""
echo "🎯 Target Deployment: $(date -d '+3 days')"
```

##### **Final Approval and Deployment:**
```bash
# After all approvals received
gh pr merge --merge         # Preserve complete release history

# Complete release process
grf 2.2.0                   # git-enhanced-release-finish (if not auto-triggered)

# Verify production deployment
env-prod                    # Switch to production environment
curl http://localhost:7510/health
curl http://localhost:7510/api/v2/analytics
```

#### **Post-Release Actions:**

##### **GitHub Release Creation:**
```bash
# Create comprehensive GitHub release
gh release create v2.2.0 \
  --title "🚀 MagmaBI v2.2.0 - Advanced Analytics & Performance" \
  --notes-file CHANGELOG-2.2.0.md \
  --latest \
  --discussion-category "Releases"
```

##### **Release Metrics Collection:**
```bash
# Collect release metrics
cat > release-metrics-v2.2.0.md << 'EOF'
# Release Metrics: v2.2.0

## Development Timeline
- **Development Start**: $(date -d '6 weeks ago')
- **Feature Freeze**: $(date -d '1 week ago')
- **Release Date**: $(date)
- **Total Development Time**: 6 weeks

## Code Changes
- **Commits**: $(git rev-list v2.1.0..v2.2.0 --count)
- **Files Changed**: $(git diff --name-only v2.1.0..v2.2.0 | wc -l)
- **Lines Added**: $(git diff --stat v2.1.0..v2.2.0 | tail -1 | awk '{print $4}')
- **Lines Removed**: $(git diff --stat v2.1.0..v2.2.0 | tail -1 | awk '{print $6}')

## Contributors
$(git shortlog -sn v2.1.0..v2.2.0)

## Performance Improvements
- **API Response Time**: 40% faster (200ms → 120ms)
- **Bundle Size**: 24% smaller (2.5MB → 1.9MB)
- **Memory Usage**: 25% reduction
- **Test Coverage**: 95% (up from 88%)

## Quality Metrics
- **Bugs Fixed**: 12
- **Security Issues Resolved**: 3
- **Performance Issues Resolved**: 5
- **New Features**: 4 major, 8 minor

## Deployment Success
- **Downtime**: 0 minutes (rolling deployment)
- **Rollback Required**: No
- **Post-Deployment Issues**: 0 critical, 1 minor
- **User Adoption**: 85% within 24 hours
EOF
```

##### **Team Communication:**
```bash
# Release announcement
cat > release-announcement.md << 'EOF'
# 🎉 Release Announcement: MagmaBI v2.2.0

We're excited to announce the release of MagmaBI v2.2.0, featuring major analytics enhancements and significant performance improvements!

## ✨ What's New
- **Advanced Analytics Dashboard** with real-time data visualization
- **40% faster API performance** through optimization
- **Mobile-responsive design** for better user experience
- **Enhanced security** with OAuth2 integration

## 🚀 Performance Highlights
- API responses now 40% faster
- 25% reduction in memory usage
- Smaller bundle size for faster loading
- 95% test coverage for better reliability

## 📖 For Developers
- **Migration Guide**: docs/MIGRATION-v2.2.0.md
- **API Documentation**: Updated for v2.2.0
- **Breaking Changes**: See changelog for details

## 🔄 Rollout Plan
- **Production Deployment**: Completed $(date)
- **User Migration**: Automatic
- **Support**: Available 24/7 during transition

## 📞 Support
- **Documentation**: https://docs.yourapp.com/v2.2.0
- **Issues**: https://github.com/yourorg/yourapp/issues
- **Support**: support@yourapp.com

Thank you to all contributors who made this release possible!

The MagmaBI Team
EOF

# Send to team channels, stakeholders, users
```

### **Scenario Completion:**

#### **Post-Release Monitoring:**
```bash
# Set up release monitoring
cat > monitor-release.sh << 'EOF'
#!/bin/bash
echo "📊 Post-Release Monitoring v2.2.0"
echo "================================="

# Check production health
echo "Production Health:"
curl -s http://localhost:7510/health | jq .

# Monitor key metrics
echo ""
echo "Key Metrics:"
echo "- API Response Time: $(curl -w "%{time_total}" -s -o /dev/null http://localhost:7510/api/analytics)s"
echo "- Memory Usage: $(docker stats --no-stream --format "{{.MemUsage}}" magmabi_backend-prod)"
echo "- Active Users: $(curl -s http://localhost:7510/api/metrics/users | jq .active_users)"

# Check for errors
echo ""
echo "Recent Errors:"
env-logs backend --tail 20 | grep ERROR || echo "No errors detected"
EOF

chmod +x monitor-release.sh

# Monitor for first 24 hours
echo "Setting up release monitoring for 24 hours..."
# ./monitor-release.sh > release-monitoring-v2.2.0.log 2>&1
```

### **Exit State:**
- **Release:** Successfully deployed to production
- **Documentation:** Complete and accessible
- **Monitoring:** Active and tracking key metrics
- **Team:** Informed and ready for support
- **Next Version:** Development can begin for v2.3.0

---

## 📊 **Scenario Summary Matrix**

| Scenario | Primary Command | Environment | Duration | Complexity | Team Impact |
|----------|----------------|-------------|----------|------------|-------------|
| **1. Feature Development** | `gffs` → `gfff` | Local → Staging | Days-Weeks | Medium | Low |
| **2. Production Hotfix** | `ghfs` → `ghff` | Local → Production | Hours | High | High |
| **3. Release Preparation** | `grs` → `grf` | Local → Production | Days | High | High |
| **4. Team Integration** | `env-staging` + merges | Staging | Hours | Medium | Medium |
| **5. Hotfix Distribution** | `git rebase develop` | Local | Hours | Low | Medium |
| **6. Multi-Environment Testing** | `env-*` commands | All | Hours | Low | Low |
| **7. Production Investigation** | `env-prod-debug` | Production Debug | Hours | Medium | Medium |
| **8. Container Management** | `env-*` commands | Various | Minutes | Low | Low |
| **9. Feature Abandonment** | `git revert` / cleanup | Various | Hours | Medium | Medium |
| **10. Hotfix Abandonment** | Branch cleanup | Various | Minutes | Low | Low |
| **11. Emergency Switching** | Multiple commands | Multiple | Minutes | High | High |
| **12. Pull Request Workflows** | `gh pr` commands | Various | Days | Medium | High |
| **13. Release Management** | `grs` → `grf` + `gh` | All | Days-Weeks | High | High |

---

## 🎯 **Quick Command Reference**

### **🔄 Environment Commands**
```bash
env-prod                    # Production (7500) - built images
env-prod-debug             # Production (7500) - source mounted
env-staging                # Staging (7600) - built images  
env-staging-debug          # Staging (7600) - source mounted
env-local                  # Local (7700) - always source mounted
env-health                 # Health check all environments
env-status                 # Show environment status
env-stop [env]             # Stop environments
env-logs [service]         # View logs
```

### **🌊 Git Flow Commands**
```bash
gffs <name>                # Start feature + local env
gfff                       # Finish feature + staging env
ghfs <version>             # Start hotfix + local env
ghff <version>             # Finish hotfix + production env
grs <version>              # Start release + local env
grf <version>              # Finish release + production env
```

### **💬 Commit Commands**
```bash
feat "description"         # Feature commit
fix "description"          # Bug fix commit
docs "description"         # Documentation commit
test "description"         # Test commit
chore "description"        # Maintenance commit
```

### **🔧 Git Safety Commands**
```bash
gp [args]                  # Safe push
gco <branch>               # Safe checkout + auto env switch
gs                         # Enhanced status
gl                         # Pretty log
```

### **📋 GitHub Commands**
```bash
gh pr create               # Create pull request
gh pr merge --squash       # Merge with squash
gh release create          # Create release
```

This comprehensive guide provides complete coverage of all development scenarios with your custom aliases and functions prioritized over native Git commands, detailed explanations for each workflow step, and proper navigation for easy reference!