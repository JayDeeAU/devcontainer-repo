# ~/.functions/git.sh
# Git helper functions for managing a feature-branch workflow using main/develop
# Designed for safety, readability, and use by both beginners and experienced devs.

# ------------------------------------------------------------------------------
# start-feature <name>
#
# ⛏️ PURPOSE:
#   Starts a new feature branch off the latest 'develop' branch.
#
# 📌 WHEN TO USE:
#   Use this at the beginning of a new feature or unit of work.
#
# 💡 WHY:
#   This ensures you always branch from the most recent version of 'develop'.
# ------------------------------------------------------------------------------
start-feature() {
  if [ -z "$1" ]; then
    echo "❌ Usage: start-feature <feature-name>"
    return 1
  fi
  git checkout develop && git pull && git checkout -b "feature/$1"
}

# ------------------------------------------------------------------------------
# start-hotfix <name>
#
# 🩹 PURPOSE:
#   Creates a hotfix branch off 'main' for urgent fixes.
#
# 📌 WHEN TO USE:
#   Use this when production is broken and needs a quick patch.
#
# 💡 WHY:
#   Keeps production fixes separate and allows back-merging to 'develop'.
# ------------------------------------------------------------------------------
start-hotfix() {
  if [ -z "$1" ]; then
    echo "❌ Usage: start-hotfix <hotfix-name>"
    return 1
  fi
  git checkout main && git pull && git checkout -b "hotfix/$1"
}

# ------------------------------------------------------------------------------
# trash-feature <name>
#
# 🗑️ PURPOSE:
#   Deletes a local feature branch that is no longer needed.
#
# 📌 WHEN TO USE:
#   Use this when you've abandoned a feature before pushing it.
#
# ⚠️ WARNING:
#   This is irreversible and only affects your local machine.
# ------------------------------------------------------------------------------
trash-feature() {
  if [ -z "$1" ]; then
    echo "❌ Usage: trash-feature <feature-name>"
    return 1
  fi
  git checkout develop && git branch -D "feature/$1"
}

# ------------------------------------------------------------------------------
# park-feature <name>
#
# 📤 PURPOSE:
#   Pushes your local feature branch to GitHub and optionally deletes it locally.
#
# 📌 WHEN TO USE:
#   Use this if:
#     - You’re switching machines
#     - You’re done for the day
#     - You want to clean up your local environment
#
# 💡 WHY:
#   Keeps work safe on GitHub while cleaning your local workspace.
# ------------------------------------------------------------------------------
park-feature() {
  if [ -z "$1" ]; then
    echo "❌ Usage: park-feature <feature-name>"
    return 1
  fi
  git checkout "feature/$1" && git push origin "feature/$1"
  echo "🧹 Do you want to delete the local branch 'feature/$1'? [y/N]: "
  read confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    git checkout develop && git branch -D "feature/$1"
    echo "✅ Local branch removed."
  else
    echo "❌ Skipped deletion."
  fi
}

# ------------------------------------------------------------------------------
# reopen-feature <name>
#
# 🔄 PURPOSE:
#   Re-checks out a parked (remote) feature branch.
#
# 📌 WHEN TO USE:
#   When you're ready to resume work that was shelved using park-feature.
#
# 💡 WHY:
#   Saves you from manually finding or retyping the remote branch path.
# ------------------------------------------------------------------------------
reopen-feature() {
  if [ -z "$1" ]; then
    echo "❌ Usage: reopen-feature <feature-name>"
    return 1
  fi
  git checkout -b "feature/$1" "origin/feature/$1"
}

# ------------------------------------------------------------------------------
# gtag
#
# 🏷️ PURPOSE:
#   Creates a lightweight Git tag using the current date/time.
#
# 📌 WHEN TO USE:
#   After merging to 'main' to mark deployments or milestone releases.
#
# 💡 WHY:
#   Makes it easy to identify when and what was shipped.
# ------------------------------------------------------------------------------
alias gtag='git tag $(date +v%Y.%m.%d-%H%M) && git push --tags'

# ------------------------------------------------------------------------------
# check-branch-status
#
# 🔍 PURPOSE:
#   Compares your local 'main' and 'develop' branches to their remotes.
#
# 📌 WHEN TO USE:
#   Use this before releasing, pushing, or pulling to avoid stale code.
#
# 💡 WHY:
#   Prevents you from overwriting or missing upstream changes.
# ------------------------------------------------------------------------------
check-branch-status() {
  for branch in main develop; do
    git fetch origin "$branch" &>/dev/null
    local local=$(git rev-parse "$branch" 2>/dev/null)
    local remote=$(git rev-parse "origin/$branch" 2>/dev/null)
    if [[ "$local" != "$remote" ]]; then
      echo "⚠️  $branch is behind origin/$branch"
    fi
  done
}

# ------------------------------------------------------------------------------
# check_github_ssh
#
# 🔐 PURPOSE:
#   Confirms that SSH access to GitHub is configured properly.
#
# 📌 WHEN TO USE:
#   Run this if pushes or pulls aren't working, or when setting up a new system.
#
# 💡 WHY:
#   Helps avoid confusion when GitHub access fails silently.
# ------------------------------------------------------------------------------
check_github_ssh() {
  ssh -T git@github.com || echo "❌ SSH connection failed"
}

# ------------------------------------------------------------------------------
# ghist
#
# 🧠 PURPOSE:
#   Interactive Git history browser using FZF.
#
# 📌 WHEN TO USE:
#   To visually explore recent commits and preview changes before acting.
#
# 💡 WHY:
#   Saves time compared to `git log` and enables quick navigation.
# ------------------------------------------------------------------------------
ghist() {
  git log --oneline --decorate --graph --all |
    fzf --preview 'git show --color=always {1}' --preview-window=up:70%
}

# ------------------------------------------------------------------------------
# gcof
#
# 🔀 PURPOSE:
#   Fuzzy-checkout any branch or tag, with preview.
#
# 📌 WHEN TO USE:
#   Switching between branches or tags quickly and interactively.
#
# 💡 WHY:
#   Useful when you can't remember the exact branch name.
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# grestore
#
# ♻️ PURPOSE:
#   Restore a previously committed file from Git history.
#
# 📌 WHEN TO USE:
#   If you've accidentally modified or deleted a file.
#
# 💡 WHY:
#   Lets you recover without needing to reset or stash everything.
# ------------------------------------------------------------------------------
grestore() {
  local file
  file=$(git ls-files | fzf)
  [ -n "$file" ] && git checkout HEAD -- "$file"
}
