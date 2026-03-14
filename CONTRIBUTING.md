# Contributing to the DevContainer Repository

This guide covers how to contribute changes to the shared devcontainer infrastructure. For daily usage, see [QUICK-START.md](QUICK-START.md). For deep implementation details, see [README.md](README.md).

---

## What This Repository Is

This is a **universal devcontainer** — the same code is cloned into every project's `.devcontainer/` directory as a git submodule. Changes here propagate to all consuming projects on their next submodule update.

**Implication**: Every change must be project-agnostic. If it only makes sense for one project, it belongs in that project's repo, not here.

---

## Universal vs Project-Customizable

| Layer | Location | Who Edits | Scope |
|-------|----------|-----------|-------|
| **Universal** (this repo) | `devcontainer.json`, `features/`, `scripts/` | DevContainer maintainers | All projects |
| **Project config** | `.container-config.json` (project root) | Project team | Per-project Docker settings |
| **Project dependencies** | `pyproject.toml`, `package.json` (project root) | Project team | Per-project packages |

**Universal** — changes apply everywhere:
- Dockerfile and base image (`mcr.microsoft.com/devcontainers/python:3.12-bookworm`)
- External features (node, poetry, docker-outside-of-docker, github-cli)
- Custom features (`features/codemian-standards`, `features/host-ssh-access`, `features/extension-manager`, `features/claude-code`)
- Lifecycle scripts (`setup-environment.sh`, `install-dependencies.sh`)
- VS Code extensions list and settings defaults

**Per-project** — NOT in this repo:
- Docker Compose files (live in project's `docker/` directory, rendered by infra-base)
- `.container-config.json` (consumed by UCM for environment switching)
- Backend/frontend dependency files
- Project-specific VS Code settings

---

## Relationship to Other Submodules

This repo has **soft optional dependencies** on two sibling submodules. The integration is in `scripts/setup-environment.sh` (lines 42-49):

```bash
# Render governance files from base submodules (if present)
if [ -x "claude-base/base-init.sh" ]; then
    claude-base/base-init.sh --refresh || echo "⚠️ ... (non-blocking)"
fi
if [ -x "infra-base/scripts/infra-init.sh" ]; then
    infra-base/scripts/infra-init.sh --validate || echo "⚠️ ... (non-blocking)"
fi
```

| Submodule | Required? | What Happens Without It |
|-----------|-----------|------------------------|
| `claude-base/` | No | AI governance files not rendered — CLI dev workflow works fine |
| `infra-base/` | No | Infrastructure validation skipped — container still starts |

**Key rule**: Never add hard dependencies on other submodules. Always use `-x` existence checks with non-blocking fallbacks (`|| echo "⚠️ ..."`).

---

## Adding a New Feature

### 1. Create the Feature Directory

```
features/my-feature/
├── devcontainer-feature.json   # Metadata, options, env vars
└── install.sh                  # Runs as root during container build
```

### 2. Write `devcontainer-feature.json`

Follow the [DevContainer Feature spec](https://containers.dev/implementors/features/):

```json
{
  "id": "my-feature",
  "version": "1.0.0",
  "name": "My Feature",
  "description": "What this feature provides",
  "options": {
    "myOption": {
      "type": "boolean",
      "default": true,
      "description": "Toggle for this option"
    }
  },
  "containerEnv": {
    "MY_FEATURE_VERSION": "1.0.0"
  }
}
```

**Option naming**: Options in `devcontainer-feature.json` use camelCase. In `install.sh`, they become UPPERCASE environment variables with no separators (e.g., `myOption` → `$MYOPTION`).

### 3. Write `install.sh`

```bash
#!/usr/bin/env bash
set -e

echo "Installing My Feature..."

# Options arrive as UPPERCASE env vars
MY_OPTION=${MYOPTION:-true}

# Detect UID 1000 user (created by Dockerfile with host username via build.args)
CONTAINER_USER=$(getent passwd 1000 | cut -d: -f1)
[ -z "$CONTAINER_USER" ] && { echo "❌ No UID 1000 user found"; exit 1; }

USER_HOME="/home/$CONTAINER_USER"

# Your installation logic
if [ "$MY_OPTION" = "true" ]; then
    apt-get update && apt-get install -y some-package
fi

# Always fix ownership (use $(id -gn) — GID 100 group is 'users', not the username)
chown -R "$CONTAINER_USER:$(id -gn $CONTAINER_USER)" "$USER_HOME/.config/my-feature" 2>/dev/null || true

echo "✅ My Feature installed"
```

### 4. Register in `devcontainer.json`

```json
"./features/my-feature": {
  "myOption": true
}
```

### 5. Test

Rebuild the container: `Ctrl+Shift+P` → "Dev Containers: Rebuild Container"

Verify:
- Feature installs without errors in build output
- Environment variable is set: `echo $MY_FEATURE_VERSION`
- Installed tools are available: `which some-package`
- File ownership is correct for the container user

---

## Modifying Existing Features

### Safe Changes
- Adding a new apt package to `codemian-standards` under the `INSTALLDEVTOOLS` section
- Adding a new option with a default that preserves existing behavior
- Fixing bugs in install scripts

### Risky Changes (Require Extra Testing)
- Changing the base image version
- Modifying user detection logic (affects all features)
- Changing the `postCreateCommand` lifecycle hook
- Removing an existing option (breaks projects that set it)

### Modifying the Base Environment

The base environment is defined in `devcontainer.json`:
- `build`: The Dockerfile and build args (including `USERNAME` via `${localEnv:USER}`)
- External `features`: Third-party features from `ghcr.io`
- `mounts`: Host directories mapped into the container
- `remoteEnv`: Environment variables set in the container

Changes to these affect the container build, not just a single feature. Test thoroughly.

---

## Script System

The lifecycle flow across DevContainer hooks:

```
devcontainer.json (updateContentCommand)
  └→ install-dependencies.sh
       ├→ Skip if devcontainer repo itself (features/ + templates/ detected)
       ├→ Poetry install (if pyproject.toml found)
       ├→ pnpm install (if package.json found)
       └→ Auto-detect monorepo subdirs (frontend/, backend/, api/, web/, server/)

devcontainer.json (postCreateCommand) — runs once after container creation
  ├→ dotfiles: setup-environment.sh
  │    ├→ Clone ~/dotfiles + run dotbootstrap.sh (if not present)
  │    └→ infra-base/scripts/infra-init.sh --validate (if present, non-blocking)
  ├→ vscode: Copy tasks.json to .vscode/
  └→ renders: claude-base/base-init.sh --refresh (if present, non-blocking)

devcontainer.json (postStartCommand) — runs every container start
  └→ docker context use default
```

**DevContainer lifecycle hooks** (from the [spec](https://containers.dev/implementors/json_reference/)):
- `updateContentCommand`: Re-runs on source changes (Codespaces prebuilds). Used for dependency installation.
- `postCreateCommand` (object syntax): Runs once after container creation. Parallel tasks for user setup, dotfiles, vscode config, and governance rendering.
- `postStartCommand`: Runs every time the container starts. Used for docker context reset.
- `postAttachCommand`: Runs every time a client attaches. Not currently used.

---

## Pushing Changes

This repo is a submodule. Push from within the submodule directory:

```bash
# From the project root
cd .devcontainer
git add -u
git commit -m "feat: add my-feature to devcontainer"
git push

# The parent project's submodule pointer is NOT updated automatically.
# That's a separate step:
cd ..
git add .devcontainer
git commit -m "chore: update .devcontainer submodule"
```

Or use the shell alias (from dotfiles, if available):

```bash
devcontpush "feat: add my-feature"
```

**Note**: In worktree setups, `devcontpush` resolves the main repo path via `get_main_repo_path()`. If the main repo's `.devcontainer` is in detached HEAD, push directly from the worktree's submodule instead.

---

## Checklist Before Pushing

- [ ] Feature is project-agnostic (no hardcoded project names, ports, or paths)
- [ ] `install.sh` uses `set -e` and the user detection pattern
- [ ] File ownership set for container user, not root
- [ ] Options have sensible defaults (existing behavior preserved)
- [ ] No hard dependencies on claude-base or infra-base
- [ ] Container rebuilds successfully end-to-end
- [ ] README.md updated if adding a new feature (Feature System section)
