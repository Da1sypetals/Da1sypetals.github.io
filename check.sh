#!/bin/bash

# Function to check if `git` is installed
function check_git_installed() {
  if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install it to proceed."
    exit 1
  fi
}

# Function to find large files
function find_large_files() {
  # Exclude .git directory and respect .gitignore
  git ls-files --others --exclude-standard --cached | while read -r file; do
    # Check if the file exists and its size
    if [[ -f "$file" ]]; then
      filesize=$(stat -c%s "$file")
      if (( filesize > 2097152 )); then
        echo "Large file found: $file (Size: $((filesize / 1024 / 1024)) MB)"
      fi
    fi
  done
}

# Main script
check_git_installed
find_large_files
