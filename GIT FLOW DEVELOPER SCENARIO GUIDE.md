# 🎭 Comprehensive Development Scenarios Guide

## 📋 **Scenario Overview**

This guide covers all real-world development scenarios with clear entry/exit points and switching between scenarios.

### **Available Scenarios:**
1. **Feature Development** - Working on new features
2. **Production Hotfix** - Emergency production fixes
3. **Release Preparation** - Preparing staging for production
4. **Parallel Feature Management** - Multiple features ready for staging
5. **Hotfix Distribution** - Applying hotfixes to all branches
6. **Environment Testing** - Testing across production/staging/local
7. **Feature Abandonment** - Trashing incomplete/unwanted features

---

## 🌟 **Scenario 1: Feature Development**

### **When to Use:** Building new functionality

### **Entry Points:**
```bash
# From clean develop branch
git checkout develop && git pull origin develop
gffs <feature-name>  # git flow feature start + switch to local env
# Example: gffs user-dashboard
```

### **Environment:** Local Development (Port 7700)
- **Frontend:** http://localhost:7700 (live changes)
- **Backend:** http://localhost:7710 (live changes)
- **Source mounting:** ✅ Full (instant feedback)

### **Working in Scenario:**
```bash
# Make changes - they appear instantly due to source mounting
vim frontend/components/Dashboard.tsx
vim backend/api/dashboard.py

# Commit frequently with conventional commits
feat "add dashboard layout structure"
fix "resolve dashboard API integration issue"
test "add dashboard component tests"
docs "update dashboard API documentation"

# Push work regularly for backup
git push origin feature/user-dashboard
```

### **Scenario Completion:**
```bash
# Ensure all work is committed
git status  # Should be clean

# Finish feature
gfff  # git flow feature finish + switch to staging env
# This merges feature → develop and switches to staging (port 7600)

# Push completed feature to GitHub
git push origin develop

# Optional: Create PR record
gh pr create --title "feat: user dashboard" --base develop --head develop
```

### **Exit State:** 
- **Branch:** develop (staging environment, port 7600)
- **Feature:** Integrated and ready for release
- **GitHub:** Updated with completed feature

---

## 🚨 **Scenario 2: Production Hotfix**

### **When to Use:** Critical production issue needs immediate fix

### **Entry Points:**
```bash
# From any current work - save first
git add . && feat "WIP: saving current work"  # Save current progress

# Create hotfix from production
ghfs <version>  # git flow hotfix start + switch to local env
# Example: ghfs 1.2.3
```

### **Environment:** Local Development (Port 7700)
- **Code base:** Production code + your live changes
- **Source mounting:** ✅ Full (for rapid fix development)

### **Working in Scenario:**
```bash
# Fix the critical issue - changes are live
vim backend/api/payments.py
vim frontend/components/PaymentForm.tsx

# Test fix immediately
curl http://localhost:7710/api/payments/test
# Visit http://localhost:7700 to test UI

# Commit the fix
fix "resolve payment processing timeout in production API"
git push origin hotfix/1.2.3

# Optional: Create emergency PR
gh pr create --title "HOTFIX: payment processing timeout" \
  --base main --head hotfix/1.2.3
```

### **Scenario Completion:**
```bash
# Test hotfix in staging first (optional but recommended)
git checkout develop
git merge hotfix/1.2.3 --no-ff  # Test merge
env-staging  # Switch to staging (port 7600)
curl http://localhost:7610/api/payments/test  # Test in staging

# Go back and finish hotfix
git checkout hotfix/1.2.3
ghff 1.2.3  # git flow hotfix finish + switch to production env
# This merges hotfix → main AND develop, creates tag, switches to prod (port 7500)

# Push everything to GitHub
git push origin main develop --tags

# Create GitHub release
gh release create v1.2.3 --title "Hotfix v1.2.3: Payment Processing"
```

### **Exit State:** 
- **Branch:** main (production environment, port 7500)
- **Fix:** Applied to both production and staging
- **GitHub:** Updated with hotfix and new tag

### **Return to Previous Work:**
```bash
# Go back to your previous feature work
git checkout feature/user-dashboard
env-local  # Switch to local env (port 7700)

# Pull hotfix into your feature branch
git rebase develop  # This includes the hotfix
# Continue feature development with hotfix included
```

---

## 🚀 **Scenario 3: Release Preparation**

### **When to Use:** Multiple features ready, preparing for production release

### **Entry Points:**
```bash
# From staging with completed features
git checkout develop
env-staging  # Test all features (port 7600)

# Verify staging is ready
curl http://localhost:7610/health
curl http://localhost:7600

# Start release
grs <version>  # git flow release start + switch to local env
# Example: grs 2.0.0
```

### **Environment:** Local Development (Port 7700)
- **Code base:** All staging features + live editing for final touches
- **Source mounting:** ✅ Full (for release preparation)

### **Working in Scenario:**
```bash
# Make final release preparations
vim package.json              # Update version: "2.0.0"
vim backend/api/config.py     # Update VERSION = "2.0.0"
vim CHANGELOG.md              # Document changes
vim README.md                 # Update documentation

# Commit release preparation
chore "bump version to 2.0.0"
docs "update changelog for v2.0.0 release"

# Test release candidate
curl http://localhost:7710/health
# Visit http://localhost:7700 for full testing

# Push release branch for team review
git push origin release/2.0.0

# Optional: Create release PR for approval
gh pr create --title "Release v2.0.0" \
  --body "Production release with dashboard, auth, analytics" \
  --base main --head release/2.0.0
```

### **Scenario Completion:**
```bash
# Finish release - GO LIVE!
grf 2.0.0  # git flow release finish + switch to production env
# This merges release → main AND develop, creates tag, switches to prod (port 7500)

# Verify production deployment
curl http://localhost:7510/health  # Production with v2.0.0
curl http://localhost:7500         # Frontend with v2.0.0

# Push everything to GitHub
git push origin main develop --tags

# Create GitHub release
gh release create v2.0.0 \
  --title "MagmaBI v2.0.0 - Dashboard & Analytics" \
  --notes-file CHANGELOG.md --latest
```

### **Exit State:** 
- **Branch:** main (production environment, port 7500)
- **Release:** v2.0.0 live in production
- **Next development:** Ready to start v3.0 features on develop

---

## ⚡ **Scenario 4: Parallel Feature Management**

### **When to Use:** Multiple team members have completed features ready for staging

### **Initial State:** Multiple completed features waiting
```bash
# Available completed features:
# - feature/user-dashboard (Developer A)
# - feature/analytics-reports (Developer B)  
# - feature/user-authentication (Developer C)
```

### **Entry Points:**
```bash
# Start from clean develop
git checkout develop && git pull origin develop
env-staging  # Staging environment (port 7600)
```

### **Parallel Integration Process:**

#### **Step 1: Integrate First Feature**
```bash
# Merge first feature
git merge feature/user-dashboard --no-ff
# OR use: git checkout feature/user-dashboard && gfff

# Test in staging
curl http://localhost:7610/api/dashboard
# Visit http://localhost:7600 to test UI

# If good, push to staging
git push origin develop

# Clean up
git branch -d feature/user-dashboard
git push origin --delete feature/user-dashboard
```

#### **Step 2: Integrate Second Feature**
```bash
# Merge second feature  
git merge feature/analytics-reports --no-ff

# Test integration with first feature
curl http://localhost:7610/api/analytics
curl http://localhost:7610/api/dashboard  # Ensure still works

# If conflicts or issues:
git reset --hard HEAD~1  # Undo merge
# Fix conflicts or issues, then retry

# If good, push to staging
git push origin develop

# Clean up
git branch -d feature/analytics-reports
git push origin --delete feature/analytics-reports
```

#### **Step 3: Integrate Third Feature**
```bash
# Merge third feature
git merge feature/user-authentication --no-ff

# Test all features together
curl http://localhost:7610/api/auth/login
curl http://localhost:7610/api/dashboard
curl http://localhost:7610/api/analytics

# Comprehensive testing
# Visit http://localhost:7600 for full user flow testing

# If all good, push to staging
git push origin develop

# Clean up
git branch -d feature/user-authentication  
git push origin --delete feature/user-authentication
```

### **Scenario Completion:**
```bash
# All features now integrated in staging
git push origin develop

# Staging environment (port 7600) now has all features
# Ready for release preparation (Scenario 3)
```

### **Exit State:**
- **Branch:** develop (staging environment, port 7600)
- **Features:** All integrated and tested together
- **Next step:** Ready for release or continue with more features

---

## 🔄 **Scenario 5: Hotfix Distribution**

### **When to Use:** Hotfix applied to production, need to update all active branches

### **Initial State:** Hotfix completed
```bash
# Hotfix v1.2.3 was just applied to main and develop
# Active feature branches need updating:
# - feature/user-profile (Developer A working)
# - feature/reporting-system (Developer B working)
# - feature/admin-panel (Developer C working)
```

### **Entry Points:**
```bash
# Hotfix just completed (you're on main)
git checkout develop
git log --oneline -3  # Verify hotfix is in develop
# Should show: "Merge branch 'hotfix/1.2.3' into develop"
```

### **Distribution Process:**

#### **Step 1: Update Your Own Feature Branch**
```bash
# Switch to your active feature
git checkout feature/user-profile
env-local  # Local environment (port 7700)

# Pull hotfix into your feature
git rebase develop
# OR: git merge develop (creates merge commit)

# Test your feature with hotfix
curl http://localhost:7710/health  # Should include hotfix
# Continue your feature development

# Push updated feature
git push --force-with-lease origin feature/user-profile
```

#### **Step 2: Coordinate Team Updates**
```bash
# Notify team members
echo "Hotfix v1.2.3 applied. Please update your feature branches:"
echo "git checkout feature/your-branch"
echo "git rebase develop"
echo "git push --force-with-lease origin feature/your-branch"

# Or create script for team:
cat > update-branches.sh << 'EOF'
#!/bin/bash
echo "Updating all feature branches with hotfix..."

for branch in feature/reporting-system feature/admin-panel; do
    if git show-ref --verify --quiet refs/heads/$branch; then
        echo "Updating $branch..."
        git checkout $branch
        git rebase develop
        git push --force-with-lease origin $branch
    fi
done

echo "All branches updated with hotfix v1.2.3"
EOF
chmod +x update-branches.sh
```

#### **Step 3: Verify All Branches Updated**
```bash
# Check each branch has the hotfix
git checkout feature/user-profile
git log --oneline | grep "resolve payment"  # Should show hotfix

git checkout feature/reporting-system  
git log --oneline | grep "resolve payment"  # Should show hotfix

git checkout feature/admin-panel
git log --oneline | grep "resolve payment"  # Should show hotfix
```

### **Scenario Completion:**
```bash
# All feature branches now include hotfix
# Development can continue normally
# Next feature completions will include the hotfix
```

### **Exit State:**
- **All active feature branches:** Updated with hotfix
- **Staging:** Has hotfix (from ghff automatic merge)  
- **Production:** Has hotfix and is stable
- **Development:** Can continue normally

---

## 🧪 **Scenario 6: Environment Testing**

### **When to Use:** Need to test across multiple environments or compare versions

### **Entry Points:**
```bash
# Can start from any scenario
# Goal: Test the same feature/fix across environments
```

### **Multi-Environment Setup:**

#### **Terminal 1: Production Testing**
```bash
env-prod  # git checkout main + production containers (port 7500)
# Tests current live version

curl http://localhost:7510/health
curl http://localhost:7510/api/payments
# Visit http://localhost:7500 for UI testing

# No source mounting - tests actual production builds
```

#### **Terminal 2: Staging Testing**  
```bash
env-staging  # git checkout develop + staging containers (port 7600)
# Tests next version with all integrated features

curl http://localhost:7610/health  
curl http://localhost:7610/api/payments
# Visit http://localhost:7600 for UI testing

# Frontend source mounted - can make quick UI fixes
```

#### **Terminal 3: Local Development**
```bash
git checkout feature/your-work
env-local  # Local containers (port 7700)
# Tests your current feature work

curl http://localhost:7710/health
curl http://localhost:7710/api/payments  
# Visit http://localhost:7700 for UI testing

# Full source mounting - all changes live
```

### **Comparative Testing Process:**
```bash
# Test same endpoint across environments
curl -X POST http://localhost:7510/api/test-data  # Production
curl -X POST http://localhost:7610/api/test-data  # Staging
curl -X POST http://localhost:7710/api/test-data  # Local

# Compare responses, performance, behavior
# Document any differences

# Load testing across environments
for env in 7510 7610 7710; do
    echo "Testing port $env:"
    for i in {1..10}; do
        curl -s "http://localhost:$env/health" || echo "Failed $env"
    done
done
```

### **Scenario Completion:**
```bash
# Document findings
echo "Environment test results:" > test-results.md
echo "Production: Stable, v1.2.3" >> test-results.md  
echo "Staging: Good, v2.0.0-rc" >> test-results.md
echo "Local: Development, feature in progress" >> test-results.md

# Return to single environment for continued work
git checkout feature/your-work  # Back to feature development
```

---

## 🗑️ **Scenario 7: Feature Abandonment**

### **When to Use:** Need to trash incomplete or unwanted features

### **Entry Points:**
```bash
# Can happen from any state
# Decision made: Feature is no longer needed
```

### **Abandonment Strategies:**

#### **Case 1: Feature Only Exists Locally**
```bash
# Feature never pushed to remote
git checkout develop
git branch -D feature/unwanted-feature
# ✅ Completely gone, no trace
```

#### **Case 2: Feature Pushed but Not Merged**
```bash
# Feature exists on GitHub but not in develop/main
git checkout develop
git branch -D feature/unwanted-feature           # Delete local
git push origin --delete feature/unwanted-feature  # Delete remote

# Clean up any associated PRs
gh pr close feature/unwanted-feature
# ✅ Completely removed from everywhere
```

#### **Case 3: Feature Already in Staging (develop)**
```bash
git checkout develop
env-staging  # Test what's currently in staging (port 7600)

# Find the merge commit
git log --oneline --grep="unwanted-feature"
# Example output: abc123d Merge branch 'feature/unwanted-feature' into develop

# Revert the merge
git revert abc123d -m 1
feat "remove unwanted feature - requirements changed"

# Test staging without the feature
curl http://localhost:7610/api/unwanted-endpoint  # Should return 404
# Visit http://localhost:7600 to verify UI changes

# Push the reversion
git push origin develop

# Clean up branches
git push origin --delete feature/unwanted-feature  # If still exists
```

#### **Case 4: Feature Already in Production (main)**
```bash
# CRITICAL: Feature is live and needs emergency removal
ghfs 1.2.4  # Create hotfix for removal
env-local   # Local environment (port 7700)

# Remove the feature functionality
vim backend/api/routes.py        # Remove unwanted endpoints
vim frontend/components/App.tsx  # Remove unwanted components

# Commit removal
fix "remove unwanted feature causing production issues"

# Test removal
curl http://localhost:7710/api/unwanted-endpoint  # Should return 404

# Finish hotfix
ghff 1.2.4  # Applies removal to both main and develop

# Push everything
git push origin main develop --tags

# Create emergency release
gh release create v1.2.4 --title "Emergency: Remove Problematic Feature"
```

### **Scenario Completion:**
```bash
# Feature successfully removed from appropriate branches
# No trace remains (or properly documented removal)
# Development can continue normally
```

---

## 🔄 **Scenario Switching Guide**

### **Quick Scenario Switches:**

#### **From Feature Development → Hotfix**
```bash
# Save current feature work
git add . && feat "WIP: feature progress checkpoint"

# Switch to hotfix
ghfs 1.2.4  # Automatic environment switch to local (port 7700)
# Work on hotfix...
ghff 1.2.4  # Complete hotfix

# Return to feature
git checkout feature/your-work  # Automatic environment switch
git rebase develop  # Pull in the hotfix
# Continue feature work with hotfix included
```

#### **From Feature Development → Release**
```bash
# Complete current feature first
feat "complete feature implementation"
gfff  # Merge to develop

# Start release
grs 2.0.0  # Automatic environment switch to local (port 7700)
# Prepare release...
grf 2.0.0  # Complete release

# Start new feature for next version
gffs next-feature  # Begin v3.0 development
```

#### **From Any Scenario → Environment Testing**
```bash
# Current work is saved with commits
# Open additional terminals:
env-prod      # Terminal 1: Production testing
env-staging   # Terminal 2: Staging testing  
env-local     # Terminal 3: Local development

# Return to original work in any terminal
git checkout <original-branch>  # Automatic environment switch
```

### **Emergency Switches:**
```bash
# From ANY scenario → Emergency Hotfix
git add . && chore "emergency save point"  # Save immediately
ghfs <version>  # Drop everything, fix production
```

---

## 📊 **Scenario State Summary**

| Scenario | Branch | Environment | Port | Source Mount | GitHub Sync |
|----------|--------|-------------|------|--------------|-------------|
| Feature Development | feature/* | Local | 7700 | ✅ Full | Push when ready |
| Production Hotfix | hotfix/* → main | Local → Prod | 7700 → 7500 | ✅ → ❌ | Push on complete |
| Release Preparation | release/* → main | Local → Prod | 7700 → 7500 | ✅ → ❌ | Push on complete |
| Parallel Features | develop | Staging | 7600 | ✅ Frontend | Push after each |
| Hotfix Distribution | feature/* | Local | 7700 | ✅ Full | Push when updated |
| Environment Testing | varies | varies | all | varies | No changes |
| Feature Abandonment | varies | varies | varies | varies | Push deletions |

**Key Success Factors:**
1. **Always commit before switching scenarios**
2. **Use the enhanced aliases** (they handle environment switching)
3. **Sync to GitHub at logical completion points**
4. **Test in appropriate environment** (local for development, staging for integration, production for verification)
5. **Update feature branches after hotfixes**

This guide ensures you can handle any development situation while maintaining clean Git history and proper environment isolation!