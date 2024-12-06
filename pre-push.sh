#!/bin/bash

# Function to check if `git` is installed
function check_git_installed() {
  if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install it to proceed."
    exit 1
  fi
}

# Function to find large files and count them
function find_large_files() {
  # Initialize a counter for large files
  large_file_count=0

  # Exclude .git directory and respect .gitignore
  git ls-files --others --exclude-standard --cached | while read -r file; do
    # Check if the file exists and its size
    if [[ -f "$file" ]]; then
      filesize=$(stat -c%s "$file")
      if (( filesize > 2097152 )); then
        echo "Large file found: $file (Size: $((filesize / 1024 / 1024)) MB)"
        ((large_file_count++))
      fi
    fi
  done

  # Return the count of large files
  if (( large_file_count > 0 )); then
    echo "Error: $large_file_count large file(s) found. Resolve the issue before proceeding."
    exit 1
  fi
}

# Main script
check_git_installed
find_large_files

# Proceed if no large files are found
echo "No large files found. Proceeding with the build..."
shiroa build && echo "[pre-push] Build Done."
