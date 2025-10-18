# 🏗️ Development System Architecture

## Overview

> **Note**: This documentation is project-agnostic and works with any project using the devcontainer-repo. Replace `myproject` in examples with your actual project name.

This development environment consists of three integrated systems that work together to provide a seamless development experience. Each system has a distinct responsibility, preventing duplication while maintaining clean separation of concerns.

---

## System Components

### 1. 🏠 Dotfiles Environment

**Location**: `~/dotfiles/`  
**Scope**: Cross-project (user-level configuration)  
**Purpose**: Shell environment and user interface layer

#### Responsibilities:
- Shell configuration (zsh, aliases, functions)
- Git workflow automation (gffs, ghfs, grs)
- Environment switching shortcuts (env-local, env-staging, env-prod)
- Conventional commit helpers (feat, fix, docs, chore)
- Tool management (eza, bat, fzf, zoxide, starship)

#### Key Files:
```
~/dotfiles/
├── .functions/
│   ├── git.sh                           # Git flow integration
│   ├── git-code-enhanced-*.sh          # Enhanced git workflows
│   ├── docker.sh                        # Docker helpers
│   ├── help_*.sh                        # Help system
│   └── ...
├── .aliases                             # Shell aliases
├── .exports                             # Environment variables
└── config/                              # Tool configurations
```

#### Integration Points:
- **Calls**: `universal-container-manager.sh` for environment switching
- **Calls**: `version-manager.sh` for version control
- **Provides**: User-facing commands and aliases

---

### 2. 🐳 Universal Container Manager

**Location**: `.devcontainer/scripts/universal-container-manager.sh`  
**Scope**: Project-specific  
**Purpose**: Multi-environment Docker orchestration

#### Responsibilities:
- Environment isolation (prod, staging, local)
- Port range management (7500s, 7600s, 7700s)
- Git worktree management for debug modes
- Docker Compose orchestration
- GHCR integration (push/pull images)
- Source mounting strategies (debug vs. production)

#### Key Features:
```
Environment      Port Range    Source Mount    Use Case
-----------      ----------    ------------    --------
Production       7500-7599     No (built)      Deployment, stable images
Prod Debug       7500-7599     Yes (worktree)  Investigation only
Staging          7600-7699     No (built)      Pre-production testing
Staging Debug    7600-7699     Yes (worktree)  Investigation only
Local            7700-7799     Yes (current)   Active development
```

#### Integration Points:
- **Called by**: Dotfiles git flow functions (gffs, ghfs, grs, etc.)
- **Called by**: Environment aliases (env-local, env-staging, env-prod)
- **Uses**: Project's docker-compose files
- **Manages**: Git worktrees for branch isolation

---

### 3. 📦 Version Manager

**Location**: `.devcontainer/scripts/version-manager.sh`  
**Scope**: Project-specific  
**Purpose**: Semantic versioning and file synchronization

#### Responsibilities:
- Sequential version assignment (conflict-free parallel development)
- Multi-file version synchronization
- Conflict resolution (commit race detection)
- Version consistency checking
- Breaking change detection

#### Managed Files:
```
frontend/package.json              # Node.js version
frontend/lib/version.ts            # Frontend version module
backend/pyproject.toml             # Python project version
backend/api/config.py              # Backend config version
docker/docker-compose.*.yml        # Docker labels
```

#### Version Assignment Strategy:
```
Branch Type    Version Increment    Example Flow
-----------    -----------------    ------------
feature/*      Minor (sequential)   1.3.0 → 1.4.0 → 1.5.0
hotfix/*       Patch (sequential)   1.2.4 → 1.2.5 → 1.2.6
release/*      Manual/Major         2.0.0
```

#### Integration Points:
- **Called by**: Git flow functions during branch creation
- **Called by**: Version bump commands (gvb, gvs)
- **Updates**: All project version files atomically

---

## System Integration Flow

### Example: Starting a New Feature

```
USER COMMAND:
$ gffs user-authentication

EXECUTION FLOW:
┌─────────────────────────────────────────────┐
│ 1. Dotfiles (.functions/git.sh)            │
│    - Receives command from shell            │
│    - Validates prerequisites                │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│ 2. Version Manager                          │
│    - Detects branch type (feature)          │
│    - Assigns next minor version (1.3.0)     │
│    - Updates all project files              │
│    - Commits version assignment             │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│ 3. Git Operations (git.sh)                 │
│    - Creates feature/user-authentication    │
│    - Switches to new branch                 │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│ 4. Container Manager                        │
│    - Detects branch type → local env        │
│    - Stops other environments               │
│    - Starts local containers (7700s)        │
│    - Mounts source for hot-reload           │
└─────────────┬───────────────────────────────┘
              │
┌─────────────▼───────────────────────────────┐
│ 5. Ready for Development                    │
│    - Branch: feature/user-authentication    │
│    - Version: 1.3.0                         │
│    - Environment: Local (7700-7799)         │
│    - Containers: Running and ready          │
└─────────────────────────────────────────────┘

TIME: ~5 seconds total
```

---

## Layer Architecture

### Clean Separation of Concerns

```
┌──────────────────────────────────────────────────────┐
│  LAYER 1: User Interface (Dotfiles)                  │
│  ────────────────────────────────────────────────    │
│  Responsibility: User commands and shell experience  │
│  Examples: gffs, env-local, feat, fix                │
│  Location: ~/dotfiles/.functions/                    │
└────────────────────┬─────────────────────────────────┘
                     │ calls
┌────────────────────▼─────────────────────────────────┐
│  LAYER 2: Orchestration (Container Manager)          │
│  ────────────────────────────────────────────────    │
│  Responsibility: Environment and Docker management   │
│  Examples: switch, status, health, worktrees         │
│  Location: .devcontainer/scripts/                    │
└────────────────────┬─────────────────────────────────┘
                     │ uses
┌────────────────────▼─────────────────────────────────┐
│  LAYER 3: State Management (Version Manager)         │
│  ────────────────────────────────────────────────    │
│  Responsibility: Version state and file sync         │
│  Examples: bump, assign, check, current              │
│  Location: .devcontainer/scripts/                    │
└──────────────────────────────────────────────────────┘
```

### Why This Separation?

1. **Single Responsibility**: Each layer has one clear purpose
2. **Loose Coupling**: Layers communicate through well-defined interfaces
3. **Cross-Project Portability**: Dotfiles work across multiple projects
4. **Project Specificity**: Container/version managers stay project-local
5. **Maintainability**: Changes to one layer don't break others
6. **Testability**: Each layer can be tested independently

---

## Design Principles

### 1. Integration, Not Duplication

The systems are **integrated** (working together), not **duplicated** (doing the same thing):

- **Dotfiles**: Provides the **interface** (what users type)
- **Container Manager**: Provides the **orchestration** (how Docker runs)
- **Version Manager**: Provides the **state** (version numbers)

### 2. Simple Commands, Complex Results

```
Simple:  gffs my-feature
Complex: Branch creation + version assignment + environment startup
Result:  Ready to code in 5 seconds
```

The complexity exists **to make things simpler** for developers.

### 3. Fail-Safe Defaults

- Environment auto-detection from branch type
- Port assignment prevents conflicts
- Sequential versioning prevents parallel development conflicts
- Worktree isolation prevents branch contamination

### 4. Progressive Disclosure

- **Day 1**: Learn `gffs`, `feat`, `gfff` (3 commands)
- **Week 1**: Add environment switching (3 more commands)
- **Month 1**: Master debug modes and advanced features
- **Never**: Need to understand the internal complexity

---

## Configuration

### Project Configuration

**File**: `.container-config.json` (project root)

> **Important**: Each project using this devcontainer system must have its own `.container-config.json`. Use the config generator to create one for your project.

**Generate configuration**:
```bash
.devcontainer/scripts/config-generator.sh default
# or
.devcontainer/scripts/config-generator.sh fullstack
```

**Example configuration**:

```json
{
  "project": {
    "name": "myproject",
    "container_prefix": "myproject_",
    "worktree_support": true,
    "worktree_dirs": {
      "prod": "../myproject-production",
      "staging": "../myproject-staging"
    }
  },
  "environments": {
    "prod": {
      "branch": "main",
      "compose_files": ["docker/docker-compose.prod.yml"],
      "debug_compose_files": [
        "docker/docker-compose.prod.yml",
        "docker/docker-compose.prod-debug.yml"
      ]
    },
    "staging": {
      "branch": "develop",
      "compose_files": ["docker/docker-compose.staging.yml"],
      "debug_compose_files": [
        "docker/docker-compose.staging.yml",
        "docker/docker-compose.staging-debug.yml"
      ]
    },
    "local": {
      "branch": ["feature/*", "hotfix/*", "release/*"],
      "fallback": true,
      "compose_files": ["docker/docker-compose.local.yml"],
      "debug_compose_files": [
        "docker/docker-compose.local.yml",
        "docker/docker-compose.local-debug.yml"
      ]
    }
  }
}
```

**Customize for your project**:
- Change `"name"` to your project name
- Update `container_prefix` to match your project
- Adjust `worktree_dirs` paths if needed
- Modify branch names if using different branching strategy

Generated via: `.devcontainer/scripts/config-generator.sh [template]`

---

## Troubleshooting

### System Not Working Together?

1. **Check dotfiles installation**:
   ```bash
   cd ~/dotfiles && git pull && ./dotbootstrap.sh
   ```

2. **Verify project config**:
   ```bash
   cat .container-config.json
   # Should exist and be valid JSON
   ```

3. **Test each layer independently**:
   ```bash
   # Layer 1: Dotfiles
   which gffs  # Should show function definition
   
   # Layer 2: Container Manager
   .devcontainer/scripts/universal-container-manager.sh help
   
   # Layer 3: Version Manager
   .devcontainer/scripts/version-manager.sh current
   ```

### Integration Issues?

**Symptom**: Commands not found  
**Solution**: Source dotfiles in shell initialization

**Symptom**: Environment doesn't switch  
**Solution**: Check Docker daemon is running

**Symptom**: Version not updating  
**Solution**: Verify version files exist in project

---

## Learn More

- **Quick Start**: See `QUICK-START.md`
- **Workflow Guide**: Run `dot_help_workflow` in shell
- **Container Details**: Run `dot_help_containers` in shell
- **Help System**: Run `dot_help_all` in shell

---

## Summary

### The Philosophy

> **Simple commands should hide complex orchestration.**

Three systems, one goal: Make development effortless.

- ✅ Type simple commands
- ✅ Get complex results
- ✅ Stay in flow state
- ✅ Let the system handle the details

**This is intentional integration, not accidental duplication.**
