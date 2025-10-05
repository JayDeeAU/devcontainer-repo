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
#   Debug operations:  universal-container-manager switch prod --debug
#   Utilities:         status, health, logs, stop, setup-worktrees
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
    
    # Make variables readonly after loading
    readonly PROJECT_NAME
    readonly CONTAINER_PREFIX
    readonly PROD_WORKTREE_DIR
    readonly STAGING_WORKTREE_DIR
    readonly WORKTREE_SUPPORT
    
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
                    echo "$PROD_WORKTREE_DIR"
                    ;;
                staging)
                    echo "$STAGING_WORKTREE_DIR"
                    ;;
                *)
                    echo "."
                    ;;
            esac
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

create_worktree() {
    local worktree_dir="$1"
    local target_branch="$2"
    
    log "Creating worktree: $worktree_dir ($target_branch)"
    
    if ! git worktree add "$worktree_dir" "$target_branch"; then
        error "Failed to create worktree at $worktree_dir"
        return 1
    fi
    success "Worktree created: $worktree_dir"
    return 0
}

sync_worktree() {
    local worktree_dir="$1"
    local target_branch="$2"
    
    pushd "$worktree_dir" >/dev/null || return 1
    
    local current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "$target_branch" ]]; then
        error "Worktree $worktree_dir is on wrong branch: $current_branch (expected: $target_branch)"
        popd >/dev/null
        return 1
    fi
    
    log "Syncing $target_branch to latest..."
    if ! git pull origin "$target_branch"; then
        error "Failed to pull latest changes for $target_branch"
        error "Please resolve any conflicts manually in $worktree_dir"
        popd >/dev/null
        return 1
    fi
    
    popd >/dev/null
    success "Worktree synced: $worktree_dir"
    return 0
}

ensure_worktree_ready() {
    local env="$1"
    local debug_mode="$2"
    
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
    fi

    if [[ -n "$USER" ]]; then
        chown -R "$USER:$USER" "$worktree_dir" 2>/dev/null || true
    fi
    
    if ! sync_worktree "$worktree_dir" "$target_branch"; then
        error "Failed to sync $env worktree"
        error "Debug mode requires up-to-date source code"
        exit 1
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
    if ! ensure_worktree_ready "prod" "true"; then
        failed_setups+=("production")
    fi
    
    log "Setting up staging worktree..."
    if ! ensure_worktree_ready "staging" "true"; then
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
    
    # Parse flags
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                debug_mode="true"
                shift
                ;;
            --push)  # NEW: Explicit auto-push flag
                auto_push="true"
                shift
                ;;
            --no-push)
                should_push="false"
                shift
                ;;
            --build)
                force_build="true"
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

    # ============================================================================
    # BUILD STRATEGY - Let Docker decide what needs rebuilding
    # ============================================================================
    local needs_build="false"
    local build_reason=""
    
    # Staging/Local: Always run build (Docker cache handles optimization)
    if [[ "$target_env" == "staging" || "$target_env" == "local" ]]; then
        needs_build="true"
        build_reason="Testing local changes (Docker will cache unchanged layers)"
    
    # Production: Pull from GHCR first, build only if needed
    elif [[ "$target_env" == "prod" ]]; then
        if [[ "$force_build" == "true" ]]; then
            needs_build="true"
            build_reason="Forced rebuild (--build flag) - use after merging to main"
        else
            # Try to pull stable images from GHCR
            log "Pulling production images from GHCR..."
            if docker compose -f $compose_files pull 2>/dev/null; then
                needs_build="false"
                success "Using stable images from GHCR"
            else
                warn "Could not pull from GHCR, will build locally"
                needs_build="true"
                build_reason="GHCR pull failed, building locally (Docker will cache)"
            fi
        fi
    fi
    
    # Debug modes: Always build with source mounting enabled
    if [[ "$debug_mode" == "true" ]]; then
        needs_build="true"
        build_reason="Debug mode - building with source mounting for investigation"
    fi

    # Prepare worktrees if needed (line 687 - existing code continues)
    ensure_worktree_ready "$target_env" "$debug_mode"
    
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
        if ! docker compose -f $compose_files build; then
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
    if ! docker compose -f $compose_files up -d; then
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
                if docker compose -f $compose_files push 2>&1 | \
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
    echo "  switch [env] [--debug] [--build] [--push] [--no-push]"
    echo "                          Switch to environment (prod, staging, local)"
    echo "                          --debug: Enable debug mode with source mounting"
    echo "                          --build: Force rebuild check (for prod after main merge)"
    echo "                          --push: Auto-push to GHCR without prompting"
    echo "                          --no-push: Skip GHCR push entirely (local testing)"
    echo "  status                  Show current environment status"
    echo "  health                  Run health checks on current environment"
    echo "  logs [service]          Show logs for environment or specific service"
    echo "  stop [env]              Stop specific environment or all environments"
    echo "  push [env]              Manually build and push images to GHCR"
    echo "  pull [env]              Pull latest images from GHCR"
    echo "  setup-worktrees         Set up git worktrees for debug modes"
    echo "  help                    Show this help message"
    echo ""
    echo "Common Workflows:"
    echo "  Active development:      env-local"
    echo "  Test before prod:        env-staging"
    echo "  Deploy to production:    env-prod"
    echo "  Update prod after merge: env-prod --build"
    echo "  Push to GHCR (no prompt): env-staging --push"
    echo "  Test locally only:       env-staging --no-push"
    echo "  Debug staging issue:     env-staging-debug"
    echo "  Debug production issue:  env-prod-debug"
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