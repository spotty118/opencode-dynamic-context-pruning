#!/bin/bash
# Project Hash Generator for Dynamic Context Pruning
# Generates a consistent hash identifier for a project
#
# Usage: ./project-hash.sh [project_directory]
# Output: 64-character SHA256 hash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default to current directory if no argument provided
PROJECT_DIR="${1:-.}"

# Verify the directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error:${NC} Directory does not exist: $PROJECT_DIR" >&2
    exit 1
fi

# Convert to absolute path
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)

# Function to generate hash from git remote URL
generate_git_hash() {
    local dir="$1"

    # Check if it's a git repository
    if [ ! -d "$dir/.git" ]; then
        return 1
    fi

    # Get the remote URL (prefer origin, fallback to first remote)
    local remote_url
    remote_url=$(cd "$dir" && git remote get-url origin 2>/dev/null) || \
    remote_url=$(cd "$dir" && git remote -v 2>/dev/null | head -1 | awk '{print $2}')

    if [ -z "$remote_url" ]; then
        return 1
    fi

    # Normalize the URL (remove .git suffix, normalize github URLs)
    remote_url=$(echo "$remote_url" | sed 's/\.git$//')
    remote_url=$(echo "$remote_url" | sed 's|^git@github.com:|https://github.com/|')
    remote_url=$(echo "$remote_url" | sed 's|^git@|https://|' | sed 's|:|/|')

    # Generate SHA256 hash
    echo -n "$remote_url" | sha256sum | awk '{print $1}'
    return 0
}

# Function to generate hash from directory path
generate_path_hash() {
    local dir="$1"

    # Use the absolute path
    echo -n "$dir" | sha256sum | awk '{print $1}'
}

# Try git-based hash first, fallback to path-based hash
PROJECT_HASH=""
HASH_METHOD=""

if PROJECT_HASH=$(generate_git_hash "$PROJECT_DIR"); then
    HASH_METHOD="git-remote"
else
    PROJECT_HASH=$(generate_path_hash "$PROJECT_DIR")
    HASH_METHOD="directory-path"
fi

# Output the hash
echo "$PROJECT_HASH"

# If debug mode is enabled (via environment variable), show additional info
if [ "${DCP_DEBUG:-false}" = "true" ]; then
    echo -e "${YELLOW}[DEBUG]${NC} Project: $PROJECT_DIR" >&2
    echo -e "${YELLOW}[DEBUG]${NC} Hash method: $HASH_METHOD" >&2
    echo -e "${YELLOW}[DEBUG]${NC} Hash: $PROJECT_HASH" >&2
fi

exit 0
