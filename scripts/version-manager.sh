#!/bin/bash
# scripts/version-manager.sh - Sequential versioning with simple conflict resolution
# Predictable increments, acceptable gaps from abandoned branches
# Enhanced with locking for multi-session/worktree safety

set -e

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions (output to stderr to not pollute command output)
log() { echo -e "${BLUE}ℹ️${NC} $*" >&2; }
success() { echo -e "${GREEN}✅${NC} $*" >&2; }
warn() { echo -e "${YELLOW}⚠️${NC} $*" >&2; }
error() { echo -e "${RED}❌${NC} $*" >&2; }

# ============================================================================
# WORKTREE-AWARE PATH RESOLUTION
# ============================================================================
# Get repository root (works in both main repo and worktrees)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")

# Version file locations (Updated for MagmaBI structure)
readonly BACKEND_PYPROJECT="$REPO_ROOT/backend/pyproject.toml"
readonly FRONTEND_PACKAGE="$REPO_ROOT/frontend/package.json"
readonly BACKEND_CONFIG="$REPO_ROOT/backend/api/config.py"

# ============================================================================
# VERSION ASSIGNMENT LOCKING (Multi-Session Safety)
# ============================================================================
# Prevents concurrent version assignments from creating duplicates
# Uses mkdir for atomic lock acquisition (POSIX standard)

VERSION_LOCK_FILE="/tmp/magmabi-version-assignment.lock"

# Acquire version assignment lock
# Returns: 0 on success, 1 on failure (timeout)
acquire_version_lock() {
    local max_wait=30
    local waited=0

    while (( waited < max_wait )); do
        # mkdir is atomic - only one process can succeed
        if mkdir "$VERSION_LOCK_FILE" 2>/dev/null; then
            # Write PID for stale lock detection
            echo "$$" > "$VERSION_LOCK_FILE/pid"
            echo "$(date -Iseconds)" > "$VERSION_LOCK_FILE/acquired"
            # Set trap to clean up on exit
            trap 'release_version_lock' EXIT
            return 0
        fi

        # Check if lock holder is still alive
        local holder_pid=$(cat "$VERSION_LOCK_FILE/pid" 2>/dev/null)
        if [[ -n "$holder_pid" ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
            warn "Stale version lock detected (PID $holder_pid no longer running), cleaning up"
            rm -rf "$VERSION_LOCK_FILE"
            continue
        fi

        # Check if lock is very old (> 5 minutes = likely stale)
        local acquired_time=$(cat "$VERSION_LOCK_FILE/acquired" 2>/dev/null)
        if [[ -n "$acquired_time" ]]; then
            local acquired_epoch=$(date -d "$acquired_time" +%s 2>/dev/null || echo 0)
            local now_epoch=$(date +%s)
            local age=$(( now_epoch - acquired_epoch ))
            if (( age > 300 )); then
                warn "Version lock is ${age}s old (likely stale), cleaning up"
                rm -rf "$VERSION_LOCK_FILE"
                continue
            fi
        fi

        log "Version lock held by PID $holder_pid, waiting..."
        sleep 1
        (( waited++ ))
    done

    error "Could not acquire version lock after ${max_wait}s"
    return 1
}

# Release version assignment lock
release_version_lock() {
    rm -rf "$VERSION_LOCK_FILE" 2>/dev/null || true
    # Remove trap
    trap - EXIT
}
# readonly FRONTEND_VERSION_FILE="frontend/lib/version.ts"

# Get current version from package.json (source of truth)
get_current_version() {
    if [[ -f "$FRONTEND_PACKAGE" ]]; then
        jq -r '.version' "$FRONTEND_PACKAGE"
    else
        echo "0.0.0"
    fi
}

# Parse semantic version into components
parse_version() {
    local version="$1"
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
    else
        error "Invalid version format: $version"
        exit 1
    fi
}

# Increment version based on type
increment_version() {
    local current_version="$1"
    local increment_type="$2"
    
    read -r major minor patch <<< $(parse_version "$current_version")
    
    case "$increment_type" in
        patch)
            patch=$((patch + 1))
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            error "Invalid increment type: $increment_type"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Auto-detect version increment type
auto_detect_increment() {
    local branch_type="$1"
    
    case "$branch_type" in
        hotfix)
            echo "patch"
            ;;
        feature)
            echo "minor"
            ;;
        release)
            # Check if there are breaking changes
            if git log --oneline develop..HEAD 2>/dev/null | grep -q "BREAKING\|!:"; then
                echo "major"
            else
                echo "minor"
            fi
            ;;
        *)
            echo "patch"
            ;;
    esac
}

# ============================================================================
# VERSION ASSIGNMENT - CALLED AT FINISH TIME
# ============================================================================
# Versions are assigned when features/hotfixes finish (not at start)
# This eliminates race conditions and merge conflicts
# Sequential numbering in actual release history (no gaps from abandoned branches)

# Get next sequential version (legacy function, kept for compatibility)
get_next_sequential_version() {
    local increment_type="$1"
    local current_version=$(get_current_version)
    
    # Start with the natural next version
    local next_version=$(increment_version "$current_version" "$increment_type")
    
    # Check if this version might conflict by looking at recent remote branches
    # This is a best-effort check, not foolproof
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        # Fetch to get latest remote state (fail silently if offline)
        git fetch origin 2>/dev/null || true
        
        # Look for any recent branches that might have this version
        local potential_conflict=false
        case "$increment_type" in
            minor)
                # Check recent feature branches
                if git branch -r 2>/dev/null | grep -q "origin/feature/" && \
                   git log --all --oneline --since="24 hours ago" 2>/dev/null | grep -q "chore.*version.*$next_version"; then
                    potential_conflict=true
                fi
                ;;
            patch)
                # Check recent hotfix branches  
                if git branch -r 2>/dev/null | grep -q "origin/hotfix/" && \
                   git log --all --oneline --since="24 hours ago" 2>/dev/null | grep -q "chore.*version.*$next_version"; then
                    potential_conflict=true
                fi
                ;;
        esac
        
        # If potential conflict detected, increment once more
        if [[ "$potential_conflict" == "true" ]]; then
            log "Potential version conflict detected for $next_version, using next available"
            next_version=$(increment_version "$next_version" "$increment_type")
        fi
    fi
    
    echo "$next_version"
}

# Check if a version already exists in recent git history
# Args: $1 = version to check, $2 = branch to search
# Returns: 0 if version exists (collision), 1 if not found (safe to use)
version_exists_in_recent_history() {
    local version="$1"
    local branch="$2"

    # Method 1: Check if version is CURRENTLY set on target branch
    # This is the most reliable check - avoids false positives from merge commits
    local target_branch_version=$(git show "origin/$branch:frontend/package.json" 2>/dev/null | jq -r '.version' 2>/dev/null)
    if [[ "$target_branch_version" == "$version" ]]; then
        return 0  # Version already on target branch
    fi

    # Method 2: Check for explicit version assignment commits only
    # Pattern: "chore: assign version X.Y.Z" or "chore(version): X.Y.Z"
    # This avoids false positives from merge commits that mention versions
    if git log "origin/$branch" --oneline -50 --grep="^chore.*version.*$version" 2>/dev/null | grep -q .; then
        return 0  # Collision detected
    fi

    # Method 3: Check if any tags exist with this version
    if git tag -l "v$version" "$version" 2>/dev/null | grep -q .; then
        return 0  # Collision detected
    fi

    return 1  # No collision
}

# Assign version based on target branch's current version
# Called at finish time to avoid race conditions and merge conflicts
# Enhanced with locking and collision detection for multi-session safety
assign_version() {
    local branch_type="$1"
    local forced_increment="$2"  # Optional: "major", "minor", or "patch"
    local branch_name="$(git branch --show-current)"
    local max_retries=3
    local retry=0

    log "Assigning version for $branch_name..."

    # Acquire version lock to prevent concurrent assignments
    acquire_version_lock || {
        error "Could not acquire version lock - another session may be assigning version"
        return 1
    }

    while (( retry < max_retries )); do
        # Fresh fetch to get latest remote state
        git fetch origin 2>/dev/null || true

        # Get next version based on the target branch's current state
        local increment_type
        if [[ -n "$forced_increment" ]]; then
            increment_type="$forced_increment"
            log "Using forced increment type: $increment_type"
        else
            increment_type=$(auto_detect_increment "$branch_type")
            log "Auto-detected increment type: $increment_type"
        fi

        # For features/hotfixes finishing into develop/main, check what the target branch version is
        local base_branch
        case "$branch_type" in
            hotfix)
                base_branch="main"
                ;;
            feature)
                base_branch="develop"
                ;;
            *)
                base_branch="develop"
                ;;
        esac

        # Get version from target branch (from remote to ensure freshness)
        local target_version=$(git show "origin/$base_branch:frontend/package.json" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "0.0.0")
        log "Current $base_branch version: $target_version"

        # Skip-if-already-set: Check if current branch already has a higher version
        # This handles cases where version was set during merge conflict resolution
        local current_branch_version=$(get_current_version)
        if [[ "$current_branch_version" != "$target_version" ]]; then
            # Compare versions - if current > target, version was already bumped
            local current_parts=(${current_branch_version//./ })
            local target_parts=(${target_version//./ })
            local already_bumped=false

            if (( ${current_parts[0]:-0} > ${target_parts[0]:-0} )); then
                already_bumped=true
            elif (( ${current_parts[0]:-0} == ${target_parts[0]:-0} )); then
                if (( ${current_parts[1]:-0} > ${target_parts[1]:-0} )); then
                    already_bumped=true
                elif (( ${current_parts[1]:-0} == ${target_parts[1]:-0} )); then
                    if (( ${current_parts[2]:-0} > ${target_parts[2]:-0} )); then
                        already_bumped=true
                    fi
                fi
            fi

            if [[ "$already_bumped" == "true" ]]; then
                log "Version already bumped on this branch: $current_branch_version (target: $target_version)"
                log "Skipping version assignment"
                release_version_lock
                echo "$current_branch_version"
                return 0
            fi
        fi

        # Calculate next version
        local next_version=$(increment_version "$target_version" "$increment_type")
        log "Candidate version: $next_version"

        # CHECK FOR COLLISION: Has this version been used recently?
        if version_exists_in_recent_history "$next_version" "$base_branch"; then
            warn "Version $next_version already assigned in recent history"
            log "Trying next version..."
            # Increment again to get next available
            next_version=$(increment_version "$next_version" "$increment_type")
            ((retry++))
            continue
        fi

        log "Version $next_version is available"

        # Apply version to files
        update_all_versions "$next_version"

        # Release lock before returning
        release_version_lock

        success "Version $next_version assigned!"
        echo "$next_version"
        return 0
    done

    # Release lock on failure
    release_version_lock

    error "Could not assign unique version after $max_retries attempts"
    return 1
}

# ============================================================================
# EXISTING VERSION UPDATE FUNCTIONS (UNCHANGED)
# ============================================================================

# Update frontend package.json
update_frontend_version() {
    local new_version="$1"
    
    if [[ -f "$FRONTEND_PACKAGE" ]]; then
        log "Updating frontend version to $new_version"
        local temp_file=$(mktemp)
        jq --arg version "$new_version" '.version = $version' "$FRONTEND_PACKAGE" > "$temp_file"
        mv "$temp_file" "$FRONTEND_PACKAGE"
        success "Updated $FRONTEND_PACKAGE"
    else
        warn "Frontend package.json not found: $FRONTEND_PACKAGE"
    fi
}

# Update backend pyproject.toml
update_backend_version() {
    local new_version="$1"
    
    if [[ -f "$BACKEND_PYPROJECT" ]]; then
        log "Updating backend version to $new_version"
        sed -i.bak "s/^version = \".*\"/version = \"$new_version\"/" "$BACKEND_PYPROJECT"
        rm -f "${BACKEND_PYPROJECT}.bak"
        success "Updated $BACKEND_PYPROJECT"
    else
        warn "Backend pyproject.toml not found: $BACKEND_PYPROJECT"
    fi
}

# Update backend config.py
update_backend_config() {
    local new_version="$1"
    
    if [[ -f "$BACKEND_CONFIG" ]]; then
        log "Updating backend config version to $new_version"
        sed -i.bak "s/VERSION = \".*\"/VERSION = \"$new_version\"/" "$BACKEND_CONFIG"
        rm -f "${BACKEND_CONFIG}.bak"
        success "Updated $BACKEND_CONFIG"
    else
        warn "Backend config not found: $BACKEND_CONFIG"
    fi
}

# # Create/update frontend version file for Next.js App Router
# update_frontend_version_file() {
#     local new_version="$1"
    
#     # Create lib directory if it doesn't exist
#     mkdir -p "$(dirname "$FRONTEND_VERSION_FILE")"
    
#     log "Creating/updating frontend version file"
    
#     cat > "$FRONTEND_VERSION_FILE" << EOF
# // Auto-generated version file - DO NOT EDIT MANUALLY
# // Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

# export const VERSION = '$new_version';

# export const BUILD_INFO = {
#   version: '$new_version',
#   buildDate: '$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
#   gitCommit: '$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")',
#   gitBranch: '$(git branch --show-current 2>/dev/null || echo "unknown")',
#   environment: process.env.NODE_ENV || 'development',
# } as const;

# // React hook for accessing version info
# export function useVersion() {
#   return BUILD_INFO;
# }

# // API route helper
# export function getVersionInfo() {
#   return BUILD_INFO;
# }

# // Named export instead of anonymous default
# const versionModule = {
#   VERSION,
#   BUILD_INFO,
#   getVersionInfo,
#   useVersion,
# };

# export default versionModule;
# EOF
    
#     success "Updated $FRONTEND_VERSION_FILE"
# }

# Update Docker Compose labels
update_docker_labels() {
    local new_version="$1"
    
    log "Updating Docker Compose version labels"
    
    for compose_file in docker/docker-compose.*.yml; do
        if [[ -f "$compose_file" ]]; then
            log "Updating $compose_file"
            sed -i.bak "s/version: \".*\"/version: \"$new_version\"/" "$compose_file" 2>/dev/null || true
            sed -i.bak "s/app.version=.*/app.version=$new_version/" "$compose_file" 2>/dev/null || true
            rm -f "${compose_file}.bak" 2>/dev/null || true
        fi
    done
    
    success "Updated Docker Compose files"
}

# Update all version files
update_all_versions() {
    local new_version="$1"
    
    log "Updating all version files to $new_version"
    
    update_frontend_version "$new_version"
    update_backend_version "$new_version"
    update_backend_config "$new_version"
    # update_frontend_version_file "$new_version"
    update_docker_labels "$new_version"
    
    success "All version files updated to $new_version"
}

# Check version consistency
check_version_consistency() {
    log "Checking version consistency across files"
    
    local versions=()
    local files=()
    
    # Get version from each file
    if [[ -f "$FRONTEND_PACKAGE" ]]; then
        local frontend_version=$(jq -r '.version' "$FRONTEND_PACKAGE")
        versions+=("$frontend_version")
        files+=("frontend/package.json")
    fi
    
    if [[ -f "$BACKEND_PYPROJECT" ]]; then
        local backend_version=$(grep '^version = ' "$BACKEND_PYPROJECT" | sed 's/version = "\(.*\)"/\1/')
        versions+=("$backend_version")
        files+=("backend/pyproject.toml")
    fi
    
    if [[ -f "$BACKEND_CONFIG" ]]; then
        local config_version=$(grep 'VERSION = ' "$BACKEND_CONFIG" | sed 's/VERSION = "\(.*\)"/\1/')
        versions+=("$config_version")
        files+=("backend/api/config.py")
    fi
    
    # Check if all versions match
    local first_version="${versions[0]}"
    local all_consistent=true
    
    for i in "${!versions[@]}"; do
        if [[ "${versions[$i]}" != "$first_version" ]]; then
            all_consistent=false
            warn "Version mismatch: ${files[$i]} = ${versions[$i]}"
        else
            success "✓ ${files[$i]} = ${versions[$i]}"
        fi
    done
    
    if [[ "$all_consistent" == "true" ]]; then
        success "All versions are consistent: $first_version"
        echo "$first_version"
    else
        error "Version inconsistency detected!"
        return 1
    fi
}

# ============================================================================
# MAIN FUNCTION WITH SEQUENTIAL ASSIGNMENT
# ============================================================================

main() {
    local command="$1"
    local version_or_type="$2"
    
    case "$command" in
        bump)
            local increment_type="$version_or_type"
            local current_version=$(get_current_version)
            local new_version=$(increment_version "$current_version" "$increment_type")
            
            log "Bumping version: $current_version → $new_version ($increment_type)"
            update_all_versions "$new_version"
            echo "$new_version"
            ;;
            
        set)
            local new_version="$version_or_type"
            log "Setting version to: $new_version"
            update_all_versions "$new_version"
            echo "$new_version"
            ;;
            
        auto)
            local branch_type="$version_or_type"
            local current_version=$(get_current_version)
            local increment_type=$(auto_detect_increment "$branch_type")
            local new_version=$(increment_version "$current_version" "$increment_type")
            
            log "Auto-bumping version for $branch_type: $current_version → $new_version ($increment_type)"
            update_all_versions "$new_version"
            echo "$new_version"
            ;;
            
        # Assign version at finish time (no race conditions)
        assign)
            local branch_type="$version_or_type"
            assign_version "$branch_type"
            ;;
            
        current)
            get_current_version
            ;;
            
        check)
            check_version_consistency
            ;;
            
        *)
            echo "Usage: $0 {bump|set|auto|assign|current|check} [args...]"
            echo ""
            echo "Commands:"
            echo "  bump [patch|minor|major]  - Increment version"
            echo "  set [version]             - Set specific version"
            echo "  auto [hotfix|feature|release] - Auto-increment based on branch type"
            echo "  assign [hotfix|feature]   - Assign next sequential version (parallel-safe)"
            echo "  current                   - Show current version"
            echo "  check                     - Check version consistency"
            echo ""
            echo "Parallel Development:"
            echo "  $0 assign feature         # Gets next minor: 1.3.0, 1.4.0, 1.5.0..."
            echo "  $0 assign hotfix          # Gets next patch: 1.2.4, 1.2.5, 1.2.6..."
            echo ""
            echo "How sequential assignment works:"
            echo "  - Tries to assign next logical version (1.3.0, 1.4.0, etc.)"
            echo "  - Detects potential conflicts via recent Git history"
            echo "  - Uses commit race to resolve simultaneous assignments"
            echo "  - Acceptable gaps if branches are abandoned (1.3.0 → 1.5.0 is fine)"
            echo ""
            echo "Examples:"
            echo "  Current: 1.2.3"
            echo "  Feature A: assign feature → 1.3.0"
            echo "  Feature B: assign feature → 1.4.0"  
            echo "  Hotfix A:  assign hotfix  → 1.2.4"
            echo "  Feature C: assign feature → 1.5.0"
            echo ""
            echo "If Feature B is abandoned, you get: 1.3.0, 1.5.0 (gap is acceptable)"
            exit 1
            ;;
    esac
}

# ============================================================================
# BUILD HASH TRACKING & METADATA
# ============================================================================

# Generate hash of dependency files
generate_dependency_hash() {
    local env="$1"  # prod, staging, or local
    local hash_string=""

    # Backend dependencies
    [[ -f backend/poetry.lock ]] && hash_string+=$(md5sum backend/poetry.lock | awk '{print $1}')
    [[ -f backend/pyproject.toml ]] && hash_string+=$(md5sum backend/pyproject.toml | awk '{print $1}')

    # Frontend dependencies
    [[ -f frontend/package.json ]] && hash_string+=$(md5sum frontend/package.json | awk '{print $1}')
    [[ -f frontend/pnpm-lock.yaml ]] && hash_string+=$(md5sum frontend/pnpm-lock.yaml | awk '{print $1}')

    # Environment files
    [[ -f .env.production ]] && [[ "$env" == "prod" || "$env" == "staging" ]] && \
        hash_string+=$(md5sum .env.production | awk '{print $1}')
    [[ -f .env.local ]] && [[ "$env" == "local" ]] && \
        hash_string+=$(md5sum .env.local | awk '{print $1}')

    # Generate final hash
    echo -n "$hash_string" | md5sum | awk '{print $1}'
}

# Store build metadata
store_build_metadata() {
    local env="$1"
    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local dep_hash=$(generate_dependency_hash "$env")
    local version=$(get_current_version)
    local build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

    mkdir -p .build-cache

    cat > ".build-cache/${env}-last-build.json" << EOF
{
  "environment": "$env",
  "branch": "$branch",
  "version": "$version",
  "commit_hash": "$commit_hash",
  "dependency_hash": "$dep_hash",
  "build_time": "$build_time"
}
EOF

    log "Build metadata stored for $env environment"
}

# Check if dependencies changed since last build
check_dependency_changes() {
    local env="$1"
    local cache_file=".build-cache/${env}-last-build.json"

    if [[ ! -f "$cache_file" ]]; then
        return 0  # First build, dependencies "changed"
    fi

    local last_hash=$(jq -r '.dependency_hash' "$cache_file" 2>/dev/null || echo "")
    local current_hash=$(generate_dependency_hash "$env")

    if [[ "$last_hash" != "$current_hash" ]]; then
        return 0  # Dependencies changed
    else
        return 1  # Dependencies unchanged
    fi
}

# Get last build info
get_last_build_info() {
    local env="$1"
    local cache_file=".build-cache/${env}-last-build.json"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        echo "{}"
    fi
}

# Check if this is a build metadata command
case "$1" in
    store-build)
        store_build_metadata "$2"
        exit 0
        ;;
    check-deps)
        check_dependency_changes "$2"
        exit $?
        ;;
    build-info)
        get_last_build_info "$2"
        exit 0
        ;;
    dep-hash)
        generate_dependency_hash "$2"
        exit 0
        ;;
esac

# Execute main function
main "$@"