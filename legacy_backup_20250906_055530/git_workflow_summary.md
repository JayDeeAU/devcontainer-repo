# Git Workflow Summary (Cheat Sheet)

This cheat sheet summarizes the most common Git commands and workflows used in a modern, branch-based development setup. It’s designed for teams migrating from folder duplication (e.g. `*-prod` folders) to Git-based environments like `main`, `develop`, and `feature/*`.

---

## 🧠 Git Basics (Quick Reference)

| Command            | What it Does                                    |
|--------------------|--------------------------------------------------|
| `git add`          | Stages your changes for the next commit         |
| `git commit`       | Records a snapshot of staged changes locally    |
| `git push`         | Uploads your local commits to GitHub            |
| `git pull`         | Downloads and merges latest changes from GitHub |
| `git checkout`     | Switches branches or restores a file            |
| `git branch`       | Lists or creates branches                       |

---

## 🔁 Branch Strategy

| Branch      | Purpose                                  |
|-------------|-------------------------------------------|
| `main`      | Stable production code                   |
| `develop`   | Integration of all features and fixes    |
| `feature/*` | New features, isolated from other work   |
| `hotfix/*`  | Urgent bug fixes applied to `main`       |

---

## 🚧 Start a New Feature

```bash
git checkout develop         # Move to the integration branch
git pull                     # Get the latest remote changes
git checkout -b feature/xyz  # Create a new branch for your work
```
This lets you work on a change without affecting shared code.

---

## ✅ Complete a Feature

```bash
git checkout develop
git merge feature/xyz        # Bring feature into develop
git branch -d feature/xyz    # Clean up your branch list
```
The work is now part of `develop`. It's safe to delete the branch.

---

## 🐛 Apply a Hotfix to Production

```bash
git checkout main
git pull
git checkout -b hotfix/fix-name
# make changes, then:
git add .
git commit -m "fix: urgent issue"
git checkout main
git merge hotfix/fix-name
git push
git checkout develop
git merge hotfix/fix-name
```
Use this when something is broken in production and must be fixed quickly.

---

## 🚀 Release `develop` to `main` (Deploy to Production)

```bash
git checkout main
git pull
git merge develop
git push
```
Run this when you’re ready to deploy a new version to production.

---

## 🗑️ Abandon or Park a Feature

```bash
# Permanently delete an abandoned feature:
git checkout develop
git branch -D feature/xyz

# OR: Park it on GitHub for later
git checkout feature/xyz
git push origin feature/xyz
git checkout develop
git branch -D feature/xyz
```
Use this to clean up or store WIP remotely.

---

## 🔁 Restore a Parked Feature

```bash
git checkout -b feature/xyz origin/feature/xyz
```
Restores a shelved feature branch from the remote.

---

## 🧹 Backup and Remove Legacy `*-prod` Folders

```bash
mkdir ../legacy-backup
cp -r magmabi-prod backend-prod ../legacy-backup/
git rm -r magmabi-prod backend-prod
rm -rf magmabi-prod backend-prod
git commit -m "Remove legacy prod folders"
```
This should only be done after migrating to branches.

---

## 🧪 Worktree: Work in Two Branches at Once

```bash
git worktree add ../workspace-dev develop
git worktree add ../workspace-prod main
```
Lets you open both `develop` and `main` simultaneously in separate terminals/editors.

---

## 🏷 Tag for Releases

```bash
alias gtag='git tag $(date +v%Y.%m.%d-%H%M) && git push --tags'
```
Useful for versioning or rollback points.

---

## 🚀 Open a Pull Request from CLI

```bash
gh pr create --fill
```
A Pull Request (PR) lets you propose merging a feature into `develop` or `main`, with review and approval.

---

## 🔐 Check GitHub SSH Authentication

```bash
check_github_ssh() {
  ssh -T git@github.com || echo "❌ SSH failed"
}
```

---

🗂 Save this file as:  
`.devcontainer/docs/git_workflow_summary.md`
