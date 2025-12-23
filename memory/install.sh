#!/bin/bash

################################################################################
# Context Memory System - Installation Script
################################################################################
#
# This script installs and configures the complete Context Memory System for
# Claude Code, including:
#   - MCP server for semantic search and retrieval
#   - Configuration directories
#   - Claude Code MCP integration
#   - Testing utilities
#
# Usage:
#   ./memory/install.sh [--skip-mcp-setup]
#
# Options:
#   --skip-mcp-setup    Skip automatic MCP configuration (manual setup required)
#
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MCP_SERVER_DIR="$SCRIPT_DIR/mcp-server"

# Configuration
SKIP_MCP_SETUP=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --skip-mcp-setup)
      SKIP_MCP_SETUP=true
      shift
      ;;
    -h|--help)
      head -n 30 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
      exit 0
      ;;
  esac
done

################################################################################
# Helper Functions
################################################################################

print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

check_command() {
  if command -v "$1" &> /dev/null; then
    print_success "$1 is installed ($(command -v "$1"))"
    return 0
  else
    print_error "$1 is not installed"
    return 1
  fi
}

################################################################################
# Dependency Checks
################################################################################

print_header "Checking Dependencies"

DEPENDENCIES_OK=true

# Check Node.js
if check_command node; then
  NODE_VERSION=$(node --version)
  print_info "Node.js version: $NODE_VERSION"

  # Check if version is >= 18.0.0
  MAJOR_VERSION=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d'.' -f1)
  if [ "$MAJOR_VERSION" -lt 18 ]; then
    print_error "Node.js version must be >= 18.0.0 (found: $NODE_VERSION)"
    DEPENDENCIES_OK=false
  fi
else
  DEPENDENCIES_OK=false
fi

# Check npm
if check_command npm; then
  NPM_VERSION=$(npm --version)
  print_info "npm version: $NPM_VERSION"
else
  DEPENDENCIES_OK=false
fi

# Check jq (optional but recommended)
if check_command jq; then
  JQ_VERSION=$(jq --version)
  print_info "jq version: $JQ_VERSION"
else
  print_warning "jq is not installed (optional, but recommended for JSON manipulation)"
fi

if [ "$DEPENDENCIES_OK" = false ]; then
  echo ""
  print_error "Missing required dependencies. Please install them first:"
  echo ""
  echo "  Ubuntu/Debian:"
  echo "    sudo apt-get update"
  echo "    sudo apt-get install nodejs npm jq"
  echo ""
  echo "  macOS:"
  echo "    brew install node jq"
  echo ""
  echo "  Or visit: https://nodejs.org/"
  exit 1
fi

################################################################################
# MCP Server Installation
################################################################################

print_header "Installing MCP Server"

if [ ! -d "$MCP_SERVER_DIR" ]; then
  print_error "MCP server directory not found: $MCP_SERVER_DIR"
  exit 1
fi

cd "$MCP_SERVER_DIR"

print_info "Installing dependencies..."
if npm install --silent; then
  print_success "Dependencies installed"
else
  print_error "Failed to install dependencies"
  exit 1
fi

print_info "Building TypeScript..."
if npm run build --silent; then
  print_success "Build completed"
else
  print_error "Build failed"
  exit 1
fi

# Verify build output
if [ -f "$MCP_SERVER_DIR/dist/index.js" ]; then
  print_success "MCP server built successfully: dist/index.js"
else
  print_error "Build output not found: dist/index.js"
  exit 1
fi

################################################################################
# Create Configuration Directories
################################################################################

print_header "Setting Up Configuration Directories"

# Default Claude config directory
CLAUDE_CONFIG_DIR="${HOME}/.config/claude"
DCP_MEMORY_DIR="${CLAUDE_CONFIG_DIR}/dcp/memory"

print_info "Creating configuration directories..."

mkdir -p "$DCP_MEMORY_DIR/sessions"
print_success "Created: $DCP_MEMORY_DIR/sessions"

mkdir -p "$DCP_MEMORY_DIR/projects"
print_success "Created: $DCP_MEMORY_DIR/projects"

mkdir -p "$CLAUDE_CONFIG_DIR"
print_success "Created: $CLAUDE_CONFIG_DIR"

################################################################################
# Make Scripts Executable
################################################################################

print_header "Making Scripts Executable"

cd "$SCRIPT_DIR"

for script in install.sh setup-mcp.sh test-memory-system.sh; do
  if [ -f "$script" ]; then
    chmod +x "$script"
    print_success "Made executable: $script"
  else
    print_warning "Script not found: $script"
  fi
done

################################################################################
# MCP Configuration
################################################################################

if [ "$SKIP_MCP_SETUP" = false ]; then
  print_header "Configuring Claude Code MCP Integration"

  print_info "Running setup-mcp.sh..."
  if [ -f "$SCRIPT_DIR/setup-mcp.sh" ]; then
    if "$SCRIPT_DIR/setup-mcp.sh"; then
      print_success "MCP configuration completed"
    else
      print_warning "MCP configuration had issues (you may need to configure manually)"
    fi
  else
    print_warning "setup-mcp.sh not found, skipping MCP configuration"
  fi
else
  print_header "Skipping MCP Configuration"
  print_info "You can configure MCP manually later by running:"
  echo "    ./memory/setup-mcp.sh"
fi

################################################################################
# Installation Summary
################################################################################

print_header "Installation Complete!"

echo -e "${GREEN}The Context Memory System has been successfully installed!${NC}\n"

echo "Installation summary:"
echo "  ✓ MCP Server: $MCP_SERVER_DIR/dist/index.js"
echo "  ✓ Memory Storage: $DCP_MEMORY_DIR"
echo "  ✓ Configuration: $CLAUDE_CONFIG_DIR"
echo ""

################################################################################
# Next Steps
################################################################################

print_header "Next Steps"

echo "1. Test the installation:"
echo "   ${BLUE}./memory/test-memory-system.sh${NC}"
echo ""

if [ "$SKIP_MCP_SETUP" = true ]; then
  echo "2. Configure MCP manually:"
  echo "   ${BLUE}./memory/setup-mcp.sh${NC}"
  echo ""
fi

echo "2. Verify MCP server is working:"
echo "   ${BLUE}cd memory/mcp-server && npm start${NC}"
echo "   (Press Ctrl+C to stop)"
echo ""

echo "3. Claude Code will automatically use the MCP server when:"
echo "   - You search for context using semantic queries"
echo "   - You need to recall past decisions and code changes"
echo "   - PreCompact hooks store conversation summaries"
echo ""

echo "4. Read the documentation:"
echo "   ${BLUE}memory/mcp-server/README.md${NC}"
echo "   ${BLUE}memory/mcp-server/QUICKSTART.md${NC}"
echo "   ${BLUE}memory/mcp-server/INTEGRATION.md${NC}"
echo ""

print_info "For help, visit: https://github.com/Opencode-DCP/opencode-dynamic-context-pruning"

echo ""
