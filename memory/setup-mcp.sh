#!/bin/bash

################################################################################
# Context Memory System - MCP Configuration Script
################################################################################
#
# This script configures Claude Code to use the Context Memory MCP Server.
# It automatically detects your Claude Code configuration location and adds
# or updates the MCP server entry.
#
# Usage:
#   ./memory/setup-mcp.sh [--config-path PATH]
#
# Options:
#   --config-path PATH    Specify custom Claude config file path
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
MCP_SERVER_PATH="$SCRIPT_DIR/mcp-server/dist/index.js"

# Configuration
CUSTOM_CONFIG_PATH=""

# Parse arguments
for arg in "$@"; do
  case $arg in
    --config-path=*)
      CUSTOM_CONFIG_PATH="${arg#*=}"
      shift
      ;;
    -h|--help)
      head -n 20 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
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

################################################################################
# Detect Claude Code Configuration Location
################################################################################

print_header "Detecting Claude Code Configuration"

detect_config_path() {
  # Possible configuration locations
  local CONFIG_PATHS=(
    "${HOME}/.config/claude-code/settings.json"
    "${HOME}/.claude-code/settings.json"
    "${HOME}/.config/claude/settings.json"
    "${HOME}/.claude/settings.json"
    "${HOME}/Library/Application Support/claude-code/settings.json"
    "${HOME}/Library/Application Support/Claude/settings.json"
  )

  if [ -n "$CUSTOM_CONFIG_PATH" ]; then
    echo "$CUSTOM_CONFIG_PATH"
    return 0
  fi

  for path in "${CONFIG_PATHS[@]}"; do
    if [ -f "$path" ]; then
      echo "$path"
      return 0
    fi
  done

  # If no existing config found, use default
  echo "${HOME}/.config/claude-code/settings.json"
}

CONFIG_PATH=$(detect_config_path)
CONFIG_DIR=$(dirname "$CONFIG_PATH")

if [ -f "$CONFIG_PATH" ]; then
  print_success "Found existing configuration: $CONFIG_PATH"
else
  print_info "Configuration will be created at: $CONFIG_PATH"
fi

################################################################################
# Verify MCP Server Build
################################################################################

print_header "Verifying MCP Server"

if [ ! -f "$MCP_SERVER_PATH" ]; then
  print_error "MCP server not found: $MCP_SERVER_PATH"
  print_info "Please run: cd memory/mcp-server && npm install && npm run build"
  exit 1
fi

print_success "MCP server found: $MCP_SERVER_PATH"

################################################################################
# Check Dependencies
################################################################################

if ! command -v node &> /dev/null; then
  print_error "Node.js is not installed"
  exit 1
fi

print_success "Node.js is available: $(node --version)"

# Check if jq is available for JSON manipulation
HAS_JQ=false
if command -v jq &> /dev/null; then
  HAS_JQ=true
  print_success "jq is available for JSON manipulation"
else
  print_warning "jq not found, using fallback JSON manipulation"
fi

################################################################################
# Create/Update MCP Configuration
################################################################################

print_header "Configuring MCP Server"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"
print_success "Configuration directory ready: $CONFIG_DIR"

# Backup existing config if it exists
if [ -f "$CONFIG_PATH" ]; then
  BACKUP_PATH="${CONFIG_PATH}.backup.$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG_PATH" "$BACKUP_PATH"
  print_success "Backed up existing configuration to: $BACKUP_PATH"
fi

# Create or update configuration
if [ "$HAS_JQ" = true ]; then
  # Use jq for proper JSON manipulation
  if [ -f "$CONFIG_PATH" ]; then
    # Update existing config
    TEMP_CONFIG=$(mktemp)
    jq --arg server_path "$MCP_SERVER_PATH" \
       '.mcpServers["context-memory"] = {
          "command": "node",
          "args": [$server_path],
          "env": {}
        }' "$CONFIG_PATH" > "$TEMP_CONFIG"
    mv "$TEMP_CONFIG" "$CONFIG_PATH"
    print_success "Updated existing configuration with context-memory MCP server"
  else
    # Create new config
    cat > "$CONFIG_PATH" <<EOF
{
  "mcpServers": {
    "context-memory": {
      "command": "node",
      "args": [
        "$MCP_SERVER_PATH"
      ],
      "env": {}
    }
  }
}
EOF
    print_success "Created new configuration with context-memory MCP server"
  fi
else
  # Fallback: Simple JSON creation/update without jq
  if [ -f "$CONFIG_PATH" ]; then
    # Check if mcpServers already exists
    if grep -q '"mcpServers"' "$CONFIG_PATH"; then
      # Try to add to existing mcpServers section
      print_warning "Existing configuration detected. Manual merge may be required."
      print_info "Please add this MCP server configuration manually:"
      echo ""
      echo '  "context-memory": {'
      echo '    "command": "node",'
      echo '    "args": ['
      echo "      \"$MCP_SERVER_PATH\""
      echo '    ],'
      echo '    "env": {}'
      echo '  }'
      echo ""
    else
      print_error "Cannot automatically update complex configuration without jq"
      print_info "Please install jq or manually add the configuration"
      exit 1
    fi
  else
    # Create simple new config
    cat > "$CONFIG_PATH" <<EOF
{
  "mcpServers": {
    "context-memory": {
      "command": "node",
      "args": [
        "$MCP_SERVER_PATH"
      ],
      "env": {}
    }
  }
}
EOF
    print_success "Created new configuration with context-memory MCP server"
  fi
fi

################################################################################
# Validate Configuration
################################################################################

print_header "Validating Configuration"

if [ ! -f "$CONFIG_PATH" ]; then
  print_error "Configuration file was not created"
  exit 1
fi

# Validate JSON syntax
if [ "$HAS_JQ" = true ]; then
  if jq empty "$CONFIG_PATH" 2>/dev/null; then
    print_success "Configuration JSON is valid"
  else
    print_error "Configuration JSON is invalid"
    exit 1
  fi
else
  # Basic validation without jq
  if node -e "JSON.parse(require('fs').readFileSync('$CONFIG_PATH', 'utf8'))" 2>/dev/null; then
    print_success "Configuration JSON is valid"
  else
    print_error "Configuration JSON is invalid"
    exit 1
  fi
fi

# Verify the MCP server entry exists
if grep -q "context-memory" "$CONFIG_PATH"; then
  print_success "context-memory MCP server entry found"
else
  print_error "context-memory MCP server entry not found in configuration"
  exit 1
fi

################################################################################
# Test Connection
################################################################################

print_header "Testing MCP Server Connection"

print_info "Starting MCP server for connection test..."

# Try to start the server and check if it responds
TIMEOUT=5
if timeout $TIMEOUT node "$MCP_SERVER_PATH" <<< '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' &> /dev/null; then
  print_success "MCP server responds correctly"
else
  print_warning "Could not verify server response (this may be normal)"
  print_info "The server will be started automatically by Claude Code when needed"
fi

################################################################################
# Configuration Summary
################################################################################

print_header "Configuration Complete!"

echo -e "${GREEN}MCP Server has been successfully configured!${NC}\n"

echo "Configuration details:"
echo "  ✓ Config file: $CONFIG_PATH"
echo "  ✓ Server path: $MCP_SERVER_PATH"
echo "  ✓ Server name: context-memory"
echo ""

print_info "View your configuration:"
if [ "$HAS_JQ" = true ]; then
  echo ""
  jq '.mcpServers["context-memory"]' "$CONFIG_PATH"
  echo ""
else
  echo "  cat $CONFIG_PATH"
fi

################################################################################
# Next Steps
################################################################################

print_header "Next Steps"

echo "1. Restart Claude Code for changes to take effect"
echo ""

echo "2. Verify MCP tools are available in Claude Code:"
echo "   - search_memory"
echo "   - store_summary"
echo "   - get_summary"
echo "   - list_sessions"
echo "   - get_session_metadata"
echo "   - get_project_knowledge"
echo ""

echo "3. Test the memory system:"
echo "   ${BLUE}./memory/test-memory-system.sh${NC}"
echo ""

echo "4. Read the integration guide:"
echo "   ${BLUE}memory/mcp-server/INTEGRATION.md${NC}"
echo ""

print_success "Setup complete!"

echo ""
