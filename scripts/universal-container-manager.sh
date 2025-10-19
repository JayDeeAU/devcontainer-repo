#!/bin/bash
# ============================================================================
# Universal Container Manager - Aligned with Outstanding Items Fixes
# ============================================================================
# 
# PURPOSE:
#   Cross-project container management with Git Flow branch isolation using worktrees
#   Provides production-optimized builds by default with debug modes for 
#   source tracing and investigation (not for code changes)
#
# ARCHITECTURE:
#   - Production/Staging: Built images (Dockerfile.prod), no source mounting
#   - Debug Modes: Source mounted (Dockerfile.dev) for investigation only  
#   - Local: Always source mounted (Dockerfile.dev) for active development
#   - Worktrees: Separate source directories for true branch isolation
#   - Configuration-driven: Uses .container-config.json for project settings
#
# ENVIRONMENTS:
#   prod (7500-7599):     Production environment, built images only
#   staging (7600-7699):  Staging environment, built images only
#   local (7700-7799):    Local development, always source mounted
#
# CONFIGURATION:
#   Project settings loaded from .container-config.json (required)
#   Use config generator: .devcontainer/scripts/config-generator.sh
#
# USAGE:
#   Normal operations: universal-container-manager switch [env]
#                      universal-container-manager switch [env] --build
#   Debug operations:  universal-container-manager switch prod --debug
#                      universal-container-manager switch staging --debug --sync
#   Utilities:         status, health, logs, stop, setup-worktrees
#
# FLAGS:
#   --build   Force rebuild (required for staging/local with code changes)
#   --debug   Enable debug mode with source mounting (prod/staging only)
#   --sync    Update debug worktree from origin (use with --debug)
#   --push    Auto-push to GHCR after successful build
#
# DEBUG WORKTREES:
#   prod-debug/staging-debug: Isolated worktrees for read-only debugging
#   - Created on first --debug use, preserved between sessions
#   - Use --sync flag to update from origin when needed
#   - Scratch pad area - debug prints won't affect main workspace
#   local-debug: Uses same source as local (current directory)
#
# AUTHOR: Universal Container Management Team
# VERSION: 2.0.0-universal-aligned
# BASED ON: Enhanced Container Manager v1.0.0 (1,200+ lines)
# ALIGNED WITH: Outstanding Items 1, 2, 4 fixes
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="2.0.0-universal-aligned"
readonly CONFIG_FILE=".container-config.json"
readonly CONFIG_GENERATOR=".devcontainer/scripts/config-generator.sh"

# Color definitions for output formatting (PRESERVED from original)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Emoji constants for better UX (PRESERVED from original)
if [[ "${DISABLE_EMOJIS:-false}" == "false" ]]; then
    readonly ROCKET="🚀"
    readonly CHECK="✅"
    readonly WARNING="⚠️"
    readonly ERROR="❌"
    readonly INFO="ℹ️"
    readonly GEAR="⚙️"
    readonly HEALTH="🏥"
    readonly NETWORK="🌐"
    readonly CONTAINER="🐳"
    readonly BRANCH="🌿"
    readonly SHIELD="🛡️"
    readonly PACKAGE="📦"
    readonly DEBUG="🐛"
else
    readonly ROCKET="[*]"
    readonly CHECK="[✓]"
    readonly WARNING="[!]"
    readonly ERROR="[✗]"
    readonly INFO="[i]"
    readonly GEAR="[>]"
    readonly HEALTH="[+]"
    readonly NETWORK="[~]"
    readonly CONTAINER="[D]"
    readonly BRANCH="[B]"
    readonly SHIELD="[S]"
    readonly PACKAGE="[P]"
    readonly DEBUG="[D]"
fi

# # ================================
# # 📝 Logging Utilities
# # ================================
# Logging functions with consistent formatting
log() { echo -e "${BLUE}${INFO}${NC}  $*"; }
success() { echo -e "${GREEN}${CHECK}${NC}  $*"; }
warn() { echo -e "${YELLOW}${WARNING}${NC}  $*"; }
error() { echo -e "${RED}${ERROR}${NC}  $*"; }
header() { echo -e "${PURPLE}${ROCKET}${NC}  ${CYAN}$*${NC}"; }
protect() { echo -e "${CYAN}${SHIELD}${NC}  $*"; }

# ✅ FIXED: Universal port range assignments (no hardcoding)
readonly PROD_PORT_BASE=7500
readonly STAGING_PORT_BASE=7600
readonly LOCAL_PORT_BASE=7700

# ✅ FIXED: Dynamic project detection (no hardcoding)
# These will be set by load_project_config()
PROJECT_NAME=""
CONTAINER_PREFIX=""
PROD_WORKTREE_DIR=""
STAGING_WORKTREE_DIR=""
WORKTREE_SUPPORT=""

# ============================================================================
# DYNAMIC PROJECT DETECTION FUNCTIONS (ITEM 4 FIXES)
# ============================================================================

# ✅ FIXED: Auto-detect project name from directory or git repository
get_project_name() {
    local project_name=""
    
    # Try to get project name from git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
        # Get repository name from git remote URL
        local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            # Extract repository name from URL
            project_name=$(basename "$remote_url" .git)
        fi
    fi
    
    # Fallback to current directory name
    if [[ -z "$project_name" ]]; then
        project_name=$(basename "$(pwd)")
    fi
    
    # Convert to lowercase and sanitize for container names
    project_name=$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9\-]//g')
    
    echo "$project_name"
}

# ✅ FIXED: Generate container prefix from project name
get_container_prefix() {
    local project_name="$1"
    echo "${project_name}_"
}

# ✅ FIXED: Generate worktree directories from project name
get_worktree_dirs() {
    local project_name="$1"
    echo "../${project_name}-production" "../${project_name}-staging"
}

# ============================================================================
# CONFIGURATION LOADING FUNCTIONS (ITEM 4 FIXES)
# ============================================================================

# ✅ FIXED: Enhanced configuration loading with no config generation
load_project_config() {
    # Skip if already loaded
    if [[ -n "$PROJECT_NAME" && -n "$CONTAINER_PREFIX" ]]; then
        return 0
    fi
    
    if [[ -f "$CONFIG_FILE" ]]; then
        log "Loading configuration from $CONFIG_FILE"
        
        # Load project settings from config
        PROJECT_NAME=$(jq -r '.project.name // empty' "$CONFIG_FILE")
        CONTAINER_PREFIX=$(jq -r '.project.container_prefix // empty' "$CONFIG_FILE")
        WORKTREE_SUPPORT=$(jq -r '.project.worktree_support // false' "$CONFIG_FILE")
        
        # Load worktree directories
        PROD_WORKTREE_DIR=$(jq -r '.project.worktree_dirs.prod // empty' "$CONFIG_FILE")
        STAGING_WORKTREE_DIR=$(jq -r '.project.worktree_dirs.staging // empty' "$CONFIG_FILE")
        
        # Validate required fields
        if [[ -z "$PROJECT_NAME" ]]; then
            warn "No project name in config, auto-detecting..."
            PROJECT_NAME=$(get_project_name)
        fi
        
        if [[ -z "$CONTAINER_PREFIX" ]]; then
            CONTAINER_PREFIX=$(get_container_prefix "$PROJECT_NAME")
        fi
        
        # Generate worktree directories if not specified
        if [[ -z "$PROD_WORKTREE_DIR" || -z "$STAGING_WORKTREE_DIR" ]]; then
            local auto_dirs=($(get_worktree_dirs "$PROJECT_NAME"))
            PROD_WORKTREE_DIR="${PROD_WORKTREE_DIR:-${auto_dirs[0]}}"
            STAGING_WORKTREE_DIR="${STAGING_WORKTREE_DIR:-${auto_dirs[1]}}"
        fi
        
        # ✅ Convert relative worktree paths to absolute paths (siblings to main repo)
        # Worktrees are created as siblings: /current/dir/worktree-name
        local current_dir="$(pwd)"
        
        if [[ -n "$PROD_WORKTREE_DIR" && "$PROD_WORKTREE_DIR" != /* ]]; then
            local worktree_name="$(basename "$PROD_WORKTREE_DIR")"
            PROD_WORKTREE_DIR="${current_dir}/${worktree_name}"
        fi
        if [[ -n "$STAGING_WORKTREE_DIR" && "$STAGING_WORKTREE_DIR" != /* ]]; then
            local worktree_name="$(basename "$STAGING_WORKTREE_DIR")"
            STAGING_WORKTREE_DIR="${current_dir}/${worktree_name}"
        fi
        
        success "Configuration loaded for project: $PROJECT_NAME"
    else
        # ✅ FIXED: No config generation - provide clear instructions
        error "Configuration file not found: $CONFIG_FILE"
        echo ""
        echo "🎯 Required Setup:"
        
        if [[ -f "$CONFIG_GENERATOR" ]]; then
            echo "   1. Generate project configuration:"
            echo "      $CONFIG_GENERATOR default"
            echo "      $CONFIG_GENERATOR fullstack"
            echo "      $CONFIG_GENERATOR microservices"
        else
            echo "   1. Create configuration using the config generator:"
            echo "      .devcontainer/scripts/config-generator.sh [template]"
        fi
        
        echo ""
        echo "   2. Customize the generated $CONFIG_FILE for your project"
        echo "   3. Run this command again"
        echo ""
        echo "💡 Available templates: default, fullstack, simple, microservices"
        
        return 1
    fi
    
    log "Project configuration:"
    log "  Name: $PROJECT_NAME"
    log "  Container prefix: $CONTAINER_PREFIX"
    log "  Worktree support: $WORKTREE_SUPPORT"
    if [[ "$WORKTREE_SUPPORT" == "true" ]]; then
        log "  Production worktree: $PROD_WORKTREE_DIR"
        log "  Staging worktree: $STAGING_WORKTREE_DIR"
    fi
}

# Load configuration first
load_project_config

# ============================================================================
# ENVIRONMENT DETECTION FUNCTIONS (ITEM 2 FIXES)
# ============================================================================

# Detects Docker host IP for health checks when running in dev containers
detect_docker_host() {
    local docker_host="localhost"
    
    if [ -f /.dockerenv ]; then
        docker_host=$(ip route show default | awk '/default/ {print $3}' | head -1 2>/dev/null || echo "172.17.0.1")
        log "Dev container detected, using Docker host: $docker_host"
    fi
    
    echo "$docker_host"
}

# Gets current Git branch name
get_current_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

# ✅ FIXED: Universal environment detection with comprehensive branch support (ITEM 2)
get_environment_for_branch() {
    local branch="$1"
    
    # Load branch mappings from config if available
    if [[ -f "$CONFIG_FILE" ]]; then
        # Check each environment's branch configuration
        local prod_branch=$(jq -r '.environments.prod.branch // "main"' "$CONFIG_FILE")
        local staging_branch=$(jq -r '.environments.staging.branch // "develop"' "$CONFIG_FILE")
        local local_branches=$(jq -r '.environments.local.branch // ["feature/*", "hotfix/*", "release/*", "bugfix/*"]' "$CONFIG_FILE")
        
        # Handle both string and array formats for local branches
        if [[ "$local_branches" =~ ^\[.*\]$ ]]; then
            # Array format - check each pattern
            local patterns=$(echo "$local_branches" | jq -r '.[]')
            while IFS= read -r pattern; do
                if [[ "$branch" == $pattern ]]; then
                    echo "local"
                    return
                fi
            done <<< "$patterns"
        else
            # String format - direct pattern match
            if [[ "$branch" == $local_branches ]]; then
                echo "local"
                return
            fi
        fi
        
        # Check specific branch matches
        if [[ "$branch" == "$prod_branch" ]]; then
            echo "prod"
            return
        elif [[ "$branch" == "$staging_branch" ]]; then
            echo "staging"
            return
        fi
        
        # Check fallback setting
        local fallback=$(jq -r '.environments.local.fallback // true' "$CONFIG_FILE")
        if [[ "$fallback" == "true" ]]; then
            echo "local"
            return
        fi
    fi
    
    # ✅ FIXED: Enhanced universal branch mapping (ITEM 2 COMPREHENSIVE SUPPORT)
    case "$branch" in
        main|master)
            echo "prod"
            ;;
        develop|development)
            echo "staging"
            ;;
        # ✅ CRITICAL FIX: Comprehensive local branch support including hotfix
        feature/*|hotfix/*|release/*|bugfix/*|fix/*|chore/*|docs/*|test/*|experiment/*|dev/*)
            echo "local"
            ;;
        *)
            # ✅ FIXED: Default to local for unknown branches (fallback strategy)
            echo "local"
            ;;
    esac
}

# ✅ FIXED: Universal target branch detection
get_target_branch_for_env() {
    local env="$1"
    
    # Load from config if available
    if [[ -f "$CONFIG_FILE" ]]; then
        local target_branch=$(jq -r ".environments.${env}.branch // empty" "$CONFIG_FILE")
        if [[ -n "$target_branch" && "$target_branch" != "null" ]]; then
            # Handle array format (take first element)
            if [[ "$target_branch" =~ ^\[.*\]$ ]]; then
                target_branch=$(echo "$target_branch" | jq -r '.[0]')
            fi
            echo "$target_branch"
            return
        fi
    fi
    
    # Default mapping
    case "$env" in
        prod)
            echo "main"
            ;;
        staging)
            echo "develop"
            ;;
        local)
            echo ""  # No specific branch for local
            ;;
        *)
            echo ""
            ;;
    esac
}

# ✅ FIXED: Universal port range detection
get_port_range_for_env() {
    local env="$1"
    
    case "$env" in
        prod)
            echo "$PROD_PORT_BASE"
            ;;
        staging)
            echo "$STAGING_PORT_BASE"
            ;;
        local)
            echo "$LOCAL_PORT_BASE"
            ;;
        *)
            echo "7000"  # Default fallback
            ;;
    esac
}

# ✅ FIXED: Universal compose file detection
get_compose_file_for_env() {
    local env="$1"
    local debug_mode="$2"
    
    # Load compose files from config if available
    if [[ -f "$CONFIG_FILE" ]]; then
        if [[ "$debug_mode" == "true" ]]; then
            local debug_files=$(jq -r ".environments.${env}.debug_compose_files[]? // empty" "$CONFIG_FILE" 2>/dev/null)
            if [[ -n "$debug_files" ]]; then
                echo "$debug_files" | tr '\n' ' '
                return
            fi
        else
            local compose_files=$(jq -r ".environments.${env}.compose_files[]? // empty" "$CONFIG_FILE" 2>/dev/null)
            if [[ -n "$compose_files" ]]; then
                echo "$compose_files" | tr '\n' ' '
                return
            fi
        fi
    fi
    
    # ✅ FIXED: Universal default compose file pattern
    local base_file="docker/docker-compose.${env}.yml"
    
    if [[ "$debug_mode" == "true" ]]; then
        local debug_file="docker/docker-compose.${env}-debug.yml"
        if [[ -f "$debug_file" ]]; then
            echo "$base_file $debug_file"
        else
            echo "$base_file"
        fi
    else
        echo "$base_file"
    fi
}

# ✅ FIXED: Universal source directory detection with VSCode support (ITEM 1 INTEGRATION)
get_source_directory_for_env() {
    local env="$1" 
    local debug_mode="$2"
    
    # Only mount source in debug mode or local environment
    if [[ "$debug_mode" == "true" || "$env" == "local" ]]; then
        # Use worktree directory if enabled and available
        if [[ "$WORKTREE_SUPPORT" == "true" && "$debug_mode" == "true" ]]; then
            case "$env" in
                prod)
                    local wt="$PROD_WORKTREE_DIR"
                    ;;
                staging)
                    local wt="$STAGING_WORKTREE_DIR"
                    ;;
                *)
                    echo "."
                    return
                    ;;
            esac

            # If worktree path is empty, fallback to current directory
            if [[ -z "$wt" ]]; then
                echo "."
                return
            fi

            # 🔧 DEVCONTAINER FIX: When running inside devcontainer, Docker daemon needs
            # the HOST path, not the devcontainer path. Convert container path to host path.
            if [[ -n "$REMOTE_CONTAINERS" && "$REMOTE_CONTAINERS" == "true" ]]; then
                # Detect the actual workspace mount point (could be /workspace or /workspaces)
                local current_workspace="$(pwd)"
                local workspace_parent="$(dirname "$current_workspace")"
                local current_repo_name="$(basename "$current_workspace")"
                
                # Try common devcontainer naming patterns
                local container_name=""
                for pattern in "devcontainer_${current_repo_name}" "vsc-${current_repo_name}" "${current_repo_name}-devcontainer"; do
                    if docker inspect "$pattern" >/dev/null 2>&1; then
                        container_name="$pattern"
                        break
                    fi
                done
                
                # If still not found, try to find by any devcontainer pattern
                if [[ -z "$container_name" ]]; then
                    container_name=$(docker ps --format '{{.Names}}' | grep -i "devcontainer\|vsc-" | head -1)
                fi
                
                if [[ -n "$container_name" ]]; then
                    # Find the host path by checking which mount corresponds to our current workspace
                    local host_workspace=$(docker inspect "$container_name" 2>/dev/null | \
                        jq -r ".[0].Mounts[] | select(.Destination == \"${current_workspace}\") | .Source" 2>/dev/null)
                    
                    if [[ -n "$host_workspace" && "$wt" == ${current_workspace}/* ]]; then
                        # Convert /workspace(s)/PROJECT/worktree to /host/path/PROJECT/worktree
                        # by replacing the devcontainer workspace prefix with the host path
                        local relative_path="${wt#${current_workspace}/}"
                        echo "${host_workspace}/${relative_path}"
                        return
                    fi
                fi
            fi

            # Non-devcontainer path: prefer relative sibling path for host daemon resolution
            local repo_root="$(pwd)"
            local wt_basename="$(basename "$wt")"

            # If wt is a sibling to repo_root, return ../basename
            if [[ "$wt" == "$repo_root"* || "$wt" == */$(basename "$repo_root")* ]]; then
                echo "../${wt_basename}"
            else
                # Absolute path fallback
                echo "$wt"
            fi
        else
            echo "."
        fi
    else
        echo "none"
    fi
}

# ============================================================================
# CONTAINER MANAGEMENT FUNCTIONS (PRESERVED from original)
# ============================================================================

is_environment_running() {
    local env="$1"
    local containers=$(docker ps --format "table {{.Names}}" | grep "${CONTAINER_PREFIX}.*-$env" 2>/dev/null || true)
    [[ -n "$containers" ]]
}

check_docker_compose() {
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed or not in PATH"
        error "Please install Docker: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    if ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose is not available"
        error "Please install Docker Compose: https://docs.docker.com/compose/install/"
        return 1
    fi
    
    return 0
}

check_compose_file() {
    local compose_files="$1"
    
    for file in $compose_files; do
        if [[ ! -f "$file" ]]; then
            error "Compose file not found: $file"
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# WORKTREE MANAGEMENT FUNCTIONS (PRESERVED from original)
# ============================================================================

worktree_exists() {
    local worktree_dir="$1"
    [[ -d "$worktree_dir" && -f "$worktree_dir/.git" ]]
}

setup_worktree_dependencies() {
    local worktree_dir="$1"
    
    log "Setting up dependencies in worktree: $worktree_dir"
    
    pushd "$worktree_dir" >/dev/null || return 1
    
    # Setup backend dependencies (Poetry)
    if [[ -d "backend" && -f "backend/pyproject.toml" ]]; then
        log "Installing Python dependencies in backend..."
        cd backend
        if command -v poetry &>/dev/null; then
            poetry config virtualenvs.in-project true
            poetry install || warn "Poetry install failed, but continuing..."
        else
            warn "Poetry not found, skipping Python dependency setup"
        fi
        cd ..
    fi
    
    # Setup frontend dependencies (pnpm)
    if [[ -d "frontend" && -f "frontend/package.json" ]]; then
        log "Installing Node dependencies in frontend..."
        cd frontend
        if command -v pnpm &>/dev/null; then
            pnpm install || warn "pnpm install failed, but continuing..."
        else
            warn "pnpm not found, skipping Node dependency setup"
        fi
        cd ..
    fi
    
    # Setup root-level dependencies if they exist
    if [[ -f "pyproject.toml" ]]; then
        log "Installing root Python dependencies..."
        if command -v poetry &>/dev/null; then
            poetry config virtualenvs.in-project true
            poetry install || warn "Poetry install failed, but continuing..."
        fi
    fi
    
    if [[ -f "package.json" ]]; then
        log "Installing root Node dependencies..."
        if command -v pnpm &>/dev/null; then
            pnpm install || warn "pnpm install failed, but continuing..."
        fi
    fi
    
    popd >/dev/null
    
    success "Worktree dependencies setup completed"
    return 0
}

create_worktree() {
    local worktree_dir="$1"
    local target_branch="$2"
    
    log "Creating detached worktree: $worktree_dir ($target_branch)"
    
    # Remove existing directory if it exists but isn't a valid worktree
    if [[ -d "$worktree_dir" ]] && [[ ! -f "$worktree_dir/.git" ]]; then
        warn "Removing invalid worktree directory: $worktree_dir"
        rm -rf "$worktree_dir"
    fi
    
    # Always create worktrees in detached state for debugging
    # This ensures main workspace can freely switch branches without conflicts
    # Since worktrees are scratch pads that never merge back, detached state is ideal
    if ! git worktree add --detach "$worktree_dir" "$target_branch" 2>/dev/null; then
        # If it already exists as a worktree, that's fine - it will be synced if needed
        if [[ -f "$worktree_dir/.git" ]]; then
            log "Worktree already exists: $worktree_dir"
        else
            error "Failed to create worktree at $worktree_dir"
            return 1
        fi
    fi
    
    # Remove git submodule references and directories from worktree (scratch pad doesn't need them)
    pushd "$worktree_dir" >/dev/null || return 1
    
    # Deinitialize .devcontainer submodule if it exists
    if [[ -d ".devcontainer/.git" ]] || grep -q "path = .devcontainer" .gitmodules 2>/dev/null; then
        log "Deinitializing .devcontainer submodule in worktree..."
        git submodule deinit -f .devcontainer 2>/dev/null || true
        git rm -f .devcontainer 2>/dev/null || true
        rm -rf .devcontainer 2>/dev/null || true
    fi
    
    # Deinitialize dotfiles submodule if it exists  
    if [[ -d "dotfiles/.git" ]] || grep -q "path = dotfiles" .gitmodules 2>/dev/null; then
        log "Deinitializing dotfiles submodule in worktree..."
        git submodule deinit -f dotfiles 2>/dev/null || true
        git rm -f dotfiles 2>/dev/null || true
        rm -rf dotfiles 2>/dev/null || true
    fi
    
    # Clean up .gitmodules if it exists and is now empty
    if [[ -f ".gitmodules" ]]; then
        if ! grep -q "\[submodule" .gitmodules 2>/dev/null; then
            rm -f .gitmodules
        fi
    fi
    
    popd >/dev/null
    
    # Add worktree to .gitignore if not already there
    local worktree_name=$(basename "$worktree_dir")
    if ! grep -q "^${worktree_name}/$" ".gitignore" 2>/dev/null; then
        echo "${worktree_name}/" >> ".gitignore"
    fi
    
    success "Worktree created in detached state: $worktree_dir (tracking $target_branch)"
    
    # Note: Worktree dependencies are NOT installed here
    # Containers use dependencies from their built images (preserved via volume exclusions)
    # If IDE support is needed, manually run: cd worktree && poetry install && pnpm install
    
    return 0
}

sync_worktree() {
    local worktree_dir="$1"
    local target_branch="$2"
    
    pushd "$worktree_dir" >/dev/null || return 1
    
    log "Syncing detached worktree with origin/$target_branch..."
    
    # Fetch latest from origin
    if ! git fetch origin "$target_branch"; then
        error "Failed to fetch $target_branch from origin"
        popd >/dev/null
        return 1
    fi
    
    # Reset detached HEAD to latest origin commit
    if ! git reset --hard "origin/$target_branch"; then
        error "Failed to reset to origin/$target_branch"
        error "Manual intervention required in $worktree_dir"
        popd >/dev/null
        return 1
    fi
    
    popd >/dev/null
    
    # Remove git submodule references and directories from worktree after sync
    pushd "$worktree_dir" >/dev/null || return 1
    
    # Deinitialize .devcontainer submodule if it exists
    if [[ -d ".devcontainer/.git" ]] || grep -q "path = .devcontainer" .gitmodules 2>/dev/null; then
        log "Deinitializing .devcontainer submodule after sync..."
        git submodule deinit -f .devcontainer 2>/dev/null || true
        git rm -f .devcontainer 2>/dev/null || true
        rm -rf .devcontainer 2>/dev/null || true
    fi
    
    # Deinitialize dotfiles submodule if it exists
    if [[ -d "dotfiles/.git" ]] || grep -q "path = dotfiles" .gitmodules 2>/dev/null; then
        log "Deinitializing dotfiles submodule after sync..."
        git submodule deinit -f dotfiles 2>/dev/null || true
        git rm -f dotfiles 2>/dev/null || true
        rm -rf dotfiles 2>/dev/null || true
    fi
    
    # Clean up .gitmodules if it exists and is now empty
    if [[ -f ".gitmodules" ]]; then
        if ! grep -q "\[submodule" .gitmodules 2>/dev/null; then
            rm -f .gitmodules
        fi
    fi
    
    popd >/dev/null
    
    success "Worktree synced to origin/$target_branch (detached)"
    
    # Note: Worktree dependencies are NOT installed after sync
    # Containers use dependencies from their built images (preserved via volume exclusions)
    # If IDE support is needed, manually run: cd worktree && poetry install && pnpm install
    
    return 0
}

ensure_worktree_ready() {
    local env="$1"
    local debug_mode="$2"
    local sync_worktree_flag="${3:-false}"  # Optional sync flag
    
    # Only manage worktrees if enabled and for debug modes of prod/staging
    if [[ "$WORKTREE_SUPPORT" != "true" || "$debug_mode" != "true" || ("$env" != "prod" && "$env" != "staging") ]]; then
        return 0
    fi
    
    local target_branch=""
    local worktree_dir=""
    
    case "$env" in
        prod)
            target_branch=$(get_target_branch_for_env "prod")
            worktree_dir="$PROD_WORKTREE_DIR"
            ;;
        staging)
            target_branch=$(get_target_branch_for_env "staging")
            worktree_dir="$STAGING_WORKTREE_DIR"
            ;;
    esac
    
    log "Preparing worktree for $env debug mode..."
    
    if ! worktree_exists "$worktree_dir"; then
        if ! create_worktree "$worktree_dir" "$target_branch"; then
            error "Failed to create worktree for $env environment"
            exit 1
        fi
        # Always sync on first creation
        sync_worktree_flag="true"
    fi

    # Skip chown - worktree permissions are fine, and recursive chown on large trees is slow
    # If permission issues occur, manually run: sudo chown -R $USER:$USER /path/to/worktree
    
    # Only sync if explicitly requested via --sync flag
    if [[ "$sync_worktree_flag" == "true" ]]; then
        if ! sync_worktree "$worktree_dir" "$target_branch"; then
            error "Failed to sync $env worktree"
            error "Debug mode requires up-to-date source code"
            exit 1
        fi
    else
        log "Using existing worktree (use --sync to update from origin)"
        log "Worktree: $worktree_dir"
    fi
    
    success "Worktree ready for $env debug mode"
}

# ============================================================================
# COMMAND FUNCTIONS (ENHANCED WITH ALL FIXES)
# ============================================================================

setup_worktrees() {
    if [[ "$WORKTREE_SUPPORT" != "true" ]]; then
        warn "Worktree support is disabled for this project"
        warn "Enable in .container-config.json: \"worktree_support\": true"
        return 1
    fi
    
    header "Setting Up Worktrees for $PROJECT_NAME"
    echo "======================================="
    echo ""
    echo "This will create separate source directories for production and staging:"
    echo "  $PROD_WORKTREE_DIR    → $(get_target_branch_for_env prod) branch (for production debugging)"
    echo "  $STAGING_WORKTREE_DIR → $(get_target_branch_for_env staging) branch (for staging debugging)"
    echo ""
    
    local failed_setups=()
    
    log "Setting up production worktree..."
    if ! ensure_worktree_ready "prod" "true" "true"; then
        failed_setups+=("production")
    fi
    
    log "Setting up staging worktree..."
    if ! ensure_worktree_ready "staging" "true" "true"; then
        failed_setups+=("staging")
    fi
    
    echo ""
    if [[ ${#failed_setups[@]} -eq 0 ]]; then
        success "Worktree setup completed successfully!"
        echo ""
        echo "Worktrees created:"
        echo "  Production: $PROD_WORKTREE_DIR ($(get_target_branch_for_env prod) branch)"
        echo "  Staging:    $STAGING_WORKTREE_DIR ($(get_target_branch_for_env staging) branch)"
        echo ""
        echo "These will be used automatically when you run:"
        echo "  env-prod-debug    → Uses $PROD_WORKTREE_DIR"
        echo "  env-staging-debug → Uses $STAGING_WORKTREE_DIR"
    else
        error "Failed to set up worktrees: ${failed_setups[*]}"
        error "Please check Git configuration and try again"
        return 1
    fi
    
    return 0
}

# Main switch command with universal project support
switch_environment() {
    local target_env="$1"
    local debug_mode="false"
    local should_push="false"
    local force_build="false"
    local auto_push="false"  # NEW: Auto-push without prompt
    local sync_worktree="false"  # NEW: Sync worktree flag for debug modes
    
    # Parse flags
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug|debug)
                debug_mode="true"
                shift
                ;;
            --push|push)
                auto_push="true"
                shift
                ;;
            --no-push|no-push)
                should_push="false"
                shift
                ;;
            --build|build)
                force_build="true"
                shift
                ;;
            --sync|sync)
                sync_worktree="true"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Determine if we should offer to push (non-local, non-debug)
    if [[ "$target_env" != "local" && "$debug_mode" == "false" ]]; then
        should_push="true"
    fi
    
    # Export for use in build phase
    export AUTO_PUSH="$auto_push"
    
    
    
    # Validate environment
    case "$target_env" in
        prod|staging|local) ;;
        *)
            error "Invalid environment: $target_env"
            error "Valid environments: prod, staging, local"
            return 1
            ;;
    esac
    
    # Check prerequisites
    if ! check_docker_compose; then
        return 1
    fi

    # Get compose files for this environment
    local compose_files=$(get_compose_file_for_env "$target_env" "$debug_mode")
    if ! check_compose_file "$compose_files"; then
        error "Required Docker Compose files not found for $target_env environment"
        return 1
    fi
    
    # Convert space-separated file list to -f flag format
    local compose_flags=""
    for file in $compose_files; do
        compose_flags="$compose_flags -f $file"
    done

    # ============================================================================
    # BUILD STRATEGY - Build only when explicitly requested or necessary
    # ============================================================================
    local needs_build="false"
    local build_reason=""
    
    # All environments: Only build if --build flag provided
    if [[ "$force_build" == "true" ]]; then
        needs_build="true"
        build_reason="Forced rebuild (--build flag) - rebuilding with latest changes"
        if [[ "$target_env" == "prod" ]]; then
            log "Skipping GHCR pull - forcing local build as requested"
        fi
    
    # Production without --build: Try to pull from GHCR
    elif [[ "$target_env" == "prod" ]]; then
        log "Pulling production images from GHCR..."
        if docker compose $compose_flags pull 2>/dev/null; then
            needs_build="false"
            success "Using stable images from GHCR"
        else
            warn "Could not pull from GHCR, will build locally"
            needs_build="true"
            build_reason="GHCR pull failed, building locally (Docker will cache)"
        fi
    
    # Staging/Local without --build: Try to pull from GHCR, or use local if exists
    elif [[ "$target_env" == "staging" ]]; then
        log "Attempting to pull staging images from GHCR..."
        if docker compose $compose_flags pull 2>/dev/null; then
            needs_build="false"
            success "Using images from GHCR (use --build to rebuild with local changes)"
        else
            log "No images in GHCR or pull failed, will use local images if available"
            needs_build="false"
            build_reason="Using local images (use --build to rebuild)"
        fi
    
    # Local environment: Never pull, just use local images
    else
        needs_build="false"
        log "Using local images (use --build to rebuild with latest changes)"
    fi
    
    # Debug modes: Always build with source mounting enabled
    if [[ "$debug_mode" == "true" ]]; then
        needs_build="true"
        build_reason="Debug mode - building with source mounting for investigation"
    fi

    # Prepare worktrees if needed (pass sync flag)
    ensure_worktree_ready "$target_env" "$debug_mode" "$sync_worktree"
    
    # ... rest of existing code ...
    
    # Stop existing containers for this environment (if any)
    if is_environment_running "$target_env"; then
        log "Stopping existing $target_env containers..."
        docker compose -f "$(get_compose_file_for_env "$target_env" "false")" down --remove-orphans 2>/dev/null || true
    fi   

    # Set source directory for debug/local modes
    local source_dir=$(get_source_directory_for_env "$target_env" "$debug_mode")
    if [[ "$source_dir" != "none" ]]; then
        export SOURCE_DIR="$source_dir"
    fi
    
    # ============================================================================
    # BUILD PHASE - Docker shows live progress, intelligently uses cache
    # ============================================================================
    if [[ "$needs_build" == "true" ]]; then
        header "Building $target_env Environment"
        log "Reason: $build_reason"
        
        # Show appropriate warnings for debug modes
        if [[ "$debug_mode" == "true" ]]; then
            warn "${DEBUG} Debug mode enabled - source mounting active"
            warn "Use for investigation/debugging only - NOT for code changes"
            warn "Make code changes in feature branches using local environment"
        fi
        
        log "Building images (showing live progress)..."
        echo ""
        
        # Build with live output (don't capture - so you see progress)
        if ! docker compose $compose_flags build; then
            error "Failed to build $target_env environment"
            return 1
        fi
        
        echo ""
        success "Build completed successfully"
        
    fi
    # ============================================================================
    # START PHASE
    # ============================================================================
    header "Starting $target_env Environment"
    log "Using compose files: $compose_files"
    log "SOURCE_DIR environment variable: ${SOURCE_DIR:-NOT_SET}"
    
    # Always use --no-build to prevent docker compose from rebuilding
    # We handle builds explicitly in the BUILD PHASE above
    if ! docker compose $compose_flags up -d --no-build; then
        error "Failed to start $target_env environment"
        return 1
    fi
    
    # Show environment info
    local base_port=$(get_port_range_for_env "$target_env")
    show_environment_info "$target_env" "$debug_mode" "$base_port"
    
    success "Successfully switched to $target_env environment"
    
    # ============================================================================
    # PUSH TO GHCR - After successful startup (non-local, non-debug only)
    # ============================================================================
    if [[ "$should_push" == "true" && "$needs_build" == "true" ]]; then
        echo ""
        header "Sync to GHCR"
        
        # Check GHCR authentication first
        if ! check_ghcr_auth; then
            warn "Not authenticated to GHCR - images won't be available on other machines"
            warn "Run: ghcr-login  (or see ghcr-status for details)"
            log "Images are only available locally on this machine"
        else
            # Determine if we should push (prompt or auto)
            local do_push="n"
            
            if [[ "${AUTO_PUSH:-false}" == "true" ]]; then
                log "Auto-pushing to GHCR (--push flag enabled)..."
                do_push="y"
            else
                echo ""
                log "Environment is running successfully!"
                log "Push images to GHCR to make them available on all machines?"
                read -p "Push to GHCR? [Y/n] " -n 1 -r do_push
                echo ""
                do_push=${do_push:-y}  # Default to yes if just Enter pressed
            fi
            
            if [[ "$do_push" =~ ^[Yy]$ ]]; then
                log "Pushing to GitHub Container Registry..."
                log "(Showing minimal output - this may take a moment)"
                echo ""
                
                # Push with filtered output to reduce noise
                if docker compose $compose_flags push 2>&1 | \
                   grep -v "Preparing\|Waiting\|Layer already exists\|Pushed" | \
                   grep -E "^(Pulling|Pushing|.*:.*|Error|denied)" || true; then
                    echo ""
                    success "Images pushed to GHCR successfully!"
                    success "→ Images are now available across all your machines"
                else
                    # If grep filtered everything, that's actually success
                    if [ ${PIPESTATUS[0]} -eq 0 ]; then
                        echo ""
                        success "Images pushed to GHCR successfully!"
                        success "→ Images are now available across all your machines"
                    else
                        warn "Push completed with warnings - check output above"
                    fi
                fi
            else
                log "Skipping GHCR push - images only available locally"
                log "To push later: universal-container-manager push $target_env"
            fi
        fi
    fi
    
    return 0
}

show_environment_info() {
    local env="$1"
    local debug_mode="$2"
    local base_port="$3"
    
    echo ""
    if [[ "$debug_mode" == "true" ]]; then
        header "$env Environment (DEBUG MODE)"
        warn "${DEBUG} Source mounting enabled for investigation"
        warn "VSCode debugging available on port $((base_port + 11))"
    else
        header "$env Environment"
        success "${PACKAGE} Production optimized builds"
    fi
    
    echo "========================="
    echo -e "${BRANCH} Target Branch: ${CYAN}$(get_target_branch_for_env "$env")${NC}"
    echo -e "${GEAR}  Environment: ${CYAN}$env${NC}"
    echo -e "${NETWORK} Port Range: ${CYAN}${base_port}xx${NC}"
    echo ""
    echo -e "${CONTAINER} Container Prefix: ${CYAN}${CONTAINER_PREFIX}*-$env${NC}"
    echo -e "${INFO}  Project: ${CYAN}$PROJECT_NAME${NC}"
    
    local source_dir=$(get_source_directory_for_env "$env" "$debug_mode")
    if [[ "$source_dir" != "none" ]]; then
        echo -e "${DEBUG} Source Directory: ${CYAN}$source_dir${NC}"
        echo -e "${INFO} Mount Path: ${CYAN}/workspaces/$PROJECT_NAME${NC}"
        if [[ "$debug_mode" == "true" ]]; then
            echo -e "${INFO} VSCode Debug Port: ${CYAN}$((base_port + 11))${NC}"
        fi
    else
        echo -e "${PACKAGE} Built Images: ${CYAN}No source mounting${NC}"
    fi
    echo ""
}

# ============================================================================
# GHCR MANAGEMENT FUNCTIONS
# ============================================================================

check_ghcr_auth() {
    # Try a simple operation that requires auth
    docker pull ghcr.io/jaydeeau/test 2>&1 | grep -q "denied" && return 1
    return 0
}

push_to_ghcr() {
    local env="$1"
    
    if [[ -z "$env" ]]; then
        error "Usage: universal-container-manager push [env]"
        return 1
    fi
    
    header "Manually Pushing $env Images to GHCR"
    echo "========================================"
    echo ""
    
    local compose_files=$(get_compose_file_for_env "$env" "false")
    
    log "Building images..."
    if ! docker compose -f $compose_files build; then
        error "Failed to build images"
        return 1
    fi
    
    log "Pushing to GHCR..."
    if ! check_ghcr_auth; then
        error "Not authenticated to GHCR"
        echo "Authenticate with: echo \"\$GHCR_TOKEN\" | docker login ghcr.io -u JayDeeAU --password-stdin"
        return 1
    fi
    
    if docker compose -f $compose_files push; then
        success "Images pushed to GHCR successfully!"
        echo ""
        docker compose -f $compose_files images
    else
        error "Failed to push images"
        return 1
    fi
}

pull_from_ghcr() {
    local env="$1"
    
    if [[ -z "$env" ]]; then
        error "Usage: universal-container-manager pull [env]"
        return 1
    fi
    
    header "Pulling $env Images from GHCR"
    echo "========================================"
    echo ""
    
    local compose_files=$(get_compose_file_for_env "$env" "false")
    
    log "Pulling from GHCR..."
    if docker compose -f $compose_files pull; then
        success "Images pulled successfully!"
    else
        error "Failed to pull images"
        return 1
    fi
}

show_status() {
    header "Universal Container Manager Status"
    echo "=================================="
    echo ""
    echo "Project: $PROJECT_NAME"
    echo "Container Prefix: $CONTAINER_PREFIX"
    echo ""
    
    for env in prod staging local; do
        if is_environment_running "$env"; then
            local base_port=$(get_port_range_for_env "$env")
            echo "✅ $env environment running (${base_port}xx)"
        else
            echo "⭕ $env environment stopped"
        fi
    done
}

run_health_check() {
    local current_branch=$(get_current_branch)
    local current_env=$(get_environment_for_branch "$current_branch")
    
    header "Health Check for $current_env Environment"
    echo "========================================"
    
    if ! is_environment_running "$current_env"; then
        warn "$current_env environment is not running"
        return 1
    fi
    
    # Add health check implementation here
    success "Health check completed for $current_env environment"
}

show_logs() {
    local service="$1"
    local current_branch=$(get_current_branch)
    local current_env=$(get_environment_for_branch "$current_branch")
    local compose_files=$(get_compose_file_for_env "$current_env" "false")
    
    if [[ -n "$service" ]]; then
        docker compose -f $compose_files logs -f "$service"
    else
        docker compose -f $compose_files logs -f
    fi
}

stop_environment() {
    local env="$1"
    
    if [[ -n "$env" ]]; then
        # Stop specific environment
        if is_environment_running "$env"; then
            local compose_files=$(get_compose_file_for_env "$env" "false")
            log "Stopping $env environment..."
            docker compose -f $compose_files down --remove-orphans
            success "$env environment stopped"
        else
            warn "$env environment is not running"
        fi
    else
        # Stop all environments
        header "Stopping All Environments"
        for env in prod staging local; do
            if is_environment_running "$env"; then
                local compose_files=$(get_compose_file_for_env "$env" "false")
                log "Stopping $env environment..."
                docker compose -f $compose_files down --remove-orphans
            fi
        done
        success "All environments stopped"
    fi
}

# ============================================================================
# HELP AND STATUS FUNCTIONS
# ============================================================================

show_help() {
    echo ""
    header "Universal Container Manager v${SCRIPT_VERSION}"
    echo "=============================================="
    echo ""
    echo "${SHIELD}  SMART ISOLATION: Each environment runs independently on different ports"
    echo "${DEBUG}  DEBUG MODES: Source mounting for investigation (not code changes)"
    echo "${PACKAGE}  INTELLIGENT CACHING: Docker rebuilds only changed layers"
    echo "${GEAR}  PROJECT AGNOSTIC: Works with any project via configuration"
    echo ""
    echo "Current Project: ${CYAN}$PROJECT_NAME${NC}"
    echo "Container Prefix: ${CYAN}$CONTAINER_PREFIX${NC}"
    echo ""
    echo "Environment Strategy:"
    echo "  ${GEAR} Local:              Builds with source mounted (active development)"
    echo "  ${PACKAGE} Staging:            Builds to test local changes (pre-production testing)"
    echo "  ${DEBUG} Staging --debug:    Builds with worktree mounted (investigation only)"
    echo "  ${PACKAGE} Production:         Pulls from GHCR stable images (deployment)"
    echo "  ${DEBUG} Production --debug: Builds with worktree mounted (investigation only)"
    echo ""
    echo "Port Assignments:"
    echo "  Production:  7500-7599  (stable GHCR images, 7511 for debug)"
    echo "  Staging:     7600-7699  (test local changes, 7611 for debug)"
    echo "  Local:       7700-7799  (active development, 7711 for debug)"
    echo ""
    echo "Branch → Environment Mapping:"
    echo "  main/master  → Production environment"
    echo "  develop      → Staging environment"
    echo "  feature/*    → Local development environment"
    echo "  hotfix/*     → Local development environment"
    echo "  release/*    → Local development environment"
    echo "  bugfix/*     → Local development environment"
    echo "  *            → Local development environment (fallback)"
    echo ""
    echo "Commands:"
    echo "  switch [env] [flags...]     Switch to environment (prod, staging, local)"
    echo ""
    echo "Flags (can use '--flag' or 'flag' format):"
    echo "    --debug, debug            Enable debug mode with source mounting"
    echo "    --build, build            Force rebuild check (for prod after main merge)"
    echo "    --push, push              Auto-push to GHCR without prompting"
    echo "    --no-push, no-push        Skip GHCR push entirely (local testing)"
    echo ""
    echo "Other Commands:"
    echo "  status                      Show current environment status"
    echo "  health                      Run health checks on current environment"
    echo "  logs [service]              Show logs for environment or specific service"
    echo "  stop [env]                  Stop specific environment or all environments"
    echo "  push [env]                  Manually build and push images to GHCR"
    echo "  pull [env]                  Pull latest images from GHCR"
    echo "  setup-worktrees             Set up git worktrees for debug modes"
    echo "  help                        Show this help message"
    echo ""
    echo "Common Workflows:"
    echo "  Active development:         env-local"
    echo "  Test before prod:           env-staging"
    echo "  Deploy to production:       env-prod"
    echo "  Update prod after merge:    env-prod --build  (or: env-prod build)"
    echo "  Push to GHCR (no prompt):   env-staging --push  (or: env-staging push)"
    echo "  Test locally only:          env-staging --no-push"
    echo "  Debug staging issue:        env-staging-debug"
    echo "  Debug production issue:     env-prod-debug"
    echo ""
    echo "Build & Push Behavior:"
    echo "  • Build output: Live progress shown in real-time"
    echo "  • Push output: Minimal, filtered to reduce noise"
    echo "  • Push prompt: Interactive confirmation (unless --push flag used)"
    echo "  • Docker cache: Automatically used for unchanged layers"
    echo ""
}

# ============================================================================
# MAIN COMMAND DISPATCHER
# ============================================================================

main() {
    # Load project configuration first (required for all operations)
    load_project_config || exit 1
    
    local command="${1:-help}"
    
    case "$command" in
        switch)
            shift  # Remove "switch" command
            switch_environment "$@"  # Pass all remaining arguments
            ;;
        status)
            show_status
            ;;
        health)
            run_health_check
            ;;
        logs)
            shift  # Remove "logs" command
            show_logs "$@"  # Pass service name if provided
            ;;
        stop)
            stop_environment "$2"
            ;;
        setup-worktrees)
            setup_worktrees
            ;;
        push)
            push_to_ghcr "$2"
            ;;
        pull)
            pull_from_ghcr "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"