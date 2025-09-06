#!/bin/bash
set -euo pipefail  # Exit on any error

# Check prerequisites
command -v pnpm >/dev/null || { echo "❌ pnpm not found"; exit 1; }
command -v node >/dev/null || { echo "❌ Node.js not found"; exit 1; }

setup_js_component() {
    local dir="$1"
    local name=$(basename "$dir")
    
    echo "📦 Setting up: $name"
    cd "$dir" || return 1
    
    # Validate package.json exists and has dependencies
    [[ -f "package.json" ]] || { echo "⚠️ No package.json in $name"; return 1; }
    
    # Check if package.json is valid JSON and has dependencies
    if ! node -e "
        const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
        if (!pkg.dependencies && !pkg.devDependencies) process.exit(1);
    " 2>/dev/null; then
        echo "⚠️ No dependencies in $name, skipping"
        return 0
    fi
    
    # Install with timeout and try frozen-lockfile first
    echo "📥 Installing dependencies for $name..."
    if ! timeout 300 pnpm install --frozen-lockfile 2>/dev/null; then
        echo "🔄 Retrying without frozen lockfile for $name..."
        timeout 300 pnpm install || {
            echo "❌ Install failed: $name"
            return 1
        }
    fi
    
    echo "✅ Completed: $name"
    cd - >/dev/null
}

# Main execution
main() {
    echo "📦 Starting pnpm setup for JavaScript components"
    
    # Find all package.json files (excluding node_modules)
    local failed=0
    local total=0
    
    while IFS= read -r -d '' package_file; do
        component_dir=$(dirname "$package_file")
        
        # Skip node_modules directories
        [[ "$component_dir" == *"/node_modules"* ]] && continue
        
        ((total++))
        setup_js_component "$component_dir" || ((failed++))
    done < <(find /workspace -name "package.json" -type f -print0 2>/dev/null)
    
    if [[ $total -eq 0 ]]; then
        echo "ℹ️ No JavaScript components found"
        exit 0
    elif [[ $failed -eq 0 ]]; then
        echo "🎉 All $total JavaScript components configured successfully!"
    else
        echo "⚠️ $failed out of $total component(s) failed"
        exit 1
    fi
}

main "$@"