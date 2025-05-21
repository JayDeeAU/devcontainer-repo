# Git Workflow and Migration Guide (Full)

This guide walks you through modernizing a multi-folder dev/prod project structure into a clean, Git-based branching model. It includes:

- Git basics and branching strategy
- Migration scripts with full explanations
- Developer shell helper functions
- Interactive FZF-based tools
- Usage context for GitHub CLI, Desktop, and VSCode

---

## 🧠 Git Basics: Key Concepts

If you're new to Git, here's what you need to know:

### ✅ `git add` — *Stage a file*
Prepares your changes to be committed. Think of this like marking files you want to save in the next snapshot.

```bash
git add filename.py
```

---

### ✅ `git commit` — *Save a snapshot*
Records a snapshot of your staged files to your local repository. Your changes are saved locally but not yet shared.

```bash
git commit -m "Describe what changed"
```

---

### ✅ `git push` — *Upload to GitHub*
Sends your committed work to a remote repository (e.g. GitHub). Until you push, no one else can see your commits.

```bash
git push origin branch-name
```

---

### ✅ `git pull` — *Download from GitHub*
Fetches and integrates the latest changes from the remote repository into your current branch.

```bash
git pull origin develop
```

---

### ✅ `git branch` — *Work on multiple things*
Branches let you work on new features or fixes without affecting the main codebase.

```bash
git checkout -b feature/my-new-feature
```

---

### ✅ `git checkout` — *Switch branches or restore files*
Used to move between branches or revert files to a known state.

---

## 📦 Folder Migration Overview

This guide assumes you’re currently working with duplicated folders:

### Before:
```
magmabi/           # dev version
magmabi-prod/      # prod version
backend/           # dev version
backend-prod/      # prod version
```

### After:
```
magmabi/           # one folder
backend/
```

You’ll use Git branches instead of folders to switch between environments:
- `main` → production-ready
- `develop` → working branch
- `feature/*` → short-term development
- `hotfix/*` → urgent patches

---

## 🛠 Migration Script: `git_migrate_monorepo.sh`

This script transforms your repo from a folder-based structure to a branch-based Git workflow.

```bash
#!/bin/bash
set -e

# ✅ Verify you're in a Git repo
if [ ! -d .git ]; then
  echo "❌ Not a Git repo"
  exit 1
fi

# 📝 Stage and commit all changes before starting migration
git add .
git commit -m "Pre-migration snapshot"

# 🔐 Save the current state in a backup branch
git checkout -b prod-legacy

# 🌿 Create clean new branches
git checkout -b main
git checkout -b develop

# 🧹 Remove the duplicated folders that are now obsolete
rm -rf magmabi-prod backend-prod
git add .
git commit -m "Clean up -prod folders"

echo "✅ Migration complete. Use 'main' and 'develop' going forward."
```

---

## 🧭 Git Branch Workflow

### 🚧 Start a New Feature
```bash
git checkout develop       # switch to the working branch
git pull                   # download the latest remote changes
git checkout -b feature/xyz # create and switch to new feature branch
```
This gives you an isolated environment to work in.

---

### ✅ Merge and Delete the Feature
```bash
git checkout develop
git merge feature/xyz      # combines your work into the main dev branch
git branch -d feature/xyz  # deletes the local feature branch (safe if merged)
```
Once your feature is tested and merged, delete the branch to keep things clean.

---

### 🐛 Apply a Hotfix
```bash
git checkout main
git pull
git checkout -b hotfix/fix-bug
# fix and commit your changes
git add .                  # stage fixed files
git commit -m "fix: urgent bug"
git checkout main
git merge hotfix/fix-bug   # bring the fix into main
git push                   # upload to GitHub
git checkout develop
git merge hotfix/fix-bug   # ensure dev also has the fix
```

---

### 🚀 Release Develop to Production
```bash
git checkout main
git pull
git merge develop
git push
```
This merges everything tested in `develop` into `main` and publishes it to GitHub.

---

## 🧹 Remove Legacy Folders (Manual Backup)

```bash
mkdir ../legacy-backup
cp -r magmabi-prod backend-prod ../legacy-backup/
git rm -r magmabi-prod backend-prod  # removes from Git
rm -rf magmabi-prod backend-prod     # removes from disk
git commit -m "Removed old prod folders"
```

---

## 🗃 Shell Helper Functions

These simplify common Git tasks. Add them to `~/.functions/git.sh` or similar.

### Create a New Feature Branch
```bash
start-feature() {
  if [ -z "$1" ]; then echo "Usage: start-feature <name>"; return 1; fi
  git checkout develop && git pull && git checkout -b "feature/$1"
}
```

### Start a Hotfix from `main`
```bash
start-hotfix() {
  if [ -z "$1" ]; then echo "Usage: start-hotfix <name>"; return 1; fi
  git checkout main && git pull && git checkout -b "hotfix/$1"
}
```

### Permanently Delete a Local Branch
```bash
trash-feature() {
  git checkout develop && git branch -D "feature/$1"
}
```

### Push and Clean Local Feature (Optional)
```bash
park-feature() {
  git checkout "feature/$1" && git push origin "feature/$1"
  echo "Delete local branch 'feature/$1'? [y/N]: "
  read confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git checkout develop && git branch -D "feature/$1"
  else
    echo "❌ Skipped"
  fi
}
```

### Restore a Parked Feature
```bash
reopen-feature() {
  git checkout -b "feature/$1" "origin/feature/$1"
}
```

---

## 🏷 Tagging and PRs

### Timestamp a Release
```bash
alias gtag='git tag $(date +v%Y.%m.%d-%H%M) && git push --tags'
```

### Open Pull Request via CLI
```bash
gh pr create --fill
```
Pull Requests let you submit work for review and merge it into `main` or `develop`.

---

## 🔁 Work in Two Branches at Once

```bash
git worktree add ../workspace-dev develop
git worktree add ../workspace-prod main
```

---

## 🔐 SSH GitHub Connectivity Check

```bash
check_github_ssh() {
  ssh -T git@github.com || echo "❌ SSH failed"
}
```

---

## ⚠️ Check If `main` or `develop` Is Behind

```bash
check_branch_status() {
  for branch in main develop; do
    git fetch origin $branch &>/dev/null
    local local=$(git rev-parse $branch 2>/dev/null)
    local remote=$(git rev-parse origin/$branch 2>/dev/null)
    if [[ "$local" != "$remote" ]]; then
      echo "⚠️  $branch is behind origin/$branch"
    fi
  done
}
```

---

## 🔎 FZF Git Tools

### Browse Git History
```bash
ghist() {
  git log --oneline --decorate --graph --all |
    fzf --preview 'git show --color=always {1}' --preview-window=up:70%
}
```

### Checkout Branches/Tags with Preview
```bash
gcof() {
  echo "Choose: [1] Branches [2] Tags [3] Both"
  read mode
  case $mode in
    1) refs=refs/heads ;;
    2) refs=refs/tags ;;
    *) refs="refs/heads refs/tags" ;;
  esac

  git fetch --all &>/dev/null
  git for-each-ref --format='%(refname:short)' $refs |
    sort -u | fzf --preview='git log -n 5 --oneline {}' | xargs git checkout
}
```

### Restore a File from History
```bash
grestore() {
  local file=$(git ls-files | fzf)
  git checkout HEAD -- "$file"
}
```

---

## 🧠 GitHub Desktop and VSCode

### GitHub Desktop
- Great for beginners
- GUI for branches, commits, and PRs
- Useful for non-terminal workflows

### VSCode Git UI
- Git sidebar: stage, commit, push
- Timeline view: see changes per file
- Branch switching from the lower-left menu

---

🗂 Save this file as:  
`.devcontainer/docs/git_workflow_full_guide.md`
