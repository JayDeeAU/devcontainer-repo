# CoDemian Dev Container Framework 🚀

This framework provides a flexible and reusable development environment using Visual Studio Code's Remote - Containers feature. It allows for consistent development environments across multiple projects while enabling project-specific customizations.

## Table of Contents

- [CoDemian Dev Container Framework 🚀](#codemian-dev-container-framework-)
  - [Table of Contents](#table-of-contents)
  - [1. Directory Structure 📁](-#1-directory-structure-📁)
  - [2. Key Components 🔑](-#2-key-components-🔑)
  - [3. How It Works ⚙️](-#3-how-it-works-⚙️)
  - [4. Setting Up a New Project 🆕](-#4-setting-up-a-new-project-🆕)
    - [Environment Variables](-#envirnment-variables)
  - [5. Setting Up DevContainer as a Submodule 🔗](-#5-setting-up-devcontainer-as-a-submodule-🔗)
    - [Cloning a Project with Submodules](#cloning-a-project-with-submodules)
    - [Updating the DevContainer Submodule](#updating-the-devcontainer-submodule)
    - [Troubleshooting Submodule Setup](#troubleshooting-submodule-setup)
  - [6. Adding New Components ➕](-#6-adding-new-components-➕)
    - [A. Adding a New Python Component](#a-adding-a-new-python-component)
    - [B. Adding a New Next.js Frontend Component](#b-adding-a-new-nextjs-frontend-component)
  - [7. Customizing a Project 🎨](-#7-customizing-a-project-🎨)
  - [8. Updating the Shared Configuration 🔄](-#8-updating-the-shared-configuration-🔄)
  - [9. Virtual Environments 🐍](-#9-virtual-environments-🐍)
  - [10. Best Practices 👍](-#10-best-practices-👍)
  - [11. Troubleshooting 🔧](-#11-troubleshooting-🔧)
  - [12. Contributing 🤝](-#12-contributing-🤝)

## 1. Directory Structure 📁

```plaintext
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
        ├── docker-compose-devcontainer.yml (must be created once the devcontainer repo is cloned)
        └── .gitignore
```

## 2. Key Components 🔑

- **Dockerfile**: Defines the base development environment with Python, Node.js, and various tools.
- **docker-compose.yml**: Configures the dev container service and its dependencies.
- **devcontainer.json**: Specifies VS Code settings and extensions for the dev container.
- **setup-ssh.sh**: Sets up SSH keys for the container user.
- **setup-poetry.sh**: Configures Poetry and installs Python dependencies for each component.
- **setup-pnpm.sh**: Sets up `pnpm` and installs JavaScript dependencies for each component.
- **devcontainerlinks.sh**: Legacy script for creating symlinks (now replaced by Git submodule configuration).
- **init-project.sh**: Initializes a new project with the dev container setup.
- **update_dependencies.sh**: Updates dependencies for both Python and JavaScript components.

## 3. How It Works ⚙️

1. The shared `.devcontainer` folder contains the base configuration files and is set up as a Git submodule for easy sharing and versioning.
2. Each project includes a `.devcontainer` folder that references the shared configuration using the submodule approach.
3. Project-specific customizations are made in `docker-compose-devcontainer.yml` in the root of the project directory.
4. When VS Code opens a project, it uses the project-specific `devcontainer.json` (provided by the shared submodule), which references both the shared `docker-compose.yml` and the project-specific `docker-compose-devcontainer.yml` for any overrides.

## 4. Setting Up a New Project 🆕

1. **Run the initialization script**:

   ```sh
   /share/DevelopmentProjects/.devcontainer/init-project.sh YourNewProject
   ```

2. **Open the new project folder** in VS Code.

3. **Reopen in Container**: When prompted, click "Reopen in Container" to build and start the dev container.

### Environment Variables

This setup uses two environment files:

1. **/share/DevelopmentProjects/.devcontainer/dockervariables.env**: Contains shared default settings.
2. **[PROJECT_ROOT]/.env**: Contains project-specific settings and overrides.

When setting up a new project, create a `.env` file in your project root with the necessary overrides. See the sample `.env` file in this README for an example.

## 5. Setting Up DevContainer as a Submodule 🔗

1. **Navigate to your project's root directory**:

   ```sh
   cd /path/to/your/project
   ```

2. **Ensure you're on the branch where you want to add the submodule**:

   ```sh
   git checkout your-branch-name  # usually main
   ```

3. **Add the DevContainer repository as a submodule**:

   ```sh
   git submodule add https://github.com/YourGitHubUsername/devcontainer-repo.git .devcontainer
   ```

4. **Commit the changes**:

   ```sh
   git add .gitmodules .devcontainer
   git commit -m "Add .devcontainer as submodule"
   ```

5. **Update your `.gitignore` file to ignore the contents of the `.devcontainer` directory**:

   ```sh
   echo ".devcontainer/*" >> .gitignore
   echo "!.devcontainer/.gitkeep" >> .gitignore
   git add .gitignore
   git commit -m "Update .gitignore for .devcontainer submodule"
   ```

### Cloning a Project with Submodules

When cloning a project that uses this submodule, use the `--recursive` flag:

```sh
git clone --recursive https://github.com/YourGitHubUsername/your-project.git
```

If you've already cloned the project without the `--recursive` flag, you can initialize and update the submodule with:

```sh
git submodule update --init --recursive
```

### Updating the DevContainer Submodule

1. **Navigate to the `.devcontainer` directory**:

   ```sh
   cd .devcontainer
   ```

2. **Fetch the latest changes and checkout the desired branch (usually `main`)**:

   ```sh
   git fetch origin
   git checkout origin/main
   ```

3. **Go back to your project root and commit the submodule update**:

   ```sh
   cd ..
   git add .devcontainer
   git commit -m "Update DevContainer submodule"
   ```

### Troubleshooting Submodule Setup

If you encounter issues adding the submodule, ensure that:

- You have the correct permissions to access the DevContainer repository.
- The `.devcontainer` directory in your project is empty or doesn't exist before adding the submodule.
- Your Git version is up to date.

For further assistance, contact the DevOps team.

## 6. Adding New Components ➕

### A. Adding a New Python Component

1. **Create a new directory for your component**:

   ```sh
   mkdir /workspace/new_python_component
   ```

2. **Navigate to the new directory**:

   ```sh
   cd /workspace/new_python_component
   ```

3. **Initialize a new Poetry project**:

   ```sh
   poetry init
   ```

4. **Add your dependencies**:

   ```sh
   poetry add package1 package2
   ```

5. **Create a `.env` file for VS Code**:

   ```sh
   echo "PYTHON_VENV=$(poetry env info --path)" > .env
   ```

6. **Update the dev container**:

   ```sh
   /workspace/.devcontainer/setup-poetry.sh
   ```

7. **Restart the VS Code window** to apply the changes.

### B. Adding a New Next.js Frontend Component

1. **Create a new directory for your component**:

   ```sh
   mkdir /workspace/new_nextjs_component
   ```

2. **Navigate to the new directory**:

   ```sh
   cd /workspace/new_nextjs_component
   ```

3. **Initialize a new Next.js project**:

   ```sh
   npx create-next-app@latest .
   ```

4. **Choose your preferred options** when prompted.

5. **Switch to using `pnpm`**:

   - Delete the `package-lock.json` file and `node_modules` directory.

     ```sh
     pnpm install
     ```

6. **Update the dev container**:

   ```sh
   /workspace/.devcontainer/setup-pnpm.sh
   ```

7. **Restart the VS Code window** to apply the changes.

After adding new components, you may need to update your `docker-compose-devcontainer.yml` file to include any necessary volume mounts or environment variables for the new components.

## 7. Customizing a Project 🎨

To customize a project's dev container:

1. Edit the `docker-compose-devcontainer.yml` file in your project's root directory.
2. Add project-specific volume mounts, environment variables, or other Docker Compose overrides.

Example `docker-compose-devcontainer.yml`:

```yaml
version: '3.8'

services:
  ide:
    volumes:
      - ${PROJECT_ROOT:-/share/DevelopmentProjects/YourProject}/specific_folder:/workspace/specific_folder
    environment:
      - PROJECT_SPECIFIC_VAR=value
```

## 8. Updating the Shared Configuration 🔄

To update the shared configuration for all projects:

1. Edit the desired file** in `/share/DevelopmentProjects/.devcontainer/`.
2. Rebuild the dev containers** for all projects to apply the changes.

## 9. Virtual Environments 🐍

This dev container setup creates separate virtual environments for each Python component in your project.

- VS Code automatically uses the correct virtual environment based on your current working directory.

- To activate a virtual environment in the terminal:  

    1. Navigate to the component's directory:

   ```sh
      cd /workspace/your_component
   ```

    1. Activate the virtual environment:

   ```sh
     source .venv/bin/activate
   ```

- To deactivate the virtual environment:

   ```sh
  deactivate
   ```

- To install new dependencies:
  
  1. Ensure you're in the correct component directory.
  2. Use Poetry to add the dependency:

   ```sh
     poetry add package_name
   ```

- To update dependencies:
  
  1. Ensure you're in the correct component directory.
  2. Use Poetry to update:

   ```sh
     poetry update
   ```

Remember, each Python component (directory with a `pyproject.toml` file) has its own virtual environment.

## 10. Best Practices 👍

1. Keep project-specific configurations in `docker-compose-devcontainer.yml`.
2. Use environment variables for values that might change between projects or environments.
3. Regularly update the shared configuration to ensure all projects benefit from improvements and security updates.

## 11. Troubleshooting 🔧

- If the submodule is not properly linked, run `git submodule update --init --recursive`.
- If dependencies are not installing, check the project's `pyproject.toml` or `package.json` files.
- For SSH issues, review the output of `setup-ssh.sh` in the VS Code terminal.

## 12. Contributing 🤝

To contribute to this dev container framework:

1. **Fork the repository** containing the `.devcontainer` folder.
2. **Make your changes in a new branch**.
3. **Test your changes** with multiple projects.
4. **Submit a pull request** with a detailed description of your changes.
