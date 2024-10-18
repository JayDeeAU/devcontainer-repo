#!/bin/bash

# This script creates symbolic links for the .devcontainer directory

###################################################################
### NO LONGER USED SINCE DEV CONTAINER IS NOW MANAGED USING GIT ###
###################################################################

# Check if target directory is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <target_directory>"
  exit 1
fi

# Assign variables
SOURCE_DIR="/share/DevelopmentProjects/.devcontainer"  # Fixed source directory path
TARGET_DIR="$1"
TARGET_SUBDIR="$TARGET_DIR/.devcontainer"

# Create the .devcontainer subdirectory in the target directory if it doesn't exist
if [ ! -d "$TARGET_SUBDIR" ]; then
  mkdir -p "$TARGET_SUBDIR"
  echo "Created directory: $TARGET_SUBDIR"
else
  echo "Directory already exists: $TARGET_SUBDIR"
fi

# Create symbolic links to all contents of the source directory, including dot files
shopt -s dotglob  # Enable dotglob to include dot files
for item in "$SOURCE_DIR"/*; do
  item_name="$(basename "$item")"

  # Skip the . and .. entries, and docker-compose.override.yml
  if [ "$item_name" = "." ] || [ "$item_name" = ".." ] || [ "$item_name" = "docker-compose.override.yml" ]; then
    continue
  fi
  
  target_link="$TARGET_SUBDIR/$item_name"
  
  if [ -e "$target_link" ]; then
    echo "Link or file already exists: $target_link"
  else
    ln "$item" "$target_link"
    echo "Created symlink: $target_link -> $item"
  fi
done

# Create an empty docker-compose.override.yml if it doesn't exist
if [ ! -f "$TARGET_SUBDIR/docker-compose.override.yml" ]; then
  touch "$TARGET_SUBDIR/docker-compose.override.yml"
  echo "Created empty docker-compose.override.yml"
fi

echo "All symbolic links processed."