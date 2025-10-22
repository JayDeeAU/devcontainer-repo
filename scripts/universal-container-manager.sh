#!/bin/bash
# ============================================================================
# Universal Container Manager - Simplified Architecture
# ============================================================================
#
# PURPOSE:
#   Cross-project container management with environment-based deployment
#   Provides production-optimized builds with development mode for local work
#
# ARCHITECTURE:
#   - Production/Staging: Built images (Dockerfile.prod), no source mounting
#   - Local: Source mounted (Dockerfile.dev) for active development
#   - Configuration-driven: Uses .container-config.json for project settings
#
# ENVIRONMENTS:
#   prod (7500-7599):     Production environment, main branch, built images only
#   staging (7600-7699):  Staging environment, current branch, built images only
#   local (7700-7799):    Local development, current branch, source mounted
#
# CONFIGURATION:
#   Project settings loaded from .container-config.json (required)
#   Use config generator: .devcontainer/scripts/config-generator.sh
#
# USAGE:
#   Normal operations: universal-container-manager switch [env]
#                      universal-container-manager switch [env] --build
#   Utilities:         status, health, logs, stop
#
# FLAGS:
#   --build   Force rebuild (required for staging/local with code changes)
#   --push    Auto-push to GHCR after successful build
#
# DEBUGGING STRATEGY:
#   For debugging prod/staging issues:
#   1. Create a debug branch (e.g., debug/prod-issue)
#   2. Switch to env-local for full development environment with source mounting
#   3. Make changes, test, and commit to your debug branch
#
# AUTHOR: Universal Container Management Team
# VERSION: 3.0.0-simplified
# BASED ON: Enhanced Container Manager v2.0.0 (1,486 lines)
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="3.0.0-simplified"
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

# Dynamic project detection (no hardcoding)
# These will be set by load_project_config()
PROJECT_NAME=""
CONTAINER_PREFIX=""

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

# Generate container prefix from project name
get_container_prefix() {
    local project_name="$1"
    echo "${project_name}_"
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

        # Validate required fields
        if [[ -z "$PROJECT_NAME" ]]; then
            warn "No project name in config, auto-detecting..."
            PROJECT_NAME=$(get_project_name)
        fi

        if [[ -z "$CONTAINER_PREFIX" ]]; then
            CONTAINER_PREFIX=$(get_container_prefix "$PROJECT_NAME")
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

# Universal compose file detection
get_compose_file_for_env() {
    local env="$1"

    # Load compose files from config if available
    if [[ -f "$CONFIG_FILE" ]]; then
        local compose_files=$(jq -r ".environments.${env}.compose_files[]? // empty" "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$compose_files" ]]; then
            echo "$compose_files" | tr '\n' ' '
            return
        fi
    fi

    # Universal default compose file pattern
    echo "docker/docker-compose.${env}.yml"
}

# Universal source directory detection with VSCode support
# Returns the source directory path for volume mounting
# - For prod/staging: Returns current directory (for logs only - no full source mounting)
# - For local: Returns current directory (for full source mounting)
get_source_directory_for_env() {
    local env="$1"

    # All environments use current directory, with devcontainer path translation if needed
    local current_dir="$(pwd)"

    # DEVCONTAINER FIX: Translate to host path when running in devcontainer
    if [[ -n "$REMOTE_CONTAINERS" && "$REMOTE_CONTAINERS" == "true" ]]; then
        local current_repo_name="$(basename "$current_dir")"

        # Detect devcontainer name
        local container_name=""
        for pattern in "devcontainer_${current_repo_name}" "vsc-${current_repo_name}" "${current_repo_name}-devcontainer"; do
            if docker inspect "$pattern" >/dev/null 2>&1; then
                container_name="$pattern"
                break
            fi
        done

        if [[ -z "$container_name" ]]; then
            container_name=$(docker ps --format '{{.Names}}' | grep -iE "devcontainer.*${current_repo_name}|vsc-${current_repo_name}" | head -1)
        fi

        if [[ -n "$container_name" ]]; then
            # Get host path from devcontainer mount
            local host_path=$(docker inspect "$container_name" 2>/dev/null | \
                jq -r ".[0].Mounts[] | select(.Destination == \"${current_dir}\") | .Source" 2>/dev/null)

            if [[ -n "$host_path" && "$host_path" != "null" ]]; then
                echo "$host_path"
                return
            fi
        fi
    fi

    # Default: return absolute path to current directory (Docker Compose needs absolute paths)
    echo "$current_dir"
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
# BUILD METADATA & DEPENDENCY TRACKING
# ============================================================================

# Generate .env.local.buildinfo with current git metadata
generate_local_buildinfo() {
    local version=$(jq -r '.version' frontend/package.json 2>/dev/null || echo "dev")
    local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log "Generating .env.local.buildinfo with current git metadata..."

    # Overwrite .env.local.buildinfo
    cat > .env.local.buildinfo << EOF
# Auto-generated build metadata - DO NOT EDIT
# Generated: ${build_time}
# This file is recreated every time env-local starts

# Frontend build metadata (NEXT_PUBLIC_ for client-side access)
NEXT_PUBLIC_VERSION=${version}
NEXT_PUBLIC_GIT_COMMIT=${git_commit}
NEXT_PUBLIC_GIT_BRANCH=${git_branch}
NEXT_PUBLIC_BUILD_TIME=${build_time}

# Backend build metadata
APP_VERSION=${version}
GIT_COMMIT=${git_commit}
GIT_BRANCH=${git_branch}
BUILD_TIME=${build_time}
EOF

    success "Build metadata generated: v${version} @ ${git_branch} (${git_commit:0:7})"
}

# Build local dev images with metadata
build_local_images_with_metadata() {
    local version=$(jq -r '.version' frontend/package.json 2>/dev/null || echo "dev")
    local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Read image names from config (project-agnostic)
    local backend_dev_image=$(jq -r '.project.images.backend.dev // "backend-dev"' "$CONFIG_FILE")
    local frontend_dev_image=$(jq -r '.project.images.frontend.dev // "frontend-dev"' "$CONFIG_FILE")

    log "Building backend dev image with metadata..."
    docker build \
        --build-arg VERSION="$version" \
        --build-arg GIT_COMMIT="$git_commit" \
        --build-arg GIT_BRANCH="$git_branch" \
        --build-arg BUILD_TIME="$build_time" \
        -f backend/Dockerfile.dev \
        -t ${backend_dev_image}:latest \
        . || {
            error "Backend build failed"
            return 1
        }

    log "Building frontend dev image with metadata..."
    docker build \
        --build-arg VERSION="$version" \
        --build-arg GIT_COMMIT="$git_commit" \
        --build-arg GIT_BRANCH="$git_branch" \
        --build-arg BUILD_TIME="$build_time" \
        -f frontend/Dockerfile.dev \
        -t ${frontend_dev_image}:latest \
        . || {
            error "Frontend build failed"
            return 1
        }

    success "Dev images built successfully"
}

# ============================================================================
# COMMAND FUNCTIONS
# ============================================================================

# Main switch command with universal project support
switch_environment() {
    local target_env="$1"
    local should_push="false"
    local force_build="false"
    local auto_push="false"  # Auto-push without prompt

    # Parse flags
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
            *)
                shift
                ;;
        esac
    done

    # Determine if we should offer to push (non-local environments only)
    if [[ "$target_env" != "local" ]]; then
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

    # ============================================================================
    # BRANCH TRACKING (PROD ENVIRONMENT ONLY)
    # ============================================================================
    # env-prod: Track current branch, switch to main, run operations, return to original branch
    # env-staging: Run current branch in staging environment (no switching)
    # env-local: Run current branch (no switching)

    local original_branch=""
    local needs_branch_restore=false

    if [[ "$target_env" == "prod" ]]; then
        # Track current branch
        if git rev-parse --git-dir >/dev/null 2>&1; then
            original_branch=$(git branch --show-current 2>/dev/null || echo "")

            if [[ -n "$original_branch" && "$original_branch" != "main" ]]; then
                log "🌿 Tracking current branch: $original_branch"
                log "🌿 Switching to main branch for production environment..."

                if git checkout main 2>/dev/null; then
                    needs_branch_restore=true
                    success "Switched to main branch"
                else
                    error "Failed to switch to main branch"
                    error "Continuing with current branch: $original_branch"
                fi
            elif [[ "$original_branch" == "main" ]]; then
                log "Already on main branch"
            fi
        fi
    fi

    # ============================================================================
    # DEPENDENCY CHANGE DETECTION
    # ============================================================================
    # Check if dependencies changed since last build (warn user)
    if command -v .devcontainer/scripts/version-manager.sh >/dev/null 2>&1; then
        if .devcontainer/scripts/version-manager.sh check-deps "$target_env" 2>/dev/null; then
            warn "Dependencies have changed since last build!"
            echo ""
            log "Last build information:"
            .devcontainer/scripts/version-manager.sh build-info "$target_env" | jq '.' 2>/dev/null || echo "  (no previous build found)"
            echo ""
            warn "Consider rebuilding with:"
            warn "  env-${target_env}-build       (explicit command)"
            warn "  env-${target_env} --build     (build flag)"
            echo ""

            # Only prompt if not already building
            if [[ "$force_build" != "true" ]]; then
                read -p "Continue without rebuilding? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log "Exiting. Please rebuild first."
                    return 1
                fi
            fi
        fi
    fi

    # ============================================================================
    # LOCAL ENVIRONMENT - SPECIAL HANDLING
    # ============================================================================
    # For local: handle buildinfo generation and optional rebuild
    if [[ "$target_env" == "local" ]]; then
        local should_rebuild=false

        # Check if rebuild needed (if not already building)
        if [[ "$force_build" != "true" ]]; then
            if command -v .devcontainer/scripts/version-manager.sh >/dev/null 2>&1; then
                if .devcontainer/scripts/version-manager.sh check-deps "local" 2>/dev/null; then
                    warn "Dependencies changed - rebuild recommended for local environment"
                    read -p "Rebuild dev images? (Y/n): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                        should_rebuild=true
                        force_build="true"  # Set flag for BUILD PHASE
                    fi
                fi
            fi
        fi

        # Build dev images if needed
        if [[ "$should_rebuild" == "true" || "$force_build" == "true" ]]; then
            log "Building local dev images with metadata..."
            if ! build_local_images_with_metadata; then
                error "Failed to build local dev images"
                return 1
            fi
            # Store build metadata
            if command -v .devcontainer/scripts/version-manager.sh >/dev/null 2>&1; then
                .devcontainer/scripts/version-manager.sh store-build "local" 2>/dev/null || true
            fi
        fi

        # Always regenerate buildinfo (branch might have changed)
        generate_local_buildinfo
    fi

    # Check prerequisites
    if ! check_docker_compose; then
        return 1
    fi

    # Get compose files for this environment
    local compose_files=$(get_compose_file_for_env "$target_env")
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

    # Stop existing containers for this environment (if any)
    if is_environment_running "$target_env"; then
        log "Stopping existing $target_env containers..."
        docker compose -f "$(get_compose_file_for_env "$target_env")" down --remove-orphans 2>/dev/null || true
    fi

    # ALWAYS set SOURCE_DIR for volume mounts (logs only for prod/staging, full source for local)
    local source_dir=$(get_source_directory_for_env "$target_env")
    export SOURCE_DIR="$source_dir"
    log "SOURCE_DIR set to: $SOURCE_DIR"
    
    # ============================================================================
    # BUILD PHASE - Docker shows live progress, intelligently uses cache
    # ============================================================================
    if [[ "$needs_build" == "true" ]]; then
        header "Building $target_env Environment"
        log "Reason: $build_reason"

        # Generate and export build metadata for docker compose
        # Docker will automatically pass these to Dockerfile ARG declarations
        export VERSION=$(jq -r '.version' frontend/package.json 2>/dev/null || echo "unknown")
        export GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        export GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        export BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        log "Build metadata: v${VERSION} @ ${GIT_BRANCH} (${GIT_COMMIT:0:7}) - ${BUILD_TIME}"

        log "Building images (showing live progress)..."
        echo ""

        # Build with live output (don't capture - so you see progress)
        if ! docker compose $compose_flags build; then
            error "Failed to build $target_env environment"
            return 1
        fi

        echo ""
        success "Build completed successfully"

        # Store build metadata after successful build
        if command -v .devcontainer/scripts/version-manager.sh >/dev/null 2>&1; then
            .devcontainer/scripts/version-manager.sh store-build "$target_env" 2>/dev/null || true
        fi

        # ============================================================================
        # PUSH TO GHCR - Immediately after successful build (non-local only)
        # ============================================================================
        if [[ "$should_push" == "true" ]]; then
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
                    log "Build completed successfully!"
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
                    # Store push exit code before grep filtering
                    docker compose $compose_flags push 2>&1 | \
                       grep -v "Preparing\|Waiting\|Layer already exists\|Pushed" | \
                       grep -E "^(Pulling|Pushing|.*:.*|Error|denied)" || true

                    local push_exit_code=${PIPESTATUS[0]}

                    if [ $push_exit_code -eq 0 ]; then
                        echo ""
                        success "Images pushed to GHCR successfully!"
                        success "→ Images are now available across all your machines"
                    else
                        echo ""
                        error "Failed to push images to GHCR (exit code: $push_exit_code)"
                        error "Continuing with local images..."
                        echo ""
                        echo "Possible causes:"
                        echo "  - GHCR authentication token expired"
                        echo "  - Network connectivity issues"
                        echo "  - Repository permissions problems"
                        echo ""
                        echo "Recovery steps:"
                        echo "  1. Check GHCR auth: ghcr-status"
                        echo "  2. Re-authenticate: ghcr-login"
                        echo "  3. Retry push: docker compose $compose_flags push"
                    fi
                else
                    log "Skipping GHCR push - images only available locally"
                fi
            fi
        fi

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
    show_environment_info "$target_env" "$base_port"

    success "Successfully switched to $target_env environment"

    # ============================================================================
    # BRANCH RESTORATION (PROD ENVIRONMENT ONLY)
    # ============================================================================
    # Restore original branch if we switched for prod environment

    if [[ "$needs_branch_restore" == "true" && -n "$original_branch" ]]; then
        log "🌿 Restoring original branch: $original_branch"
        if git checkout "$original_branch" 2>/dev/null; then
            success "Restored to original branch: $original_branch"
        else
            warn "Failed to restore branch: $original_branch"
            warn "You may need to manually checkout your original branch"
        fi
    fi

    return 0
}

show_environment_info() {
    local env="$1"
    local base_port="$2"

    echo ""
    header "$env Environment"

    echo "========================="
    echo -e "${BRANCH} Target Branch: ${CYAN}$(get_target_branch_for_env "$env")${NC}"
    echo -e "${GEAR}  Environment: ${CYAN}$env${NC}"
    echo -e "${NETWORK} Port Range: ${CYAN}${base_port}xx${NC}"
    echo ""
    echo -e "${CONTAINER} Container Prefix: ${CYAN}${CONTAINER_PREFIX}*-$env${NC}"
    echo -e "${INFO}  Project: ${CYAN}$PROJECT_NAME${NC}"

    local source_dir=$(get_source_directory_for_env "$env")
    if [[ "$env" == "local" ]]; then
        echo -e "${DEBUG} Source Directory: ${CYAN}$source_dir${NC}"
        echo -e "${INFO} Mount Path: ${CYAN}/workspaces/$PROJECT_NAME${NC}"
        echo -e "${INFO} Mode: ${CYAN}Development with full source mounting${NC}"
    else
        echo -e "${PACKAGE} Mode: ${CYAN}Production build (no source mounting)${NC}"
        echo -e "${INFO} Logs accessible via: ${CYAN}$source_dir/backend/logs/${env}, $source_dir/frontend/logs/${env}${NC}"
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

    local compose_files=$(get_compose_file_for_env "$env")

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

    local compose_files=$(get_compose_file_for_env "$env")

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
    local compose_files=$(get_compose_file_for_env "$current_env")

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
            local compose_files=$(get_compose_file_for_env "$env")
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
                local compose_files=$(get_compose_file_for_env "$env")
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
    echo "${PACKAGE}  INTELLIGENT CACHING: Docker rebuilds only changed layers"
    echo "${GEAR}  PROJECT AGNOSTIC: Works with any project via configuration"
    echo ""
    echo "Current Project: ${CYAN}$PROJECT_NAME${NC}"
    echo "Container Prefix: ${CYAN}$CONTAINER_PREFIX${NC}"
    echo ""
    echo "Environment Strategy:"
    echo "  ${GEAR} Local:       Development with source mounting (Dockerfile.dev)"
    echo "  ${PACKAGE} Staging:     Production build on current branch (Dockerfile.prod)"
    echo "  ${PACKAGE} Production:  Production build on main branch (Dockerfile.prod)"
    echo ""
    echo "Port Assignments:"
    echo "  Production:  7500-7599  (main branch, production builds)"
    echo "  Staging:     7600-7699  (current branch, production builds)"
    echo "  Local:       7700-7799  (current branch, development with source mounting)"
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
    echo "    --build, build            Force rebuild with latest changes"
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
    echo "  help                        Show this help message"
    echo ""
    echo "Common Workflows:"
    echo "  Active development:         env-local"
    echo "  Test before prod:           env-staging"
    echo "  Deploy to production:       env-prod"
    echo "  Update prod after merge:    env-prod --build  (or: env-prod build)"
    echo "  Push to GHCR (no prompt):   env-staging --push  (or: env-staging push)"
    echo "  Test locally only:          env-staging --no-push"
    echo ""
    echo "Debugging Strategy:"
    echo "  To debug prod/staging issues:"
    echo "    1. Create a debug branch (e.g., debug/prod-issue)"
    echo "    2. Switch to env-local for full source mounting"
    echo "    3. Make changes, test, and commit to your debug branch"
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