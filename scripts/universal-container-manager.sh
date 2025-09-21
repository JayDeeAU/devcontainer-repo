#!/bin/bash
# ============================================================================
# Universal Container Manager - Based on Enhanced Container Manager
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
#   Project settings loaded from .container-config.json
#   Fallback to auto-detection if config missing
#
# USAGE:
#   Normal operations: universal-container-manager switch [env]
#   Debug operations:  universal-container-manager switch prod --debug
#   Utilities:         status, health, logs, stop, setup-worktrees, init
#
# AUTHOR: Universal Container Management Team
# VERSION: 2.0.0-universal
# BASED ON: Enhanced Container Manager v1.0.0 (1,200+ lines)
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

readonly SCRIPT_VERSION="2.0.0-universal"
readonly CONFIG_FILE=".container-config.json"

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

# Port range assignments for each environment (PRESERVED from original)
readonly PROD_PORT_BASE=7500
readonly STAGING_PORT_BASE=7600
readonly LOCAL_PORT_BASE=7700

# Docker compose file naming convention (PRESERVED - this is universal)
readonly COMPOSE_FILE_PATTERN="docker/docker-compose.%s.yml"
readonly DEBUG_OVERLAY_PATTERN="docker/docker-compose.%s-debug.yml"

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

# Load project configuration or use defaults
# CORRECT: Load project configuration or use defaults
load_project_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "Loading configuration from $CONFIG_FILE"
        PROJECT_NAME=$(jq -r '.project.name // "unknown"' "$CONFIG_FILE")
        CONTAINER_PREFIX=$(jq -r '.project.container_prefix // "project_"' "$CONFIG_FILE")
        PROD_WORKTREE_DIR=$(jq -r '.project.worktree_dirs.prod // "../${PROJECT_NAME}-production"' "$CONFIG_FILE")
        STAGING_WORKTREE_DIR=$(jq -r '.project.worktree_dirs.staging // "../${PROJECT_NAME}-staging"' "$CONFIG_FILE")
        WORKTREE_SUPPORT=$(jq -r '.project.worktree_support // false' "$CONFIG_FILE")
    else
        # Auto-detect from directory name (THIS IS THE KEY PART)
        PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
        CONTAINER_PREFIX="${PROJECT_NAME}_"
        PROD_WORKTREE_DIR="../${PROJECT_NAME}-production"
        STAGING_WORKTREE_DIR="../${PROJECT_NAME}-staging"
        WORKTREE_SUPPORT=false
        warn "No configuration file found, using auto-detected settings for: $PROJECT_NAME"
        warn "Run 'universal-container-manager init' to create configuration"
    fi
    
    # Make variables readonly after loading
    readonly PROJECT_NAME
    readonly CONTAINER_PREFIX
    readonly PROD_WORKTREE_DIR
    readonly STAGING_WORKTREE_DIR
    readonly WORKTREE_SUPPORT
}

# Load configuration first
load_project_config

# ============================================================================
# UTILITY FUNCTIONS (PRESERVED from original)
# ============================================================================

# Logging functions with consistent formatting
log() { echo -e "${BLUE}${INFO}${NC} $*"; }
success() { echo -e "${GREEN}${CHECK}${NC} $*"; }
warn() { echo -e "${YELLOW}${WARNING}${NC} $*"; }
error() { echo -e "${RED}${ERROR}${NC} $*"; }
header() { echo -e "${PURPLE}${ROCKET}${NC} ${CYAN}$*${NC}"; }
protect() { echo -e "${CYAN}${SHIELD}${NC} $*"; }

# ============================================================================
# ENVIRONMENT DETECTION FUNCTIONS (PRESERVED from original)
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

# Maps Git branches to environment names based on Git Flow conventions
get_environment_for_branch() {
    local branch="$1"
    case "$branch" in
        main|master) echo "prod" ;;
        develop) echo "staging" ;;
        feature/*|hotfix/*|release/*|bugfix/*) echo "local" ;;
        *) echo "local" ;;
    esac
}

# Gets base port number for an environment
get_port_range_for_env() {
    local env="$1"
    case "$env" in
        prod) echo "$PROD_PORT_BASE" ;;
        staging) echo "$STAGING_PORT_BASE" ;;
        local) echo "$LOCAL_PORT_BASE" ;;
        *)
            error "Unknown environment: $env"
            return 1
            ;;
    esac
}

# Constructs Docker Compose file path(s) for an environment
get_compose_file_for_env() {
    local env="$1"
    local debug_mode="$2"
    
    local base_file
    printf -v base_file "$COMPOSE_FILE_PATTERN" "$env"
    
    if [[ "$debug_mode" == "true" && ("$env" == "prod" || "$env" == "staging") ]]; then
        local debug_overlay
        printf -v debug_overlay "$DEBUG_OVERLAY_PATTERN" "$env"
        echo "${base_file}:${debug_overlay}"
    else
        echo "$base_file"
    fi
}

# Determines source directory for environment based on debug mode
get_source_directory_for_env() {
    local env="$1"
    local debug_mode="$2"
    
    case "$env" in
        prod)
            if [[ "$debug_mode" == "true" ]]; then
                echo "$PROD_WORKTREE_DIR"
            else
                echo "none"
            fi
            ;;
        staging)
            if [[ "$debug_mode" == "true" ]]; then
                echo "$STAGING_WORKTREE_DIR"
            else
                echo "none"
            fi
            ;;
        local) echo "." ;;
        *)
            error "Unknown environment: $env"
            return 1
            ;;
    esac
}

# Gets target Git branch for an environment
get_target_branch_for_env() {
    local env="$1"
    case "$env" in
        prod) echo "main" ;;
        staging) echo "develop" ;;
        local) echo "$(get_current_branch)" ;;
        *) echo "unknown" ;;
    esac
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
    
    log "Creating worktree: $worktree_dir → $target_branch"
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
            target_branch="main"
            worktree_dir="$PROD_WORKTREE_DIR"
            ;;
        staging)
            target_branch="develop"
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
    
    if ! sync_worktree "$worktree_dir" "$target_branch"; then
        error "Failed to sync $env worktree"
        error "Debug mode requires up-to-date source code"
        exit 1
    fi
    
    success "Worktree ready for $env debug mode"
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
        error "Please ensure you're using 'docker compose' (not 'docker-compose')"
        error "Update Docker to latest version if needed"
        return 1
    fi
    
    return 0
}

check_compose_file() {
    local compose_files="$1"
    
    IFS=':' read -ra FILES <<< "$compose_files"
    for compose_file in "${FILES[@]}"; do
        if [[ ! -f "$compose_file" ]]; then
            error "Compose file not found: $compose_file"
            error "Expected compose files:"
            error "  docker/docker-compose.prod.yml"
            error "  docker/docker-compose.staging.yml"
            error "  docker/docker-compose.local.yml"
            error "  docker/docker-compose.prod-debug.yml (for debug mode)"
            error "  docker/docker-compose.staging-debug.yml (for debug mode)"
            return 1
        fi
    done
    
    return 0
}

start_environment() {
    local env="$1"
    local debug_mode="$2"
    local compose_files="$3"
    local base_port="$4"
    
    if is_environment_running "$env"; then
        success "$env environment is already running"
        return 0
    fi
    
    if [[ "$debug_mode" == "true" ]]; then
        log "Starting $env environment in DEBUG mode (source mounting enabled)..."
        warn "This is for investigation only - make code changes in local hotfix branches"
    else
        log "Starting $env environment in PRODUCTION mode (optimized builds)..."
    fi
    
    export COMPOSE_PROJECT_NAME="${CONTAINER_PREFIX%_}-$env"
    export ENVIRONMENT="$env"
    
    local source_dir=$(get_source_directory_for_env "$env" "$debug_mode")
    if [[ "$source_dir" != "none" ]]; then
        export SOURCE_DIR="$source_dir"
        success "Source mapping: $source_dir → containers"
    else
        unset SOURCE_DIR
        success "Using built images only (no source mounting)"
    fi
    
    log "Building and starting containers..."
    if ! docker compose -f "$compose_files" up -d --build; then
        error "Failed to start $env environment"
        error "Check Docker logs for details: docker compose -f $compose_files logs"
        return 1
    fi
    
    success "$env environment started successfully"
    return 0
}

wait_for_containers() {
    local compose_files="$1"
    local max_wait=60
    local wait_time=0
    
    log "Waiting for containers to be ready..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        local running=$(docker compose -f "$compose_files" ps --services --filter "status=running" 2>/dev/null | wc -l)
        
        if [[ $running -gt 0 ]]; then
            success "Containers are starting ($running services running)"
            return 0
        fi
        
        sleep 2
        wait_time=$((wait_time + 2))
        echo -n "."
    done
    
    echo ""
    warn "Container startup is taking longer than expected"
    warn "Check container logs if issues persist"
    return 1
}

stop_specific_environment() {
    local env="$1"
    local compose_file
    printf -v compose_file "$COMPOSE_FILE_PATTERN" "$env"
    
    if ! is_environment_running "$env"; then
        warn "$env environment is not running"
        return 0
    fi
    
    if [[ ! -f "$compose_file" ]]; then
        error "Compose file not found: $compose_file"
        return 1
    fi
    
    log "Stopping $env environment..."
    if ! docker compose -f "$compose_file" down --remove-orphans 2>/dev/null; then
        error "Failed to stop $env environment cleanly"
        warn "Some containers may still be running"
    fi
    
    success "$env environment stopped"
    return 0
}

stop_all_environments() {
    header "Stopping All Containers"
    echo "======================="
    
    local running_envs=()
    for env in prod staging local; do
        if is_environment_running "$env"; then
            running_envs+=("$env")
        fi
    done
    
    if [[ ${#running_envs[@]} -eq 0 ]]; then
        log "No environments are currently running"
        return 0
    fi
    
    warn "This will stop ALL environments: ${running_envs[*]}"
    warn "Users testing on staging/production will be affected!"
    echo ""
    read -p "Are you sure you want to stop all containers? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Operation cancelled - no containers stopped"
        return 0
    fi
    
    local failed_stops=()
    for env in prod staging local; do
        local compose_file
        printf -v compose_file "$COMPOSE_FILE_PATTERN" "$env"
        if [[ -f "$compose_file" ]]; then
            log "Stopping $env environment..."
            if ! docker compose -f "$compose_file" down --remove-orphans 2>/dev/null; then
                failed_stops+=("$env")
            fi
        fi
    done
    
    log "Cleaning up any remaining containers..."
    local remaining=$(docker ps -q --filter "name=${CONTAINER_PREFIX}" 2>/dev/null || true)
    if [[ -n "$remaining" ]]; then
        echo "$remaining" | xargs docker stop 2>/dev/null || true
        echo "$remaining" | xargs docker rm 2>/dev/null || true
    fi
    
    if [[ ${#failed_stops[@]} -eq 0 ]]; then
        success "All containers stopped successfully"
    else
        warn "Some environments failed to stop cleanly: ${failed_stops[*]}"
        warn "Manual cleanup may be required"
    fi
    
    return 0
}

# ============================================================================
# HEALTH CHECK FUNCTIONS (PRESERVED from original)
# ============================================================================

health_check() {
    local env="$1"
    local base_port="$2"
    local docker_host="${3:-localhost}"
    
    header "Running Health Checks for $env"
    echo "================================="
    
    if ! is_environment_running "$env"; then
        error "$env environment is not running"
        echo ""
        echo "Start the environment first:"
        echo "  env-$env      → Start $env environment"
        if [[ "$env" == "prod" || "$env" == "staging" ]]; then
            echo "  env-$env-debug → Start $env debug mode"
        fi
        return 1
    fi
    
    local backend_port=$((base_port + 10))
    local frontend_port=$base_port
    
    log "Waiting for services to initialize..."
    sleep 10
    
    local health_issues=0
    
    echo -n "Backend (port $backend_port): "
    if timeout 10 curl -f "http://$docker_host:$backend_port/health" >/dev/null 2>&1; then
        success "Healthy"
    elif timeout 10 curl -f "http://$docker_host:$backend_port" >/dev/null 2>&1; then
        warn "Responding (no /health endpoint)"
    else
        error "Not responding"
        ((health_issues++))
    fi
    
    echo -n "Frontend (port $frontend_port): "
    if timeout 10 curl -f "http://$docker_host:$frontend_port" >/dev/null 2>&1; then
        success "Accessible"
    else
        error "Not accessible"
        ((health_issues++))
    fi
    
    echo -n "Redis: "
    if docker exec "${CONTAINER_PREFIX}redis-$env" redis-cli ping >/dev/null 2>&1; then
        success "Healthy"
    else
        error "Not responding"
        ((health_issues++))
    fi
    
    echo ""
    if [[ $health_issues -eq 0 ]]; then
        success "All health checks passed"
    else
        warn "$health_issues health check(s) failed"
        echo "Check container logs: env-logs"
    fi
    
    return $health_issues
}

# ============================================================================
# DISPLAY FUNCTIONS (PRESERVED from original)
# ============================================================================

show_environment_info() {
    local env="$1"
    local debug_mode="$2"
    local base_port="$3"
    
    echo ""
    if [[ "$debug_mode" == "true" ]]; then
        header "$env Environment (DEBUG MODE)"
        warn "${DEBUG} Source mounting + development commands enabled"
        warn "Use for investigation only - make code changes in local hotfix branches"
    else
        header "$env Environment"
        success "${PACKAGE} Production optimized builds"
    fi
    
    echo "========================="
    echo -e "${BRANCH} Target Branch: ${CYAN}$(get_target_branch_for_env "$env")${NC}"
    echo -e "${GEAR} Environment: ${CYAN}$env${NC}"
    echo -e "${NETWORK} Port Range: ${CYAN}${base_port}xx${NC}"
    echo ""
    echo -e "${CONTAINER} Container Prefix: ${CYAN}${CONTAINER_PREFIX}*-$env${NC}"
    echo -e "${INFO} Project: ${CYAN}$PROJECT_NAME${NC}"
    
    local source_dir=$(get_source_directory_for_env "$env" "$debug_mode")
    if [[ "$source_dir" != "none" ]]; then
        echo -e "${DEBUG} Source Directory: ${CYAN}$source_dir${NC}"
        if [[ "$debug_mode" == "true" ]]; then
            echo -e "${INFO} Dockerfile: ${CYAN}Dockerfile.dev${NC}"
            echo -e "${INFO} Commands: ${CYAN}npm run dev, uvicorn --reload${NC}"
        fi
    else
        echo -e "${PACKAGE} Built Images: ${CYAN}No source mounting${NC}"
        echo -e "${INFO} Dockerfile: ${CYAN}Dockerfile.prod${NC}"
        echo -e "${INFO} Commands: ${CYAN}npm start, uvicorn production${NC}"
    fi
    echo ""
}

show_access_points() {
    local base_port="$1"
    local env="$2"
    local docker_host="${3:-localhost}"
    local debug_mode="${4:-false}"
    
    echo -e "${NETWORK} Access Points for $env:"
    if [[ "$debug_mode" == "true" ]]; then
        echo -e "   ${DEBUG} Debug Mode Active (development commands)${NC}"
    fi
    
    echo "   Frontend:    http://${docker_host}:$base_port"
    echo "   Backend:     http://${docker_host}:$((base_port + 10))"
    echo "   Redis:       http://${docker_host}:$((base_port + 30))"
    
    if [[ "$env" == "local" ]]; then
        echo "   Flower:      http://${docker_host}:$((base_port + 55)) (--profile flower)"
        echo "   RedisInsight: http://${docker_host}:$((base_port + 85)) (--profile redis-tools)"
        echo ""
        echo "${INFO} Local profiles available:"
        echo "   Core services: docker compose up"
        echo "   With Flower: docker compose --profile flower up"
        echo "   With RedisInsight: docker compose --profile redis-tools up"
        echo "   Full stack: docker compose --profile flower --profile redis-tools up"
    else
        echo "   Flower:      http://${docker_host}:$((base_port + 55))"
        echo "   RedisInsight: http://${docker_host}:$((base_port + 85))"
    fi
    echo ""
}

show_status() {
    local docker_host=$(detect_docker_host)
    
    header "System Status - $PROJECT_NAME"
    echo "==============================="
    echo ""
    
    echo -e "${NETWORK} Running Environment Access Points:"
    local any_running=false
    
    for check_env in prod staging local; do
        if is_environment_running "$check_env"; then
            any_running=true
            local check_port=$(get_port_range_for_env "$check_env")
            echo ""
            echo -e "${CYAN}$check_env Environment:${NC}"
            echo "   Frontend: http://${docker_host}:$check_port"
            echo "   Backend:  http://${docker_host}:$((check_port + 10))"
            echo "   Redis:    http://${docker_host}:$((check_port + 30))"
        fi
    done
    
    if ! $any_running; then
        echo "   ${YELLOW}No environments currently running${NC}"
        echo ""
        echo "Start an environment with:"
        echo "   env-prod, env-staging, or env-local"
    fi
    
    echo ""
    echo -e "${SHIELD} Available Commands:"
    echo "   env-prod          → Production (built images)"
    echo "   env-prod-debug    → Production (source mapped) ${DEBUG}"
    echo "   env-staging       → Staging (built images)"
    echo "   env-staging-debug → Staging (source mapped) ${DEBUG}"
    echo "   env-local         → Local development (source mapped)"
    echo ""
    echo "   env-health        → Health checks"
    echo "   env-status        → This status display"
    echo "   env-logs [svc]    → Show logs"
    echo "   env-stop [env]    → Stop environment(s)"
    echo ""
}

show_container_status() {
    local compose_files="$1"
    local env="$2"
    
    header "Container Status for $env"
    echo "========================="
    
    if docker compose -f "$compose_files" ps 2>/dev/null; then
        echo ""
    else
        error "Unable to show container status"
        error "Compose files may be missing or invalid: $compose_files"
    fi
}

show_logs() {
    local compose_files="$1"
    local service="${2:-}"
    
    if [[ -n "$service" ]]; then
        log "Showing logs for service: $service"
        docker compose -f "$compose_files" logs --tail=50 -f "$service"
    else
        log "Showing logs for all services (last 20 lines each)"
        docker compose -f "$compose_files" logs --tail=20
    fi
}

# ============================================================================
# MAIN ENVIRONMENT SWITCHING FUNCTION (PRESERVED from original)
# ============================================================================

switch_environment() {
    local env="$1"
    local debug_mode="${2:-false}"
    local base_port=$(get_port_range_for_env "$env")
    local compose_files=$(get_compose_file_for_env "$env" "$debug_mode")
    
    show_environment_info "$env" "$debug_mode" "$base_port"
    
    if ! check_docker_compose; then
        return 1
    fi
    
    if ! check_compose_file "$compose_files"; then
        return 1
    fi
    
    ensure_worktree_ready "$env" "$debug_mode"
    
    if is_environment_running "$env"; then
        success "$env environment is already running - no changes needed"
        show_access_points "$base_port" "$env" "localhost" "$debug_mode"
        show_container_status "$compose_files" "$env"
        return 0
    fi
    
    start_environment "$env" "$debug_mode" "$compose_files" "$base_port"
    wait_for_containers "$compose_files"
    show_access_points "$base_port" "$env" "localhost" "$debug_mode"
    show_container_status "$compose_files" "$env"
    
    success "Environment switch completed!"
    return 0
}

# ============================================================================
# COMMAND FUNCTIONS (PRESERVED + NEW)
# ============================================================================

run_health_check() {
    local branch=$(get_current_branch)
    local env=$(get_environment_for_branch "$branch")
    local base_port=$(get_port_range_for_env "$env")
    local docker_host=$(detect_docker_host)
    
    health_check "$env" "$base_port" "$docker_host"
    
    local compose_files=$(get_compose_file_for_env "$env" "false")
    if check_compose_file "$compose_files" >/dev/null 2>&1; then
        show_container_status "$compose_files" "$env"
    fi
    
    return $?
}

setup_worktrees() {
    if [[ "$WORKTREE_SUPPORT" != "true" ]]; then
        warn "Worktree support is disabled for this project"
        warn "Enable in .container-config.json: \"worktree_support\": true"
        return 1
    fi
    
    header "Setting Up Worktrees"
    echo "===================="
    echo ""
    echo "This will create separate source directories for production and staging:"
    echo "  $PROD_WORKTREE_DIR    → main branch (for production debugging)"
    echo "  $STAGING_WORKTREE_DIR → develop branch (for staging debugging)"
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
        echo "  Production: $PROD_WORKTREE_DIR (main branch)"
        echo "  Staging:    $STAGING_WORKTREE_DIR (develop branch)"
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

# NEW: Initialize project with universal container management
initialize_project() {
    header "Initializing Universal Container Management"
    echo "==========================================="
    echo ""
    
    if [[ -f "$CONFIG_FILE" ]]; then
        warn "Configuration file already exists: $CONFIG_FILE"
        read -p "Overwrite existing configuration? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Initialization cancelled"
            return 0
        fi
    fi
    
    echo "Use the config generator to create project configuration:"
    echo "  .devcontainer/scripts/config-generator.sh default"
    echo "  .devcontainer/scripts/config-generator.sh fullstack"
    echo ""
    echo "Or manually create .container-config.json for custom setup."
}


show_help() {
    echo ""
    header "Universal Container Manager with Worktree Support"
    echo "================================================="
    echo ""
    echo "${SHIELD}  SMART ISOLATION: Each environment runs independently on different ports"
    echo "${DEBUG}  DEBUG MODES: Source mounting for investigation (not code changes)"
    echo "${PACKAGE}  PRODUCTION BUILDS: Optimized images by default"
    echo "${GEAR}  PROJECT AGNOSTIC: Works with any project via configuration"
    echo ""
    echo "Environment Strategy:"
    echo "  ${PACKAGE} Production/Staging: Built images (Dockerfile.prod), optimized commands"
    echo "  ${DEBUG} Debug Modes: Source mounting (Dockerfile.dev), development commands"
    echo "  ${GEAR} Local: Always source mounted (Dockerfile.dev) for active development"
    echo ""
    echo "Port Assignments:"
    echo "  Production:  7500-7599  (built images by default)"
    echo "  Staging:     7600-7699  (built images by default)"
    echo "  Local:       7700-7799  (always source mounted)"
    echo ""
    echo "Branch → Environment Mapping:"
    echo "  main/master  → Production environment"
    echo "  develop      → Staging environment"
    echo "  feature/*    → Local development environment"
    echo "  hotfix/*     → Local development environment"
    echo "  release/*    → Local development environment"
    echo ""
    echo "Commands:"
    echo "  switch [env] [--debug]  Switch to environment (auto-detect if not specified)"
    echo "  health                  Health checks for current environment"
    echo "  status                  Show all running environments"
    echo "  logs [service]          Show logs (optionally for specific service)"
    echo "  stop [env]              Stop specific environment or all with confirmation"
    echo "  setup-worktrees         Initialize worktrees for production and staging"
    echo "  init                    Initialize project with universal container management"
    echo "  help                    Show this help message"
    echo ""
    echo "Project: $PROJECT_NAME"
    echo "Config: $CONFIG_FILE"
    if [[ "$WORKTREE_SUPPORT" == "true" ]]; then
        echo "Worktree Support: Enabled"
        echo "  Production worktree: $PROD_WORKTREE_DIR"
        echo "  Staging worktree: $STAGING_WORKTREE_DIR"
    else
        echo "Worktree Support: Disabled"
    fi
    echo ""
    echo "Usage Examples:"
    echo "  $0 switch prod          # Start production with built images"
    echo "  $0 switch prod --debug  # Start production with source access for debugging"
    echo "  $0 init                 # Initialize new project"
    echo "  $0 status               # Show all running environments"
    echo "  $0 stop staging         # Stop only staging environment"
    echo "  $0 stop                 # Stop all environments (with confirmation)"
    echo ""
}

# ============================================================================
# MAIN SCRIPT LOGIC (ENHANCED from original)
# ============================================================================

main() {
    local command="${1:-help}"
    
    case "$command" in
        switch|s)
            local env="${2:-}"
            local debug_mode="false"
            
            # Check for debug flag
            if [[ "$3" == "--debug" || "$2" == "--debug" ]]; then
                debug_mode="true"
                if [[ "$2" == "--debug" ]]; then
                    env=""  # No environment specified, will auto-detect
                fi
            fi
            
            # Auto-detect environment if not specified
            if [[ -z "$env" ]]; then
                local branch=$(get_current_branch)
                env=$(get_environment_for_branch "$branch")
                log "Auto-detected environment '$env' from branch '$branch'"
            fi
            
            # Handle debug mode warnings for prod/staging
            if [[ "$debug_mode" == "true" && ("$env" == "prod" || "$env" == "staging") ]]; then
                if is_environment_running "$env"; then
                    warn "This will replace the running $env environment with debug mode"
                    warn "$env users will temporarily see development version"
                    echo ""
                    read -p "Continue with $env debug mode? [y/N]: " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        log "$env debug cancelled"
                        return 0
                    fi
                    stop_specific_environment "$env"
                fi
            fi
            
            switch_environment "$env" "$debug_mode"
            ;;
        health|h)
            run_health_check
            ;;
        status|st)
            show_status
            ;;
        logs|l)
            local branch=$(get_current_branch)
            local env=$(get_environment_for_branch "$branch")
            local compose_files=$(get_compose_file_for_env "$env" "false")
            if check_compose_file "$compose_files" >/dev/null 2>&1; then
                show_logs "$compose_files" "$2"
            else
                error "No valid environment found for logs"
                error "Start an environment first or specify compose files manually"
                return 1
            fi
            ;;
        setup-worktrees)
            setup_worktrees
            ;;
        stop)
            if [[ -n "$2" ]]; then
                case "$2" in
                    prod|staging|local)
                        stop_specific_environment "$2"
                        ;;
                    all)
                        stop_all_environments
                        ;;
                    *)
                        error "Invalid environment: $2"
                        echo ""
                        echo "Usage: $0 stop [prod|staging|local|all]"
                        exit 1
                        ;;
                esac
            else
                stop_all_environments
            fi
            ;;
        init)
            initialize_project
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Export functions that may be used by Git hooks or other scripts
export -f get_current_branch
export -f get_environment_for_branch
export -f switch_environment
export -f run_health_check
export -f is_environment_running

# Trap errors and provide helpful context
trap 'error "Script failed at line $LINENO. Check the error above for details."' ERR

# Only execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# ============================================================================
# END OF SCRIPT
# ============================================================================