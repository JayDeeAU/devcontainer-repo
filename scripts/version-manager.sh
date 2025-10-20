#!/bin/bash
# scripts/version-manager.sh - Sequential versioning with simple conflict resolution
# Predictable increments, acceptable gaps from abandoned branches

set -e

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}ℹ️${NC} $*"; }
success() { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC} $*"; }
error() { echo -e "${RED}❌${NC} $*"; }

# Version file locations (Updated for MagmaBI structure)
readonly BACKEND_PYPROJECT="backend/pyproject.toml"
readonly FRONTEND_PACKAGE="frontend/package.json"
readonly BACKEND_CONFIG="backend/api/config.py"
readonly FRONTEND_VERSION_FILE="frontend/lib/version.ts"

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

# Assign version based on target branch's current version
# Called at finish time to avoid race conditions and merge conflicts
assign_version() {
    local branch_type="$1"
    local branch_name="$(git branch --show-current)"

    log "Assigning version for $branch_name..."

    # Fetch latest develop/main to get current version
    git fetch origin 2>/dev/null || true

    # Get next version based on the target branch's current state
    local increment_type=$(auto_detect_increment "$branch_type")

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

    # Get version from target branch
    local target_version=$(git show "origin/$base_branch:frontend/package.json" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "0.0.0")
    log "Current $base_branch version: $target_version"

    # Calculate next version
    local next_version=$(increment_version "$target_version" "$increment_type")
    log "Next version will be: $next_version"

    # Apply version to files
    update_all_versions "$next_version"

    success "Version $next_version assigned!"
    echo "$next_version"
    return 0
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

# Create/update frontend version file for Next.js App Router
update_frontend_version_file() {
    local new_version="$1"
    
    # Create lib directory if it doesn't exist
    mkdir -p "$(dirname "$FRONTEND_VERSION_FILE")"
    
    log "Creating/updating frontend version file"
    
    cat > "$FRONTEND_VERSION_FILE" << EOF
// Auto-generated version file - DO NOT EDIT MANUALLY
// Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

export const VERSION = '$new_version';

export const BUILD_INFO = {
  version: '$new_version',
  buildDate: '$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
  gitCommit: '$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")',
  gitBranch: '$(git branch --show-current 2>/dev/null || echo "unknown")',
  environment: process.env.NODE_ENV || 'development',
} as const;

// React hook for accessing version info
export function useVersion() {
  return BUILD_INFO;
}

// API route helper
export function getVersionInfo() {
  return BUILD_INFO;
}

// Named export instead of anonymous default
const versionModule = {
  VERSION,
  BUILD_INFO,
  getVersionInfo,
  useVersion,
};

export default versionModule;
EOF
    
    success "Updated $FRONTEND_VERSION_FILE"
}

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
    update_frontend_version_file "$new_version"
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

# Execute main function
main "$@"