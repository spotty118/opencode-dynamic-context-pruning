#!/bin/bash
# SessionStart hook for Dynamic Context Pruning plugin
# This script runs when a new Claude Code session begins

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Plugin information
PLUGIN_NAME="Dynamic Context Pruning"
PLUGIN_VERSION="2.0.0"

# Check if this is the first run by looking for config
CONFIG_DIR="$HOME/.config/claude/dcp"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
fi

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
  "enabled": true,
  "debug": false,
  "strategies": {
    "deduplication": {
      "enabled": true,
      "protectedTools": []
    },
    "supersedeWrites": {
      "enabled": true
    },
    "semantic": {
      "enabled": true
    }
  },
  "notification": {
    "showOnSessionStart": true,
    "showAnalysisResults": true
  }
}
EOF
    echo -e "${GREEN}[DCP]${NC} Created default configuration at ${CONFIG_FILE}"
fi

# Read config to check if notifications are enabled
SHOW_NOTIFICATION=$(grep -o '"showOnSessionStart":\s*true' "$CONFIG_FILE" || echo "")

# Show welcome notification if enabled
if [ -n "$SHOW_NOTIFICATION" ]; then
    echo -e "${BLUE}[Dynamic Context Pruning v${PLUGIN_VERSION}]${NC}"
    echo "Plugin loaded. Use /prune to analyze conversation context."
    echo "Commands: /prune | Skills: context-pruning"
fi

# Initialize session log if debug is enabled
DEBUG_ENABLED=$(grep -o '"debug":\s*true' "$CONFIG_FILE" || echo "")
if [ -n "$DEBUG_ENABLED" ]; then
    LOG_DIR="$CONFIG_DIR/logs"
    mkdir -p "$LOG_DIR"
    SESSION_ID=$(date +%Y%m%d_%H%M%S)
    echo "[$(date -Iseconds)] Session started - DCP v${PLUGIN_VERSION}" >> "$LOG_DIR/session_${SESSION_ID}.log"
fi

exit 0
