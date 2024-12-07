#!/bin/bash

MAX_FILE_MB=4
MAX_FILE_SIZE=$((MAX_FILE_MB * 1024 * 1024))

# Function to print error messages in red to stderr with an endline before
function error_message() {
  echo >&2
  echo -e "\e[31m$1\e[0m" >&2
}

# Function to check if `git` is installed
function check_git_installed() {
  if ! command -v git &> /dev/null; then
    error_message "Error: git is not installed. Please install it to proceed."
    exit 1
  fi
}

# Function to find large files and count them
function find_large_files() {
  local large_file_count=0

  # Exclude .git directory and respect .gitignore
  git ls-files --others --exclude-standard --cached | while read -r file; do
    # Check if the file exists and its size
    if [[ -f "$file" ]]; then
      filesize=$(stat -c%s "$file")
      # Threshold: MAX_FILE_SIZE
      if (( filesize > MAX_FILE_SIZE )); then
        echo "Large file found: $file (Size: $((filesize / 1024 / 1024)) MB)"
        ((large_file_count++))
      fi
    fi
  done

  # Return the count of large files
  if (( large_file_count > 0 )); then
    error_message "Error: $large_file_count large file(s) found. Resolve the issue before proceeding."
    exit 1
  fi
}

# Function to check for .png files
function check_for_png_files() {
  if git ls-files | grep -q '\.png' || \
     find . -type f -name "*.png" -not -path "./.git/*" | grep -q .; then
    error_message "Error: .png files found in the repository or untracked. Aborting build."
    exit 1
  fi
}

# Function to report directory size ignoring .git
function report_directory_size() {
  local size=$(du -sh --exclude=.git . | cut -f1)
  echo "Current directory size (excluding .git): $size"
}

# Main script
check_git_installed
find_large_files
check_for_png_files

# Proceed if no large files or .png files are found
echo "No large or .png files found. Proceeding with the build..."
if shiroa build; then
  echo "[pre-push] Build Done."
  report_directory_size
  echo "[pre-push] Pre-push job completed successfully. You are ready to push."
else
  error_message "[pre-push] Build failed."
  exit 1
fi
