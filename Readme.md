# CoDemian Dev Container Framework 🚀

This framework provides a flexible and reusable development environment using Visual Studio Code's Remote - Containers feature. It allows for consistent development environments across multiple projects while enabling project-specific customizations.

## Table of Contents

1. [Directory Structure](#1-directory-structure) 📁
2. [Key Components](#2-key-components) 🔑
3. [How It Works](#3-how-it-works) ⚙️
4. [Setting Up a New Project](#4-setting-up-a-new-project) 🆕
5. [Adding New Components](#5-adding-new-components) ➕
6. [Customizing a Project](#6-customizing-a-project) 🎨
7. [Updating the Shared Configuration](#7-updating-the-shared-configuration) 🔄
8. [Virtual Environments](#8-virtual-environments) 🐍
9. [Best Practices](#9-best-practices) 👍
10. [Troubleshooting](#10-troubleshooting) 🔧
11. [Contributing](#11-contributing) 🤝

## 1. Directory Structure 📁


/share/DevelopmentProjects/
├── .devcontainer/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── devcontainer.json
│   ├── setup-ssh.sh
│   ├── setup-poetry.sh
│   ├── setup-pnpm.sh
│   ├── devcontainerlinks.sh
│   ├── init-project.sh
│   ├── update_dependencies.sh
│   └── README (this file)
└── YourProject/
    └── .devcontainer/
        ├── docker-compose.override.yml
        └── [symlinks to shared .devcontainer files]


## 2. Key Components 🔑

- **Dockerfile**: Defines the base development environment with Python, Node.js, and various tools.
- **docker-compose.yml**: Configures the dev container service and its dependencies.
- **devcontainer.json**: Specifies VS Code settings and extensions for the dev container.
- **setup-ssh.sh**: Sets up SSH keys for the container user.
- **setup-poetry.sh**: Configures Poetry and installs Python dependencies for each component.
- **setup-pnpm.sh**: Sets up pnpm and installs JavaScript dependencies for each component.
- **devcontainerlinks.sh**: Creates symbolic links from the shared .devcontainer to project-specific .devcontainer directories.
- **init-project.sh**: Initializes a new project with the dev container setup.
- **update_dependencies.sh**: Updates dependencies for both Python and JavaScript components.

## 3. How It Works ⚙️

1. The shared .devcontainer folder contains the base configuration files.
2. Each project has its own .devcontainer folder with symlinks to the shared files.
3. Project-specific customizations are made in docker-compose.override.yml within each project's .devcontainer folder.
4. When VS Code opens a project, it uses the project-specific devcontainer.json (symlinked from the shared one), which references both the shared docker-compose.yml and the project-specific docker-compose.override.yml.

## 4. Setting Up a New Project 🆕

1. Run the initialization script:

   /share/DevelopmentProjects/.devcontainer/init-project.sh YourNewProject
   
2. Open the new project folder in VS Code.

3. When prompted, click "Reopen in Container" to build and start the dev container.

### Environment Variables

This setup uses two environment files:
1. `/share/DevelopmentProjects/.devcontainer/dockervariables.env`: Contains shared default settings.
2. `[PROJECT_ROOT]/.env`: Contains project-specific settings and overrides.

When setting up a new project, create a .env file in your project root with the necessary overrides. See the sample .env file in this README for an example.

## 5. Adding New Components ➕

### A. Adding a New Python Component:

1. Create a new directory for your component:

   mkdir /workspace/new_python_component
   

2. Navigate to the new directory:

   cd /workspace/new_python_component
   

3. Initialize a new Poetry project:

   poetry init
   

4. Add your dependencies:

   poetry add package1 package2
   

5. Create a .env file for VS Code:

   echo "PYTHON_VENV=$(poetry env info --path)" > .env
   

6. Update the dev container:
   - Open a terminal in VS Code
   - Run: `/workspace/.devcontainer/setup-poetry.sh`

7. Restart the VS Code window to apply the changes

### B. Adding a New Next.js Frontend Component:

1. Create a new directory for your component:

   mkdir /workspace/new_nextjs_component
   

2. Navigate to the new directory:

   cd /workspace/new_nextjs_component
   

3. Initialize a new Next.js project:

   npx create-next-app@latest .
   

4. When prompted, choose your preferred options

5. Switch to using pnpm:
   - Delete the `package-lock.json` file and `node_modules` directory
   - Run: `pnpm install`

6. Update the dev container:
   - Open a terminal in VS Code
   - Run: `/workspace/.devcontainer/setup-pnpm.sh`

7. Restart the VS Code window to apply the changes

After adding new components, you may need to update your docker-compose.override.yml file to include any necessary volume mounts or environment variables for the new components.

## 6. Customizing a Project 🎨

To customize a project's dev container:

1. Edit the docker-compose.override.yml file in your project's .devcontainer folder.
2. Add project-specific volume mounts, environment variables, or other Docker Compose overrides.

Example docker-compose.override.yml:

yaml
version: '3.8'

services:
  ide:
    volumes:
      - ${PROJECT_ROOT:-/share/DevelopmentProjects/YourProject}/specific_folder:/workspace/specific_folder
    environment:
      - PROJECT_SPECIFIC_VAR=value


## 7. Updating the Shared Configuration 🔄

To update the shared configuration for all projects:

1. Edit the desired file in `/share/DevelopmentProjects/.devcontainer/`.
2. Rebuild the dev containers for all projects to apply the changes.

## 8. Virtual Environments 🐍

This dev container setup creates separate virtual environments for each Python component in your project.

- VS Code automatically uses the correct virtual environment based on your current working directory.

- To activate a virtual environment in the terminal:
  1. Navigate to the component's directory:
  
     cd /workspace/your_component
     
  2. Activate the virtual environment:
  
     source .venv/bin/activate
     

- To deactivate the virtual environment:
  deactivate
  

- To install new dependencies:
  1. Ensure you're in the correct component directory
  2. Use Poetry to add the dependency:
  
     poetry add package_name
     

- To update dependencies:
  1. Ensure you're in the correct component directory
  2. Use Poetry to update:
  
     poetry update
     

Remember, each Python component (directory with a pyproject.toml file) has its own virtual environment.

## 9. Best Practices 👍

1. Keep project-specific configurations in docker-compose.override.yml.
2. Use environment variables for values that might change between projects or environments.
3. Regularly update the shared configuration to ensure all projects benefit from improvements and security updates.

## 10. Troubleshooting 🔧

- If symlinks are not created correctly, run devcontainerlinks.sh manually for the project.
- If dependencies are not installing, check the project's pyproject.toml or package.json files.
- For SSH issues, review the output of setup-ssh.sh in the VS Code terminal.

## 11. Contributing 🤝

To contribute to this dev container framework:

1. Fork the repository containing the .devcontainer folder.
2. Make your changes in a new branch.
3. Test your changes with multiple projects.
4. Submit a pull request with a detailed description of your changes.