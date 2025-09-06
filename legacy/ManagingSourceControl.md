# Comprehensive Development Environment Setup Guide 🚀

## Table of Contents

- 1 [Initial Setup 🏗️](#1-initial-setup-️🏗️)
  - 1.1 [Clone the Repository](#11-clone-the-repository)
  - 1.2 [Configure SSH Access](#12-configure-ssh-access)
  - 1.3 [Set up DOCKER_HOST Environment Variable](#13-set-up-docker_host-environment-variable)
  - 1.4 [Install Required Tools](#14-install-required-tools)
- 2 [Project Structure 📁](#2-project-structure-📁)
- 3 [Git Configuration 🔧](#3-git-configuration-🔧)
  - 3.1 [.gitignore](#31-gitignore)
  - 3.2 [Git Workflow](#32-git-workflow)
- 4 [Docker Configuration 🐳](#4-docker-configuration-🐳)
  - 4.1 [.dockerignore](#41-dockerignore)
  - 4.2 [Dockerfile Best Practices](#42-dockerfile-best-practices)
- 5 [Development Workflow ⚙️](#5-development-workflow-️⚙️)
  - 5.1 [Starting Development Environment](#51-starting-development-environment)
  - 5.2 [Making Changes](#52-making-changes)
  - 5.3 [Testing Changes](#53-testing-changes)
- 6 [Production Deployment 🚀](#6-production-deployment-🚀)
  - 6.1 [Deploying to Production](#61-deploying-to-production)
- 7 [Managing Services 🎛️](#7-managing-services-️🎛️)
  - 7.1 [Starting Services](#71-starting-services)
  - 7.2 [Stopping Services](#72-stopping-services)
  - 7.3 [Restarting Services](#73-restarting-services)
  - 7.4 [Viewing Logs](#74-viewing-logs)
- 8 [Handling Dependencies 📦](#8-handling-dependencies-📦)
  - 8.1 [Updating Backend Dependencies](#81-updating-backend-dependencies)
  - 8.2 [Updating Frontend Dependencies](#82-updating-frontend-dependencies)
- 9 [Bug Fixing in Production 🐛](#9-bug-fixing-in-production-🐛)
- 10 [Best Practices 👍](#10-best-practices-👍)
- 11 [Environment Variables Configuration 🔐](#11-environment-variables-configuration-)
  - 11.1 [Sample .env Files](#111-sample-env-files)
    - [.env.dev](#envdev)
    - [.env.prod](#envprod)
  - 11.2 [Using Environment Variables](#112-using-environment-variables)
  - 11.3 [Loading Environment Variables](#113-loading-environment-variables)
  - 11.4 [Best Practices for Environment Variables](#114-best-practices-for-environment-variables)
- 12 [Appendix: Configuration Files 📄](#12-appendix-configuration-files-📄)
  - 12.1 [.gitignore](#121-gitignore)
  - 12.2 [.dockerignore](#122-dockerignore)
- 13 [Appendix: Script Documentation 📜](#13-appendix-script-documentation-📜)
  - 13.1 [build_frontend.sh](#131-build_frontendsh)
  - 13.2 [build_backend.sh](#132-build_backendsh)
  - 13.3 [build_all.sh](#133-build_allsh)
  - 13.4 [deploy.sh](#134-deploysh)
  - 13.5 [manage.sh](#135-managesh)
  - 13.6 [update_dependencies.sh](#136-update_dependenciessh)
- 14 [Conclusion 🎓](#14-conclusion-🎓)

## 1. Initial Setup 🏗️

### 1.1 Clone the Repository
1. Open VS Code
2. Press Ctrl+Shift+P to open the Command Palette
3. Type "Git: Clone" and select it
4. Enter your repository URL and choose a local folder

This process creates a local copy of your remote repository, allowing you to work on the code on your machine.

### 1.2 Configure SSH Access
1. Generate SSH keys on your local machine (if not already done):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```
2. Copy the public key:
   ```bash
   cat ~/.ssh/id_rsa.pub
   ```
3. Add this public key to the authorized_keys file on your remote server:
   ```bash
   ssh user@your-server
   echo "your-public-key-here" >> ~/.ssh/authorized_keys
   ```

This setup allows secure, password-less communication between your local machine and the remote server.

### 1.3 Set up DOCKER_HOST Environment Variable
1. Open your terminal
2. Run: 
   ```bash
   export DOCKER_HOST=ssh://username@your-server-ip
   ```
3. Add this line to your ~/.bashrc file for persistence:
   ```bash
   echo 'export DOCKER_HOST=ssh://username@your-server-ip' >> ~/.bashrc
   ```

This configuration allows your local Docker commands to interact with the Docker daemon on your remote server.

### 1.4 Install Required Tools
- Docker: Follow the official Docker installation guide for your OS
- Node.js and npm: Use the official Node.js installer
- Python 3.x: Download from python.org or use your OS package manager
- VS Code extensions:
  - Docker
  - Python
  - ESLint
  - Prettier

Install these through the VS Code Extensions marketplace.

## 2. Project Structure 📁

Ensure your project follows this structure:

```
project_root/
├── frontend/
│   ├── Dockerfile
│   ├── Dockerfile.prod
│   ├── next.config.js
│   └── package.json
├── backend/
│   ├── Dockerfile
│   ├── Dockerfile.prod
│   └── requirements.txt
├── docker-compose.dev.yml
├── docker-compose.prod.yml
├── .env.dev
├── .env.prod
├── build_frontend.sh
├── build_backend.sh
├── build_all.sh
├── deploy.sh
├── manage.sh
└── update_dependencies.sh
```

## 3. Git Configuration 🔧

### 3.1 .gitignore
Create a .gitignore file in your project root. See the Appendix for the content.

### 3.2 Git Workflow
1. Create feature branches for new work:
   ```bash
   git checkout -b feature/new-feature-name
   ```
   This creates a new branch for your feature, allowing you to work without affecting the main codebase.

2. Commit changes regularly:
   ```bash
   git add .
   git commit -m "Descriptive commit message"
   ```
   This stages your changes and creates a commit with a message describing what you've done.

3. Push changes to remote repository:
   ```bash
   git push origin feature/new-feature-name
   ```
   This uploads your local commits to the remote repository, making them available to others.

4. Create pull requests for code review:
   Do this through your Git hosting service (e.g., GitHub, GitLab). It allows team members to review your changes before they're merged.

5. Merge approved changes into the main branch:
   After approval, merge your feature branch into the main branch:
   ```bash
   git checkout main
   git merge feature/new-feature-name
   git push origin main
   ```
   This incorporates your changes into the main codebase.

## 4. Docker Configuration 🐳

### 4.1 .dockerignore
Create a .dockerignore file in each directory containing a Dockerfile. See the Appendix for the content.

### 4.2 Dockerfile Best Practices
- Use official base images
- Minimize the number of layers
- Use multi-stage builds for production images
- Don't run containers as root

## 5. Development Workflow ⚙️

### 5.1 Starting Development Environment
```bash
./deploy.sh dev
```
This script builds and starts all your services in the development environment.

### 5.2 Making Changes
1. Create a new feature branch in VS Code:
   Click on the branch name in the bottom-left corner > Create new branch > Enter branch name

2. Make code changes

3. Test changes locally:
   ```bash
   ./manage.sh restart dev
   ```

4. Commit changes using VS Code's Source Control panel:
   - Stage changes (+ button)
   - Enter commit message
   - Click checkmark to commit

5. Push changes to remote repository:
   In the Source Control panel, click "..." > Push

### 5.3 Testing Changes
```bash
./manage.sh restart dev
```
This restarts your services with the latest code changes.

## 6. Production Deployment 🚀

### 6.1 Deploying to Production
1. Merge changes into the main branch:
   In VS Code, switch to the main branch > Command Palette > "Git: Merge Branch" > Select your feature branch

2. Run:
   ```bash
   ./deploy.sh prod
   ```
   This builds production Docker images and deploys them to your production environment.

## 7. Managing Services 🎛️

### 7.1 Starting Services
```bash
./manage.sh start <dev|prod> [service_name]
```
Starts all services or a specific service in the chosen environment.

### 7.2 Stopping Services
```bash
./manage.sh stop <dev|prod> [service_name]
```
Stops all services or a specific service in the chosen environment.

### 7.3 Restarting Services
```bash
./manage.sh restart <dev|prod> [service_name]
```
Restarts all services or a specific service in the chosen environment.

### 7.4 Viewing Logs
```bash
./manage.sh logs <dev|prod> [service_name]
```
Displays logs for all services or a specific service in the chosen environment.

## 8. Handling Dependencies 📦

### 8.1 Updating Backend Dependencies
```bash
./update_dependencies.sh <dev|prod> backend
```
Updates Python dependencies and restarts the backend service.

### 8.2 Updating Frontend Dependencies
```bash
./update_dependencies.sh <dev|prod> frontend
```
Updates Node.js dependencies and restarts the frontend service.

## 9. Bug Fixing in Production 🐛

1. Create a hotfix branch:
   ```bash
   git checkout -b hotfix/bug-description
   ```

2. Make necessary changes

3. Test changes thoroughly:
   ```bash
   ./manage.sh restart dev
   ```

4. Deploy hotfix to production:
   ```bash
   ./deploy.sh prod
   ```

5. Merge hotfix into main and development branches:
   ```bash
   git checkout main
   git merge hotfix/bug-description
   git push origin main

   git checkout develop
   git merge hotfix/bug-description
   git push origin develop
   ```

## 10. Best Practices 👍

1. Always pull latest changes before starting work:
   ```bash
   git pull origin main
   ```

2. Regularly push your changes to the remote repository:
   ```bash
   git push origin your-branch-name
   ```

3. Use meaningful branch names and commit messages
4. Always test thoroughly in the development environment before deploying to production
5. Keep sensitive information out of your codebase (use environment variables)
6. Regularly update dependencies and check for security vulnerabilities

## 11. Environment Variables Configuration 🔐

Environment variables are crucial for maintaining secure and flexible configurations across different environments. We use .env files to manage these variables.

### 11.1 Sample .env Files

#### .env.dev
```
NODE_ENV=development
PORT=3000
API_URL=http://localhost:8000
DEBUG=true

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp_dev
DB_USER=devuser
DB_PASSWORD=devpassword

# Redis
REDIS_URL=redis://localhost:6379

# API Keys (use dummy values for development)
STRIPE_API_KEY=sk_test_1234567890
```

#### .env.prod
```
NODE_ENV=production
PORT=80
API_URL=https://api.myapp.com
DEBUG=false

# Database
DB_HOST=db.myapp.com
DB_PORT=5432
DB_NAME=myapp_prod
DB_USER=produser
DB_PASSWORD=prodpassword

# Redis
REDIS_URL=redis://redis.myapp.com:6379

# API Keys (use real values for production)
STRIPE_API_KEY=sk_live_1234567890
```

### 11.2 Using Environment Variables

1. In your application code:

   For Node.js (frontend):
   ```javascript
   const apiUrl = process.env.API_URL;
   ```

   For Python (backend):
   ```python
   import os
   api_url = os.getenv('API_URL')
   ```

2. In Docker Compose files:

   ```yaml
   services:
     backend:
       environment:
         - DB_HOST=${DB_HOST}
         - DB_PORT=${DB_PORT}
         - DB_NAME=${DB_NAME}
         - DB_USER=${DB_USER}
         - DB_PASSWORD=${DB_PASSWORD}
   ```

3. In Dockerfiles:

   ```dockerfile
   ARG NODE_ENV
   ENV NODE_ENV=${NODE_ENV}
   ```

### 11.3 Loading Environment Variables

1. For local development:
   - Use a package like `dotenv` to load variables from .env files.

2. For Docker:
   - Use the `env_file` directive in docker-compose:
     ```yaml
     services:
       backend:
         env_file:
           - .env.dev
     ```

3. For production:
   - Set environment variables directly on the server or use a secret management service.

### 11.4 Best Practices for Environment Variables

1. Never commit .env files to version control. Add them to .gitignore.
2. Use different .env files for different environments (dev, staging, prod).
3. Provide a .env.example file in version control as a template.
4. Rotate secrets regularly and never use production secrets in development.

## 12. Appendix: Configuration Files 📄

### 12.1 .gitignore
```gitignore
# Operating System Files
.DS_Store    # macOS folder attributes
Thumbs.db    # Windows thumbnail cache files

# Editor and IDE Files
.vscode/     # Visual Studio Code settings
.idea/       # JetBrains IDE settings
*.sublime-project    # Sublime Text project files
*.sublime-workspace  # Sublime Text workspace files
.vs/        # Visual Studio settings

# Python
__pycache__/   # Compiled Python files
*.py[cod]      # Python compiled files
*$py.class     # Python compiled files
*.so           # C extensions
.Python         # Python virtual environment indicator
*.egg-info/     # Python egg metadata
.installed.cfg  # Python distribution metadata
*.egg           # Python eggs
MANIFEST        # Python package manifest

# Virtual Environments
.env*           # Environment variable files
*.env           # Environment variable files
.venv           # Virtual environment directory
env/            # Virtual environment directory
venv/           # Virtual environment directory
ENV/            # Virtual environment directory

# Node.js
node_modules/   # Node.js dependencies
.pnpm-store/    # pnpm store
npm-debug.log*  # npm debug logs
yarn-debug.log* # Yarn debug logs
yarn-error.log* # Yarn error logs

# Next.js
.next/          # Next.js build output
out/            # Next.js static export output

# Logs and Databases
*.log           # Log files
logs/           # Log directory
log/            # Log directory
*.db            # Database files
*.sqlite        # SQLite database files
database.db     # Generic database file

# Project-specific (examples, adjust as needed)
data_provider_caches
*token*.json
data/
lightspeed_genclient/
lightspeed_openapi.yaml
openapi-code*
sevenrooms/
tanda/
uber/
grafana/
grafana_data/
prometheus_data

# Docker
docker-compose.override.yml  # Docker Compose override file

# Additional project specifics
front-to-back project
test.js
```

### 12.2 .dockerignore
```dockerignore
# Version control
.git            # Git repository
.gitignore      # Git ignore file

# Node.js
node_modules    # Node.js dependencies
npm-debug.log   # npm debug logs
yarn-debug.log  # Yarn debug logs
yarn-error.log  # Yarn error logs
.pnpm-store     # pnpm store

# Python
__pycache__     # Compiled Python files
*.pyc           # Python compiled files
*.pyo           # Python optimized files
*.pyd           # Python extension modules
.Python         # Python virtual environment indicator
pip-log.txt     # pip log file
.tox/           # Tox automation tool directory
.coverage       # Coverage.py statistics
.coverage.*     # Coverage.py data files
.cache          # Cache directory
nosetests.xml   # Nose test output
coverage.xml    # Coverage report
*.cover         # Coverage data
.hypothesis/    # Hypothesis testing framework

# Virtual environments
.env            # Environment variables file
.venv           # Virtual environment directory
env/            # Virtual environment directory
venv/           # Virtual environment directory
ENV/            # Virtual environment directory

# IDEs and editors
.vscode         # Visual Studio Code settings
.idea           # JetBrains IDE settings
*.swp           # Vim swap files
*.swo           # Vim swap files
*~              # Temporary files

# OS generated
.DS_Store       # macOS folder attributes
Thumbs.db       # Windows thumbnail cache

# Project specific (examples, adjust as needed)
data_provider_caches
*token*.json
data/
lightspeed_genclient/
lightspeed_openapi.yaml
openapi-code*
sevenrooms/
tanda/
uber/
grafana/
grafana_data/
prometheus_data

# Build artifacts
dist            # Distribution directory
build           # Build directory
*.egg-info      # Python egg metadata

# Docker
docker-compose.yml       # Docker Compose file
docker-compose.override.yml  # Docker Compose override file
Dockerfile               # Dockerfile
.dockerignore            # Docker ignore file

# Logs
logs            # Log directory
*.log           # Log files

# Test and documentation
tests/          # Test directory
docs/           # Documentation directory
*.md            # Markdown files

# Additional project specifics
front-to-back project
test.js
```

## 13. Appendix: Script Documentation 📜

### 13.1 build_frontend.sh
```bash
#!/bin/bash

# This script builds the frontend Docker image for either development or production

# Set environment variable
ENV=$1
# Set SSH host from DOCKER_HOST environment variable
SSH_HOST=$DOCKER_HOST
# Set workspace directory
WORKSPACE=/share/DevelopmentProjects/MagmaBI-Full

# Check if the environment argument is provided and valid
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "Usage: ./build_frontend.sh <dev|prod>"
    exit 1
fi

# Set the appropriate Dockerfile and image tag based on the environment
if [ "$ENV" == "dev" ]; then
    DOCKERFILE="Dockerfile"
    IMAGE_TAG="magmabi-full_frontend:latest"
else
    DOCKERFILE="Dockerfile.prod"
    IMAGE_TAG="magmabi-full_frontend-prod:latest"
fi

# Construct the Docker build command
EXEC_CMD_BUILD="cd $WORKSPACE/frontend && docker build --pull --rm -f $DOCKERFILE -t $IMAGE_TAG ."

# Execute the build command on the remote server
echo "Building frontend image for $ENV environment"
ssh $SSH_HOST -t "/bin/bash -c '$EXEC_CMD_BUILD'"
```

### 13.2 build_backend.sh
```bash
#!/bin/bash

# This script builds the backend Docker image for either development or production

# Set environment variable
ENV=$1
# Set SSH host from DOCKER_HOST environment variable
SSH_HOST=$DOCKER_HOST
# Set workspace directory
WORKSPACE=/share/DevelopmentProjects/MagmaBI-Full

# Check if the environment argument is provided and valid
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "Usage: ./build_backend.sh <dev|prod>"
    exit 1
fi

# Set the appropriate Dockerfile and image tag based on the environment
if [ "$ENV" == "dev" ]; then
    DOCKERFILE="Dockerfile"
    IMAGE_TAG="magmabi-full_backend:latest"
else
    DOCKERFILE="Dockerfile.prod"
    IMAGE_TAG="magmabi-full_backend-prod:latest"
fi

# Construct the Docker build command
EXEC_CMD_BUILD="cd $WORKSPACE/backend && docker build --pull --rm -f $DOCKERFILE -t $IMAGE_TAG ."

# Execute the build command on the remote server
echo "Building backend image for $ENV environment"
ssh $SSH_HOST -t "/bin/bash -c '$EXEC_CMD_BUILD'"
```

### 13.3 build_all.sh
```bash
#!/bin/bash

# This script builds both frontend and backend Docker images

# Set environment variable
ENV=$1

# Check if the environment argument is provided and valid
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "Usage: ./build_all.sh <dev|prod>"
    exit 1
fi

echo "Building all images for $ENV environment"
# Call the frontend build script
./build_frontend.sh $ENV
# Call the backend build script
./build_backend.sh $ENV
```

### 13.4 deploy.sh
```bash
#!/bin/bash

# This script deploys the application to either development or production environment

# Set environment variable
ENV=$1
# Set SSH host from DOCKER_HOST environment variable
SSH_HOST=$DOCKER_HOST
# Set workspace directory
WORKSPACE=/share/DevelopmentProjects/MagmaBI-Full

# Check if the environment argument is provided and valid
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "Usage: ./deploy.sh <dev|prod>"
    exit 1
fi

# Build images
./build_all.sh $ENV

# Set the appropriate docker-compose file and .env file based on the environment
COMPOSE_FILE="docker-compose.$ENV.yml"
ENV_FILE=".env.$ENV"

# Construct Docker Compose commands
EXEC_CMD_DOWN="docker-compose -f $WORKSPACE/$COMPOSE_FILE --project-name magmabi-full_$ENV down"
EXEC_CMD_UP="docker-compose -f $WORKSPACE/$COMPOSE_FILE --env-file $WORKSPACE/$ENV_FILE --project-name magmabi-full_$ENV up -d"

# Execute commands on the remote server
echo "Stopping existing services..."
ssh $SSH_HOST "/bin/bash -c '$EXEC_CMD_DOWN'"

echo "Starting services..."
ssh $SSH_HOST "/bin/bash -c '$EXEC_CMD_UP'"

echo "Deployment to $ENV completed."
```

### 13.5 manage.sh
```bash
#!/bin/bash

# This script manages the application services in either development or production environment

# Set action, environment, and services variables
ACTION=$1
ENV=$2
SERVICES=${@:3}
# Set SSH host from DOCKER_HOST environment variable
SSH_HOST=$DOCKER_HOST
# Set workspace directory
WORKSPACE=/share/DevelopmentProjects/MagmaBI-Full

# Check if the action and environment arguments are provided and valid
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "Usage: ./manage.sh <start|stop|restart|logs> <dev|prod> [services...]"
    exit 1
fi

# Set the appropriate docker-compose file and project name
COMPOSE_FILE="docker-compose.$ENV.yml"
PROJECT_NAME="magmabi-full_$ENV"

# Perform the requested action
case $ACTION in
  start)
    ssh $SSH_HOST "docker-compose -f $WORKSPACE/$COMPOSE_FILE --project-name $PROJECT_NAME up -d $SERVICES"
    ;;
  stop)
    ssh $SSH_HOST "docker-compose -f $WORKSPACE/$COMPOSE_FILE --project-name $PROJECT_NAME stop $SERVICES"
    ;;
  restart)
    ssh $SSH_HOST "docker-compose -f $WORKSPACE/$COMPOSE_FILE --project-name $PROJECT_NAME stop $SERVICES"
    ssh $SSH_HOST "docker-compose -f $WORKSPACE/$COMPOSE_FILE --project-name $PROJECT_NAME up -d $SERVICES"
    ;;
  logs)
    ssh $SSH_HOST "docker-compose -f $WORKSPACE/$COMPOSE_FILE --project-name $PROJECT_NAME logs -f $SERVICES"
    ;;
  *)
    echo "Usage: ./manage.sh <start|stop|restart|logs> <dev|prod> [services...]"
    exit 1
    ;;
esac
```

### 13.6 update_dependencies.sh
```bash
#!/bin/bash

# This script updates dependencies for either frontend or backend in development or production

# Set environment and component variables
ENV=$1
COMPONENT=$2

# Check if the environment and component arguments are provided and valid
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
    echo "Usage: ./update_dependencies.sh <dev|prod> <frontend|backend>"
    exit 1
fi

# Update dependencies based on the component
if [ "$COMPONENT" == "backend" ]; then
    if [ "$ENV" == "dev" ]; then
        # For development, update dependencies inside the container
        docker exec magmabi-full_backend pip install -r requirements.txt
    else
        # For production, rebuild the image
        ./build_backend.sh prod
    fi
    # Restart the backend service
    ./manage.sh restart $ENV backend
elif [ "$COMPONENT" == "frontend" ]; then
    if [ "$ENV" == "dev" ]; then
        # For development, update dependencies inside the container
        docker exec magmabi-full_frontend yarn install
    else
        # For production, rebuild the image
        ./build_frontend.sh prod
    fi
    # Restart the frontend service
    ./manage.sh restart $ENV frontend
else
    echo "Invalid component. Use 'frontend' or 'backend'."
    exit 1
fi
```

## 14. Conclusion 🎓

This comprehensive guide covers all aspects of setting up and managing your development environment, from initial setup to production deployment and maintenance. By following these instructions and best practices, you can ensure a smooth, efficient, and secure development process.

Key takeaways:
1. Use version control (Git) effectively to manage your codebase and collaborate with team members.
2. Leverage Docker for consistent development and production environments.
3. Implement a clear branching strategy for feature development and hotfixes.
4. Use environment variables to manage configuration across different environments securely.
5. Regularly update dependencies and follow security best practices.
6. Automate repetitive tasks using shell scripts for building, deploying, and managing services.

Remember to adapt these guidelines to your specific project needs and team workflows. Regularly review and update your processes to improve efficiency and address any new challenges that arise during development.