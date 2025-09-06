#!/bin/bash

# This script initializes a new project with the dev container setup

# Check if project name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <project_name>"
  exit 1
fi

PROJECT_NAME=$1
PROJECT_DIR="/share/DevelopmentProjects/$PROJECT_NAME"

# Create project directory if it doesn't exist
mkdir -p "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/logsD"
mkdir -p "$PROJECT_DIR/logs"

# Create a basic .env file
cat << EOF > "$PROJECT_DIR/.env"
PROJECT_NAME=$PROJECT_NAME
PROJECT_ROOT=$PROJECT_DIR
EOF

cp .env docker-compose.env

echo "Project $PROJECT_NAME initialized at $PROJECT_DIR"
echo "Dev container links created. You can now open this project in VS Code."