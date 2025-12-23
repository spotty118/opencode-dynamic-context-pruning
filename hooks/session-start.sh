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

# Generate session ID for this session
SESSION_ID=$(date +%Y%m%d_%H%M%S)

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
  "preCompact": {
    "enabled": true,
    "showPreCompactAnalysis": true,
    "autoAnalyze": true,
    "useAgent": true
  },
  "notification": {
    "showOnSessionStart": true,
    "showAnalysisResults": true
  }
}
EOF
    echo -e "${GREEN}[DCP]${NC} Created default configuration at ${CONFIG_FILE}"
fi

# Load session memory if it exists
MEMORY_DIR="$HOME/.config/claude/dcp/memory/sessions"
SESSION_MEMORY="$MEMORY_DIR/$SESSION_ID"

if [ -d "$SESSION_MEMORY/summaries" ]; then
    echo -e "${BLUE}[DCP]${NC} Loading session memory..."

    # Count summaries
    SUMMARY_COUNT=$(ls -1 "$SESSION_MEMORY/summaries/" 2>/dev/null | wc -l)

    if [ "$SUMMARY_COUNT" -gt 0 ]; then
        echo -e "  Found $SUMMARY_COUNT previous compaction summaries"

        # Load last 3 summaries
        RECENT_SUMMARIES=$(ls -t "$SESSION_MEMORY/summaries/" | head -3)

        # Create context file for Claude
        CONTEXT_FILE="/tmp/dcp_session_${SESSION_ID}_memory.md"
        cat > "$CONTEXT_FILE" <<EOF
# Session Memory Loaded

This session has previous context from $SUMMARY_COUNT compactions.

## Recent Activity

EOF

        # Append executive summaries
        for summary_file in $RECENT_SUMMARIES; do
            SUMMARY_PATH="$SESSION_MEMORY/summaries/$summary_file"
            if command -v jq &> /dev/null && [ -f "$SUMMARY_PATH" ]; then
                EXEC_SUMMARY=$(jq -r '.summary.executive // "Summary not available"' "$SUMMARY_PATH")
                TIMESTAMP=$(jq -r '.timestamp // "Unknown time"' "$SUMMARY_PATH")
                echo "### Compaction at $TIMESTAMP" >> "$CONTEXT_FILE"
                echo "$EXEC_SUMMARY" >> "$CONTEXT_FILE"
                echo "" >> "$CONTEXT_FILE"
            fi
        done

        echo "" >> "$CONTEXT_FILE"
        echo "**Use 'search_memory' MCP tool to retrieve specific context from past summaries.**" >> "$CONTEXT_FILE"

        echo -e "  Memory context prepared at: $CONTEXT_FILE"
        echo -e "  ${GREEN}Session continuity enabled${NC}"
    fi
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
    echo "[$(date -Iseconds)] Session started - DCP v${PLUGIN_VERSION}" >> "$LOG_DIR/session_${SESSION_ID}.log"
fi

exit 0
