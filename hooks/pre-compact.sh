#!/bin/bash
# PreCompact hook for Dynamic Context Pruning plugin
# Triggers when Claude Code is about to compact context (manual or automatic)
# Spawns an agent to analyze the transcript and provide compaction guidance

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hook event data (provided by Claude Code via environment variables)
TRIGGER="${CLAUDE_HOOK_TRIGGER:-unknown}"              # 'manual' or 'auto'
TRANSCRIPT_PATH="${CLAUDE_HOOK_TRANSCRIPT_PATH:-}"     # Path to conversation file
SESSION_ID="${CLAUDE_HOOK_SESSION_ID:-}"               # Current session ID
CUSTOM_INSTRUCTIONS="${CLAUDE_HOOK_CUSTOM_INSTRUCTIONS:-}"
CWD="${CLAUDE_HOOK_CWD:-$PWD}"

# Plugin configuration
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$HOME/.config/claude/dcp"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Load configuration
ENABLED=true
PRECOMPACT_ENABLED=true
SHOW_NOTIFICATIONS=true
AUTO_ANALYZE=true

if [ -f "$CONFIG_FILE" ]; then
    ENABLED=$(grep -o '"enabled":\s*\(true\|false\)' "$CONFIG_FILE" | grep -o 'true\|false' || echo "true")
    PRECOMPACT_ENABLED=$(grep -o '"preCompact":\s*{\s*"enabled":\s*\(true\|false\)' "$CONFIG_FILE" | grep -o 'true\|false' | tail -1 || echo "true")
    SHOW_NOTIFICATIONS=$(grep -o '"showPreCompactAnalysis":\s*\(true\|false\)' "$CONFIG_FILE" | grep -o 'true\|false' || echo "true")
    AUTO_ANALYZE=$(grep -o '"autoAnalyze":\s*\(true\|false\)' "$CONFIG_FILE" | grep -o 'true\|false' || echo "true")
fi

# Exit early if disabled
if [ "$ENABLED" = "false" ] || [ "$PRECOMPACT_ENABLED" = "false" ]; then
    exit 0
fi

# Validate transcript path
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    if [ "$SHOW_NOTIFICATIONS" = "true" ]; then
        echo -e "${YELLOW}[DCP]${NC} PreCompact triggered but no transcript file available"
    fi
    exit 0
fi

# Show notification
if [ "$SHOW_NOTIFICATIONS" = "true" ]; then
    echo -e "${BLUE}[DCP PreCompact]${NC} Context compaction triggered (${TRIGGER})"
    echo -e "${BLUE}[DCP]${NC} Analyzing transcript to provide compaction guidance..."
fi

# Create analysis request file
ANALYSIS_DIR="$CONFIG_DIR/analysis"
mkdir -p "$ANALYSIS_DIR"
ANALYSIS_REQUEST="$ANALYSIS_DIR/precompact_${SESSION_ID}_$(date +%s).txt"

cat > "$ANALYSIS_REQUEST" << EOF
# PreCompact Context Analysis Request

**Trigger**: ${TRIGGER}
**Session**: ${SESSION_ID}
**Transcript**: ${TRANSCRIPT_PATH}
**Time**: $(date -Iseconds)

---

## Task

Claude Code is about to compact the conversation context. Please spawn an agent to analyze the transcript and provide guidance on what to preserve during compaction.

Use the Task tool with these instructions:

\`\`\`
You are a context pruning analyzer helping with a PreCompact event.

**Transcript File**: ${TRANSCRIPT_PATH}

Your task:
1. Read and analyze the conversation transcript
2. Apply three pruning strategies:
   - Deduplication: Find repeated tool calls with identical parameters
   - Supersede Writes: Find write operations superseded by reads
   - Semantic Analysis: Identify outputs no longer relevant

3. Generate compaction guidance with:
   - What to PRESERVE (critical context, recent decisions, active work)
   - What to REMOVE (duplicates, superseded content, obsolete data)
   - Token savings estimate

4. Provide specific recommendations for Claude's compaction system

Protected tools (NEVER recommend removing):
- Task (subagent invocations)
- TodoWrite, TodoRead
- Prune
- Batch

**Output Format**:

## Compaction Guidance

### Preserve (High Priority)
- [List specific tool results/content to keep]
- [Recent file operations and their context]
- [Active task tracking and decisions]

### Can Remove (Low Priority)
- [Duplicate tool calls: positions X, Y, Z]
- [Superseded writes: file W at position N]
- [Obsolete exploration: positions A, B, C]

### Token Analysis
- Estimated removable: ~X tokens
- Critical to preserve: ~Y tokens
- Net savings: ~Z tokens

### Recommendation
[Overall guidance for compaction strategy]
\`\`\`

After the agent completes analysis, provide the guidance to inform compaction decisions.

EOF

# Output the analysis request
cat "$ANALYSIS_REQUEST"

# If auto-analyze is enabled, provide immediate guidance based on quick heuristics
if [ "$AUTO_ANALYZE" = "true" ]; then
    echo -e "\n${GREEN}[DCP]${NC} Quick Analysis:"

    # Count tool calls in transcript (grep -c returns 0 if no matches)
    TOOL_COUNT=$(grep -c '"type":\s*"tool_use"' "$TRANSCRIPT_PATH" 2>/dev/null || true)
    TOOL_COUNT=${TOOL_COUNT:-0}

    # Count message blocks
    MESSAGE_COUNT=$(grep -c '"role":' "$TRANSCRIPT_PATH" 2>/dev/null || true)
    MESSAGE_COUNT=${MESSAGE_COUNT:-0}

    echo -e "  Tool calls: ${TOOL_COUNT}"
    echo -e "  Messages: ${MESSAGE_COUNT}"

    # Provide basic guidance
    if [ "$TOOL_COUNT" -gt 100 ]; then
        echo -e "\n${YELLOW}[DCP Guidance]${NC} Large number of tool calls detected."
        echo -e "  Recommendation: Prioritize preserving recent tool results and active file states."
        echo -e "  Consider removing: Early exploration, duplicate reads, resolved debugging outputs."
    fi

    if [ "$TRIGGER" = "auto" ]; then
        echo -e "\n${BLUE}[DCP]${NC} Automatic compaction - preserving conversation flow."
    else
        echo -e "\n${BLUE}[DCP]${NC} Manual compaction - user initiated optimization."
    fi
fi

# Log the event
if grep -q '"debug":\s*true' "$CONFIG_FILE" 2>/dev/null; then
    LOG_DIR="$CONFIG_DIR/logs"
    mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] PreCompact: trigger=$TRIGGER, tools=$TOOL_COUNT, messages=$MESSAGE_COUNT" >> "$LOG_DIR/precompact.log"
fi

# Exit successfully
exit 0
