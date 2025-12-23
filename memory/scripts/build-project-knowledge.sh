#!/bin/bash
# Project Knowledge Builder for Dynamic Context Pruning
# Analyzes all session summaries and builds a cumulative knowledge base
#
# Usage: ./build-project-knowledge.sh [project_directory]
# Output: knowledge.json in ~/.config/claude/dcp/memory/projects/<project_hash>/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to current directory if no argument provided
PROJECT_DIR="${1:-.}"

# Verify the directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error:${NC} Directory does not exist: $PROJECT_DIR" >&2
    exit 1
fi

# Convert to absolute path
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)

# Verify dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error:${NC} jq is required but not installed. Please install jq." >&2
    exit 1
fi

# Generate project hash
echo -e "${BLUE}[Knowledge Builder]${NC} Analyzing project: $PROJECT_DIR"
PROJECT_HASH=$("$SCRIPT_DIR/project-hash.sh" "$PROJECT_DIR")

if [ -z "$PROJECT_HASH" ]; then
    echo -e "${RED}Error:${NC} Failed to generate project hash" >&2
    exit 1
fi

echo -e "${BLUE}[Knowledge Builder]${NC} Project hash: $PROJECT_HASH"

# Set up paths
CONFIG_DIR="$HOME/.config/claude/dcp"
MEMORY_DIR="$CONFIG_DIR/memory"
SESSIONS_DIR="$MEMORY_DIR/sessions"
PROJECT_MEMORY_DIR="$MEMORY_DIR/projects/$PROJECT_HASH"
KNOWLEDGE_FILE="$PROJECT_MEMORY_DIR/knowledge.json"

# Create project memory directory if it doesn't exist
mkdir -p "$PROJECT_MEMORY_DIR"

# Find all session summaries (searching all sessions)
echo -e "${BLUE}[Knowledge Builder]${NC} Scanning for session summaries..."

# Array to store all summary files
declare -a SUMMARY_FILES

# Find all summary JSON files in the sessions directory
if [ -d "$SESSIONS_DIR" ]; then
    while IFS= read -r -d '' summary_file; do
        SUMMARY_FILES+=("$summary_file")
    done < <(find "$SESSIONS_DIR" -type f -name "*.json" -print0 2>/dev/null)
fi

SUMMARY_COUNT=${#SUMMARY_FILES[@]}

if [ "$SUMMARY_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}[Warning]${NC} No session summaries found. Creating empty knowledge base."

    # Create empty knowledge structure
    cat > "$KNOWLEDGE_FILE" <<EOF
{
  "project_id": "$PROJECT_HASH",
  "project_path": "$PROJECT_DIR",
  "created": "$(date -Iseconds)",
  "updated": "$(date -Iseconds)",
  "summary_count": 0,
  "knowledge": {
    "architectural_decisions": [],
    "code_patterns": [],
    "conventions": [],
    "technologies": [],
    "common_tasks": []
  }
}
EOF
    echo -e "${GREEN}[Success]${NC} Created empty knowledge base at: $KNOWLEDGE_FILE"
    exit 0
fi

echo -e "${BLUE}[Knowledge Builder]${NC} Found $SUMMARY_COUNT session summaries"
echo -e "${BLUE}[Knowledge Builder]${NC} Extracting knowledge..."

# Temporary files for processing
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

DECISIONS_FILE="$TEMP_DIR/decisions.json"
PATTERNS_FILE="$TEMP_DIR/patterns.json"
CONVENTIONS_FILE="$TEMP_DIR/conventions.json"
TECHNOLOGIES_FILE="$TEMP_DIR/technologies.json"
TASKS_FILE="$TEMP_DIR/tasks.json"

# Initialize temporary JSON arrays
echo "[]" > "$DECISIONS_FILE"
echo "[]" > "$PATTERNS_FILE"
echo "[]" > "$CONVENTIONS_FILE"
echo "[]" > "$TECHNOLOGIES_FILE"
echo "[]" > "$TASKS_FILE"

# Process each summary file
for summary_file in "${SUMMARY_FILES[@]}"; do
    # Get session ID from file path
    SESSION_ID=$(basename "$(dirname "$summary_file")")
    COMPACT_ID=$(basename "$summary_file" .json)
    SOURCE_ID="${SESSION_ID}/${COMPACT_ID}"

    # Extract key decisions
    if jq -e '.summary.key_decisions' "$summary_file" &>/dev/null; then
        jq -r --arg source "$SOURCE_ID" '
            .summary.key_decisions[]? |
            {
                topic: .topic,
                decision: .decision,
                rationale: .rationale,
                confidence: 0.8,
                sources: [$source],
                files: (.files // [])
            }
        ' "$summary_file" | jq -s '.' >> "$DECISIONS_FILE.tmp"

        if [ -f "$DECISIONS_FILE.tmp" ]; then
            jq -s 'add' "$DECISIONS_FILE" "$DECISIONS_FILE.tmp" > "$DECISIONS_FILE.new"
            mv "$DECISIONS_FILE.new" "$DECISIONS_FILE"
            rm "$DECISIONS_FILE.tmp"
        fi
    fi

    # Extract technologies from topics
    if jq -e '.summary.topics' "$summary_file" &>/dev/null; then
        jq -r --arg source "$SOURCE_ID" '
            .summary.topics[]? |
            {
                name: .,
                category: "general",
                sources: [$source],
                frequency: 1
            }
        ' "$summary_file" | jq -s '.' >> "$TECHNOLOGIES_FILE.tmp"

        if [ -f "$TECHNOLOGIES_FILE.tmp" ]; then
            jq -s 'add' "$TECHNOLOGIES_FILE" "$TECHNOLOGIES_FILE.tmp" > "$TECHNOLOGIES_FILE.new"
            mv "$TECHNOLOGIES_FILE.new" "$TECHNOLOGIES_FILE"
            rm "$TECHNOLOGIES_FILE.tmp"
        fi
    fi

    # Extract common tasks
    if jq -e '.summary.tasks_completed' "$summary_file" &>/dev/null; then
        jq -r --arg source "$SOURCE_ID" '
            .summary.tasks_completed[]? |
            {
                task: .,
                frequency: 1,
                sources: [$source]
            }
        ' "$summary_file" | jq -s '.' >> "$TASKS_FILE.tmp"

        if [ -f "$TASKS_FILE.tmp" ]; then
            jq -s 'add' "$TASKS_FILE" "$TASKS_FILE.tmp" > "$TASKS_FILE.new"
            mv "$TASKS_FILE.new" "$TASKS_FILE"
            rm "$TASKS_FILE.tmp"
        fi
    fi

    # Extract code patterns from snippets
    if jq -e '.summary.code_snippets' "$summary_file" &>/dev/null; then
        jq -r --arg source "$SOURCE_ID" '
            .summary.code_snippets[]? |
            select(.importance == "high") |
            {
                pattern: .function,
                description: ("Function in " + .file),
                file: .file,
                sources: [$source],
                importance: .importance
            }
        ' "$summary_file" | jq -s '.' >> "$PATTERNS_FILE.tmp"

        if [ -f "$PATTERNS_FILE.tmp" ]; then
            jq -s 'add' "$PATTERNS_FILE" "$PATTERNS_FILE.tmp" > "$PATTERNS_FILE.new"
            mv "$PATTERNS_FILE.new" "$PATTERNS_FILE"
            rm "$PATTERNS_FILE.tmp"
        fi
    fi
done

echo -e "${BLUE}[Knowledge Builder]${NC} Aggregating and deduplicating knowledge..."

# Aggregate architectural decisions (merge by topic)
AGGREGATED_DECISIONS=$(jq -s '
    add |
    group_by(.topic) |
    map({
        topic: .[0].topic,
        decision: .[0].decision,
        rationale: .[0].rationale,
        confidence: (if length > 1 then 0.9 else 0.8 end),
        sources: (map(.sources[]) | unique),
        files: (map(.files[]?) | unique)
    }) |
    sort_by(-.confidence)
' "$DECISIONS_FILE")

# Aggregate technologies (merge by name and count frequency)
AGGREGATED_TECHNOLOGIES=$(jq -s '
    add |
    group_by(.name) |
    map({
        name: .[0].name,
        category: .[0].category,
        frequency: (map(.frequency) | add),
        sources: (map(.sources[]) | unique)
    }) |
    sort_by(-.frequency)
' "$TECHNOLOGIES_FILE")

# Aggregate common tasks (merge by task name and count frequency)
AGGREGATED_TASKS=$(jq -s '
    add |
    group_by(.task) |
    map({
        task: .[0].task,
        frequency: (map(.frequency) | add),
        sources: (map(.sources[]) | unique)
    }) |
    sort_by(-.frequency) |
    .[0:20]
' "$TASKS_FILE")

# Aggregate code patterns (merge by pattern name)
AGGREGATED_PATTERNS=$(jq -s '
    add |
    group_by(.pattern) |
    map({
        pattern: .[0].pattern,
        description: .[0].description,
        file: .[0].file,
        importance: .[0].importance,
        sources: (map(.sources[]) | unique)
    }) |
    sort_by(.pattern)
' "$PATTERNS_FILE")

# Create conventions array (placeholder for future enhancement)
CONVENTIONS='[]'

echo -e "${BLUE}[Knowledge Builder]${NC} Building knowledge graph..."

# Build the final knowledge JSON
cat > "$KNOWLEDGE_FILE" <<EOF
{
  "project_id": "$PROJECT_HASH",
  "project_path": "$PROJECT_DIR",
  "created": "$(date -Iseconds)",
  "updated": "$(date -Iseconds)",
  "summary_count": $SUMMARY_COUNT,
  "knowledge": {
    "architectural_decisions": $AGGREGATED_DECISIONS,
    "code_patterns": $AGGREGATED_PATTERNS,
    "conventions": $CONVENTIONS,
    "technologies": $AGGREGATED_TECHNOLOGIES,
    "common_tasks": $AGGREGATED_TASKS
  }
}
EOF

# Validate JSON
if ! jq empty "$KNOWLEDGE_FILE" 2>/dev/null; then
    echo -e "${RED}Error:${NC} Generated invalid JSON" >&2
    exit 1
fi

# Print summary statistics
DECISIONS_COUNT=$(echo "$AGGREGATED_DECISIONS" | jq 'length')
TECHNOLOGIES_COUNT=$(echo "$AGGREGATED_TECHNOLOGIES" | jq 'length')
TASKS_COUNT=$(echo "$AGGREGATED_TASKS" | jq 'length')
PATTERNS_COUNT=$(echo "$AGGREGATED_PATTERNS" | jq 'length')

echo ""
echo -e "${GREEN}[Success]${NC} Knowledge base built successfully!"
echo -e "${BLUE}[Statistics]${NC}"
echo "  Location: $KNOWLEDGE_FILE"
echo "  Summaries analyzed: $SUMMARY_COUNT"
echo "  Architectural decisions: $DECISIONS_COUNT"
echo "  Technologies identified: $TECHNOLOGIES_COUNT"
echo "  Common tasks: $TASKS_COUNT"
echo "  Code patterns: $PATTERNS_COUNT"
echo ""
echo -e "${GREEN}Use this knowledge base to inform future sessions in this project.${NC}"

exit 0
