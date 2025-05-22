#!/bin/bash
set -euo pipefail

# Basic error handling
trap 'echo "❌ Script failed at line $LINENO"' ERR

# Check prerequisites
check_requirements() {
    command -v poetry >/dev/null || { echo "❌ Poetry not found"; exit 1; }
    command -v python3 >/dev/null || { echo "❌ Python3 not found"; exit 1; }
    [[ -d "/workspace" ]] || { echo "❌ Workspace not found"; exit 1; }
}

# Setup single component with error handling
setup_component() {
    local dir="$1"
    local name=$(basename "$dir")
    
    echo "🔧 Setting up: $name"
    
    cd "$dir" || return 1
    
    # Validate pyproject.toml
    [[ -f "pyproject.toml" ]] || { echo "⚠️  No pyproject.toml in $name"; return 1; }
    grep -q "\[tool.poetry\]" pyproject.toml || { echo "⚠️  Not a Poetry project: $name"; return 1; }
    
    # Configure Poetry
    poetry config virtualenvs.in-project true --local || return 1
    
    # Clean existing broken venv
    if [[ -d ".venv" ]] && ! poetry env info &>/dev/null; then
        echo "🧹 Cleaning corrupted venv for $name"
        rm -rf .venv
    fi
    
    # Install with timeout
    echo "📦 Installing dependencies for $name..."
    timeout 600 poetry install || {
        echo "❌ Failed to install $name"
        return 1
    }
    
    echo "✅ Completed: $name"
    cd - >/dev/null
}

# Main execution
main() {
    echo "🐍 Starting Poetry monorepo setup"
    
    check_requirements
    
    # Find and process components
    local failed=0
    while IFS= read -r -d '' toml_file; do
        component_dir=$(dirname "$toml_file")
        setup_component "$component_dir" || ((failed++))
    done < <(find /workspace -name "pyproject.toml" -type f -print0 2>/dev/null)
    
    if [[ $failed -eq 0 ]]; then
        echo "🎉 All components configured successfully!"
    else
        echo "⚠️  $failed component(s) failed"
        exit 1
    fi
}

main "$@"