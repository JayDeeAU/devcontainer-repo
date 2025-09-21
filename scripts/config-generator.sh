#!/bin/bash
# Configuration Generator - Creates .container-config.json from templates

TEMPLATES_DIR="$(dirname "$0")/../templates"

show_usage() {
    echo "Usage: $0 [template-name]"
    echo ""
    echo "Available templates:"
    echo "  default     - Basic frontend + backend setup"
    echo "  fullstack   - Frontend + backend + database + cache"
    echo "  simple      - Single application"
    echo "  microservices - Multiple backend services"
    echo ""
    echo "Project name will be auto-detected from current directory name"
    echo ""
    echo "Examples:"
    echo "  $0 default      # Basic web app"
    echo "  $0 fullstack    # Complex app with database"
    echo "  $0 simple       # Single service"
}

generate_config() {
    local template="$1"
    
    # Auto-detect project name from directory
    local project_name=$(basename "$(pwd)")
    local template_file="$TEMPLATES_DIR/${template}-config.json"
    
    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template not found: $template_file"
        echo ""
        show_usage
        exit 1
    fi
    
    if [[ -f ".container-config.json" ]]; then
        echo "Warning: .container-config.json already exists"
        read -p "Overwrite? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi
    fi
    
    # Replace template variables
    sed "s/{{PROJECT_NAME}}/$project_name/g" "$template_file" > .container-config.json
    
    echo "Created .container-config.json from $template template"
    echo "Project: $project_name"
    echo "Container prefix: ${project_name}_"
    echo ""
    echo "Next steps:"
    echo "1. Review and customize .container-config.json"
    echo "2. Ensure your docker-compose files match the configuration"
    echo "3. Test with: universal-container-manager status"
}

# Main execution
template="${1:-default}"

if [[ "$template" == "help" || "$template" == "--help" || "$template" == "-h" ]]; then
    show_usage
    exit 0
fi

generate_config "$template"