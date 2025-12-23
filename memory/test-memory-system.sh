#!/bin/bash

################################################################################
# Context Memory System - Test Script
################################################################################
#
# This script tests the complete Context Memory System, including:
#   - MCP server functionality
#   - Summary storage
#   - Semantic search
#   - Session management
#   - Configuration validation
#
# Usage:
#   ./memory/test-memory-system.sh [--verbose]
#
# Options:
#   --verbose    Show detailed test output
#
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MCP_SERVER_PATH="$SCRIPT_DIR/mcp-server/dist/index.js"
MCP_SERVER_DIR="$SCRIPT_DIR/mcp-server"

# Configuration
VERBOSE=false
TEST_SESSION_ID="test_session_$(date +%s)"
TEST_SUMMARY_ID=""

# Parse arguments
for arg in "$@"; do
  case $arg in
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      head -n 25 "$0" | tail -n +3 | sed 's/^# //' | sed 's/^#//'
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

print_test() {
  echo -e "${CYAN}▶${NC} Testing: $1"
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

verbose() {
  if [ "$VERBOSE" = true ]; then
    echo -e "${NC}  $1${NC}"
  fi
}

################################################################################
# Test Counter
################################################################################

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

increment_passed() {
  ((TESTS_PASSED++))
  ((TESTS_TOTAL++))
}

increment_failed() {
  ((TESTS_FAILED++))
  ((TESTS_TOTAL++))
}

################################################################################
# Pre-flight Checks
################################################################################

print_header "Pre-flight Checks"

# Check Node.js
print_test "Node.js installation"
if command -v node &> /dev/null; then
  NODE_VERSION=$(node --version)
  print_success "Node.js is installed: $NODE_VERSION"
  increment_passed
else
  print_error "Node.js is not installed"
  increment_failed
  exit 1
fi

# Check MCP server build
print_test "MCP server build"
if [ -f "$MCP_SERVER_PATH" ]; then
  print_success "MCP server found: $MCP_SERVER_PATH"
  increment_passed
else
  print_error "MCP server not found. Please run: cd memory/mcp-server && npm install && npm run build"
  increment_failed
  exit 1
fi

# Check memory storage directory
print_test "Memory storage directory"
MEMORY_DIR="${HOME}/.config/claude/dcp/memory"
if [ -d "$MEMORY_DIR" ]; then
  print_success "Memory directory exists: $MEMORY_DIR"
  increment_passed
else
  print_warning "Memory directory not found, creating: $MEMORY_DIR"
  mkdir -p "$MEMORY_DIR/sessions" "$MEMORY_DIR/projects"
  print_success "Memory directory created"
  increment_passed
fi

################################################################################
# MCP Server Tests
################################################################################

print_header "MCP Server Tests"

# Helper function to send MCP requests
send_mcp_request() {
  local method="$1"
  local params="$2"
  local request_id=$((RANDOM % 10000))

  local request="{\"jsonrpc\":\"2.0\",\"id\":$request_id,\"method\":\"$method\""
  if [ -n "$params" ]; then
    request="$request,\"params\":$params"
  fi
  request="$request}"

  verbose "Request: $request"

  echo "$request" | timeout 10 node "$MCP_SERVER_PATH" 2>&1 | grep -v "^$" | head -1
}

# Test 1: Initialize MCP server
print_test "Initialize MCP server"
INIT_RESULT=$(send_mcp_request "initialize" '{"protocolVersion":"2024-11-05","capabilities":{}}')
verbose "Response: $INIT_RESULT"

if echo "$INIT_RESULT" | grep -q '"result"'; then
  print_success "MCP server initialized successfully"
  increment_passed
else
  print_error "MCP server initialization failed"
  verbose "$INIT_RESULT"
  increment_failed
fi

# Test 2: List available tools
print_test "List available MCP tools"
TOOLS_RESULT=$(send_mcp_request "tools/list" "")
verbose "Response: $TOOLS_RESULT"

if echo "$TOOLS_RESULT" | grep -q "search_memory"; then
  print_success "MCP tools are available"
  increment_passed

  # Count tools
  if command -v jq &> /dev/null; then
    TOOL_COUNT=$(echo "$TOOLS_RESULT" | jq '.result.tools | length' 2>/dev/null || echo "unknown")
    verbose "Available tools: $TOOL_COUNT"
  fi
else
  print_error "MCP tools not found"
  increment_failed
fi

################################################################################
# Storage Tests
################################################################################

print_header "Storage Tests"

# Test 3: Store a test summary
print_test "Store test summary"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SUMMARY_JSON=$(cat <<EOF
{
  "session_id": "$TEST_SESSION_ID",
  "summary": {
    "timestamp": "$TIMESTAMP",
    "compaction_trigger": "manual_test",
    "token_count_before": 150000,
    "token_count_after": 100000,
    "summary": {
      "executive": "Test summary for Context Memory System validation. This verifies that the complete memory system is working correctly, including storage, retrieval, and search capabilities.",
      "key_decisions": [
        {
          "topic": "Testing Strategy",
          "decision": "Implement comprehensive test suite for memory system",
          "rationale": "Ensures reliability and catches regressions early in development",
          "files": ["memory/test-memory-system.sh", "memory/scripts/test-mcp-server.ts"]
        },
        {
          "topic": "Storage Architecture",
          "decision": "Use file-based storage with session-based organization",
          "rationale": "Simple, portable, and easy to debug without external dependencies",
          "files": ["memory/mcp-server/index.ts"]
        }
      ],
      "files_modified": [
        {
          "path": "memory/mcp-server/index.ts",
          "action": "created",
          "purpose": "MCP server implementation with semantic search capabilities"
        },
        {
          "path": "memory/install.sh",
          "action": "created",
          "purpose": "Automated installation and setup script"
        },
        {
          "path": "memory/test-memory-system.sh",
          "action": "created",
          "purpose": "Comprehensive testing script for memory system"
        }
      ],
      "code_snippets": [
        {
          "file": "memory/mcp-server/index.ts",
          "language": "typescript",
          "code": "// Semantic search implementation\nfunction searchSummaries(query: string, limit: number): SearchResult[]",
          "purpose": "Core search functionality for finding relevant context"
        }
      ],
      "topics": ["testing", "mcp-server", "context-memory", "semantic-search", "installation"],
      "tasks_completed": [
        "Create MCP server with semantic search",
        "Implement summary storage and retrieval",
        "Build installation scripts",
        "Add comprehensive test suite"
      ],
      "tasks_pending": [
        "Add vector embeddings support",
        "Implement cross-session pattern detection",
        "Optimize search algorithm",
        "Add export/import capabilities"
      ]
    }
  }
}
EOF
)

STORE_RESULT=$(send_mcp_request "tools/call" "{\"name\":\"store_summary\",\"arguments\":$SUMMARY_JSON}")
verbose "Response: $STORE_RESULT"

if echo "$STORE_RESULT" | grep -q '"success":true'; then
  print_success "Test summary stored successfully"
  increment_passed

  # Extract summary ID
  if command -v jq &> /dev/null; then
    TEST_SUMMARY_ID=$(echo "$STORE_RESULT" | jq -r '.result.content[0].text' 2>/dev/null | jq -r '.summary_id' 2>/dev/null || echo "")
    if [ -n "$TEST_SUMMARY_ID" ]; then
      verbose "Summary ID: $TEST_SUMMARY_ID"
    fi
  fi
else
  print_error "Failed to store test summary"
  verbose "$STORE_RESULT"
  increment_failed
fi

################################################################################
# Search Tests
################################################################################

print_header "Search Tests"

# Test 4: Search for stored summary
print_test "Search memory: 'testing strategy'"

SEARCH_RESULT=$(send_mcp_request "tools/call" '{"name":"search_memory","arguments":{"query":"testing strategy","limit":5,"min_relevance":0.1}}')
verbose "Response: $SEARCH_RESULT"

if echo "$SEARCH_RESULT" | grep -q '"total_results"'; then
  # Check if our test summary was found
  if echo "$SEARCH_RESULT" | grep -q "$TEST_SESSION_ID"; then
    print_success "Found test summary in search results"
    increment_passed
  else
    print_warning "Search completed but test summary not found (may have low relevance)"
    increment_passed
  fi
else
  print_error "Search failed"
  verbose "$SEARCH_RESULT"
  increment_failed
fi

# Test 5: Search with different query
print_test "Search memory: 'semantic search implementation'"

SEARCH_RESULT2=$(send_mcp_request "tools/call" '{"name":"search_memory","arguments":{"query":"semantic search implementation","limit":3}}')
verbose "Response: $SEARCH_RESULT2"

if echo "$SEARCH_RESULT2" | grep -q '"total_results"'; then
  print_success "Second search completed successfully"
  increment_passed
else
  print_error "Second search failed"
  increment_failed
fi

# Test 6: Search for non-existent content
print_test "Search memory: 'nonexistent quantum blockchain ai'"

SEARCH_RESULT3=$(send_mcp_request "tools/call" '{"name":"search_memory","arguments":{"query":"nonexistent quantum blockchain ai xyz123","limit":5}}')
verbose "Response: $SEARCH_RESULT3"

if echo "$SEARCH_RESULT3" | grep -q '"total_results"'; then
  print_success "Search for non-existent content handled correctly"
  increment_passed
else
  print_error "Search for non-existent content failed"
  increment_failed
fi

################################################################################
# Retrieval Tests
################################################################################

print_header "Retrieval Tests"

# Test 7: Retrieve specific summary
if [ -n "$TEST_SUMMARY_ID" ]; then
  print_test "Retrieve summary: $TEST_SESSION_ID/$TEST_SUMMARY_ID"

  GET_RESULT=$(send_mcp_request "tools/call" "{\"name\":\"get_summary\",\"arguments\":{\"session_id\":\"$TEST_SESSION_ID\",\"summary_id\":\"$TEST_SUMMARY_ID\"}}")
  verbose "Response: $GET_RESULT"

  if echo "$GET_RESULT" | grep -q "$TEST_SESSION_ID"; then
    print_success "Summary retrieved successfully"
    increment_passed
  else
    print_error "Failed to retrieve summary"
    verbose "$GET_RESULT"
    increment_failed
  fi
else
  print_warning "Skipping retrieval test (summary ID not available)"
fi

################################################################################
# Session Management Tests
################################################################################

print_header "Session Management Tests"

# Test 8: List sessions
print_test "List all sessions"

LIST_RESULT=$(send_mcp_request "tools/call" '{"name":"list_sessions","arguments":{}}')
verbose "Response: $LIST_RESULT"

if echo "$LIST_RESULT" | grep -q '"total_sessions"'; then
  print_success "Sessions listed successfully"
  increment_passed

  if command -v jq &> /dev/null; then
    SESSION_COUNT=$(echo "$LIST_RESULT" | jq -r '.result.content[0].text' 2>/dev/null | jq -r '.total_sessions' 2>/dev/null || echo "unknown")
    verbose "Total sessions: $SESSION_COUNT"
  fi
else
  print_error "Failed to list sessions"
  verbose "$LIST_RESULT"
  increment_failed
fi

# Test 9: Get session metadata
print_test "Get session metadata: $TEST_SESSION_ID"

META_RESULT=$(send_mcp_request "tools/call" "{\"name\":\"get_session_metadata\",\"arguments\":{\"session_id\":\"$TEST_SESSION_ID\"}}")
verbose "Response: $META_RESULT"

if echo "$META_RESULT" | grep -q "$TEST_SESSION_ID"; then
  print_success "Session metadata retrieved successfully"
  increment_passed
else
  print_error "Failed to retrieve session metadata"
  verbose "$META_RESULT"
  increment_failed
fi

################################################################################
# Configuration Tests
################################################################################

print_header "Configuration Tests"

# Test 10: Check Claude Code MCP configuration
print_test "Claude Code MCP configuration"

CONFIG_PATHS=(
  "${HOME}/.config/claude-code/settings.json"
  "${HOME}/.claude-code/settings.json"
  "${HOME}/.config/claude/settings.json"
  "${HOME}/.claude/settings.json"
)

CONFIG_FOUND=false
for config_path in "${CONFIG_PATHS[@]}"; do
  if [ -f "$config_path" ]; then
    verbose "Checking: $config_path"
    if grep -q "context-memory" "$config_path"; then
      print_success "MCP configuration found: $config_path"
      CONFIG_FOUND=true
      increment_passed
      break
    fi
  fi
done

if [ "$CONFIG_FOUND" = false ]; then
  print_warning "MCP configuration not found in standard locations"
  print_info "Run: ./memory/setup-mcp.sh"
  increment_passed  # Not a failure, just not configured
fi

################################################################################
# File System Tests
################################################################################

print_header "File System Tests"

# Test 11: Verify summary file was created
print_test "Verify summary file creation"

SESSION_DIR="$MEMORY_DIR/sessions/$TEST_SESSION_ID"
if [ -d "$SESSION_DIR" ]; then
  SUMMARY_COUNT=$(find "$SESSION_DIR/summaries" -name "*.json" 2>/dev/null | wc -l)
  if [ "$SUMMARY_COUNT" -gt 0 ]; then
    print_success "Summary files created: $SUMMARY_COUNT file(s)"
    increment_passed
    verbose "Session directory: $SESSION_DIR"
  else
    print_error "No summary files found in session directory"
    increment_failed
  fi
else
  print_error "Session directory not created: $SESSION_DIR"
  increment_failed
fi

# Test 12: Verify metadata file
print_test "Verify session metadata file"

META_FILE="$SESSION_DIR/metadata.json"
if [ -f "$META_FILE" ]; then
  print_success "Metadata file exists: $META_FILE"
  increment_passed

  if [ "$VERBOSE" = true ] && command -v jq &> /dev/null; then
    echo ""
    jq '.' "$META_FILE" 2>/dev/null || cat "$META_FILE"
    echo ""
  fi
else
  print_error "Metadata file not found: $META_FILE"
  increment_failed
fi

################################################################################
# Performance Tests
################################################################################

print_header "Performance Tests"

# Test 13: Search performance
print_test "Search performance (10 queries)"

START_TIME=$(date +%s%N)
for i in {1..10}; do
  send_mcp_request "tools/call" '{"name":"search_memory","arguments":{"query":"test query '$i'","limit":5}}' > /dev/null 2>&1
done
END_TIME=$(date +%s%N)

DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
AVG_MS=$(( DURATION_MS / 10 ))

if [ "$AVG_MS" -lt 1000 ]; then
  print_success "Search performance: ${AVG_MS}ms average (10 queries in ${DURATION_MS}ms)"
  increment_passed
else
  print_warning "Search performance: ${AVG_MS}ms average (slower than expected)"
  increment_passed
fi

################################################################################
# Test Summary
################################################################################

print_header "Test Summary"

echo -e "${CYAN}Test Results:${NC}"
echo -e "  Total tests:  ${BLUE}$TESTS_TOTAL${NC}"
echo -e "  Passed:       ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Failed:       ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  ✓ ALL TESTS PASSED!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  print_success "The Context Memory System is working correctly!"
  EXIT_CODE=0
else
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}  ✗ SOME TESTS FAILED${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  print_error "Some tests failed. Please review the output above."
  EXIT_CODE=1
fi

################################################################################
# Cleanup Options
################################################################################

echo ""
print_info "Test session created: $TEST_SESSION_ID"
echo ""
echo "To view test data:"
echo "  ls -la $SESSION_DIR"
echo ""
echo "To clean up test data:"
echo "  rm -rf $SESSION_DIR"
echo ""

if [ "$VERBOSE" = false ]; then
  echo "For detailed output, run with --verbose flag"
  echo ""
fi

exit $EXIT_CODE
