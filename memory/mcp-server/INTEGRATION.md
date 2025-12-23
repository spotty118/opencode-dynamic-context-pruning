# Context Memory MCP Server - Integration Guide

This guide explains how to integrate the Context Memory MCP Server with Claude Code to enable persistent context across compactions and sessions.

## Overview

The Context Memory MCP Server provides:
- **Persistent Storage**: Saves conversation context before compaction
- **Semantic Search**: Find relevant past discussions and decisions
- **Session Continuity**: Resume sessions with knowledge of past work
- **Project Knowledge**: Build long-term understanding across sessions

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Claude Code                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │         Active Conversation Context              │   │
│  └──────────────────────────────────────────────────┘   │
│                         ↓                                │
│              (PreCompact Hook Triggered)                 │
│                         ↓                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │    Summarization Agent (summarize-context)       │   │
│  │    - Analyzes content being compacted            │   │
│  │    - Extracts key decisions and context          │   │
│  │    - Creates structured summary                  │   │
│  └──────────────────────────────────────────────────┘   │
│                         ↓                                │
└─────────────────────────────────────────────────────────┘
                          ↓
                  (MCP Tool: store_summary)
                          ↓
┌─────────────────────────────────────────────────────────┐
│          Context Memory MCP Server                       │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Storage Layer (~/.config/claude/dcp/memory/)    │   │
│  │  - Session summaries                             │   │
│  │  - Project knowledge                             │   │
│  │  - Embeddings (future)                           │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  Available Tools:                                        │
│  - search_memory: Semantic search                       │
│  - get_summary: Retrieve specific summary               │
│  - get_project_knowledge: Query project knowledge       │
│  - store_summary: Save new summary                      │
│  - list_sessions: Browse all sessions                   │
└─────────────────────────────────────────────────────────┘
                          ↑
                  (MCP Tool: search_memory)
                          ↑
┌─────────────────────────────────────────────────────────┐
│                    Claude Code                          │
│  "What did we decide about authentication?"             │
│                                                          │
│  [Uses search_memory tool to find relevant context]     │
│  [Retrieves past decision and rationale]                │
│  [Responds with context from previous session]          │
└─────────────────────────────────────────────────────────┘
```

## Installation

### Step 1: Build the MCP Server

```bash
cd memory/mcp-server
npm install
npm run build
```

This creates the compiled server in `dist/index.js`.

### Step 2: Configure Claude Code

Add the MCP server to your Claude Code configuration. The location depends on your platform:

**macOS/Linux:**
```bash
~/.config/claude/claude_desktop_config.json
```

**Windows:**
```
%APPDATA%\Claude\claude_desktop_config.json
```

**Configuration:**
```json
{
  "mcpServers": {
    "context-memory": {
      "command": "node",
      "args": [
        "/absolute/path/to/opencode-dynamic-context-pruning/memory/mcp-server/dist/index.js"
      ]
    }
  }
}
```

**Important**: Use absolute paths in the configuration!

### Step 3: Restart Claude Code

After updating the configuration, restart Claude Code to load the MCP server.

### Step 4: Verify Installation

In a Claude Code session, you can verify the server is loaded by asking:

```
Can you list the available MCP tools?
```

You should see tools like `search_memory`, `get_summary`, `store_summary`, etc.

## Usage Scenarios

### 1. Automatic Context Preservation (via PreCompact Hook)

When context is about to be compacted, the PreCompact hook can automatically:
1. Extract the content being removed
2. Generate a summary using the summarization agent
3. Store it via the MCP server

**Example Hook** (`hooks/pre-compact.sh`):

```bash
#!/bin/bash

SESSION_ID=${CLAUDE_SESSION_ID:-$(uuidgen)}
SUMMARY_FILE="/tmp/summary_${SESSION_ID}.json"

# Step 1: Invoke summarization agent to analyze content
echo "Generating summary for compaction..."
# (Agent generates summary.json)

# Step 2: Store via MCP server (if running in Claude Code context)
# The agent can directly call the store_summary tool
# Or we can use a helper script

echo "Summary saved for session: $SESSION_ID"
```

### 2. Manual Context Search

During a conversation, Claude can search past context:

**User:**
```
What did we discuss about the authentication system last week?
```

**Claude:**
```
Let me search our past conversations about authentication...

[Calls search_memory tool with query: "authentication system"]

Based on our previous discussion (Session abc123, Dec 16), we decided to
implement JWT-based authentication with refresh tokens. The key rationale
was to enable stateless auth for horizontal scaling.

Would you like me to retrieve the full implementation details?
```

### 3. Project Knowledge Queries

Ask about architectural decisions across all sessions:

**User:**
```
What are our coding conventions for error handling?
```

**Claude:**
```
[Calls get_project_knowledge tool with topic: "error handling"]

Based on patterns from 5 past sessions, our error handling conventions:
1. Always use custom error classes (src/errors/AppError.ts)
2. Async functions must use try/catch with proper logging
3. API errors return consistent JSON format
```

### 4. Session Continuity

When resuming work:

**User:**
```
Let's continue working on the authentication system
```

**Claude:**
```
[Searches memory for "authentication system" in this session]

I see we previously implemented JWT authentication with refresh tokens
and integrated Redis for token storage. Last time we completed the core
auth routes but had pending tasks for rate limiting and 2FA.

Should we start with implementing rate limiting?
```

## Integration Points

### PreCompact Hook Integration

The MCP server integrates seamlessly with the PreCompact hook:

```bash
#!/bin/bash
# hooks/pre-compact.sh

# Set session ID
SESSION_ID=${CLAUDE_SESSION_ID:-$(cat ~/.config/claude/dcp/session_id 2>/dev/null || uuidgen)}

# Extract compacted content (implementation specific to your setup)
CONTENT=$(extract_compaction_content)

# Invoke summarization (Claude can call store_summary tool directly)
# Or use a helper script that interfaces with the MCP server

echo "Context preserved for session: $SESSION_ID"
```

### SessionStart Hook Integration

Load recent context when starting a session:

```bash
#!/bin/bash
# hooks/session-start.sh

SESSION_ID=${CLAUDE_SESSION_ID}

# Check if session has stored summaries
if [ -d "$HOME/.config/claude/dcp/memory/sessions/$SESSION_ID" ]; then
    echo "Loading session memory..."
    # Claude can use search_memory and get_summary tools to access past context
fi
```

### Agent Integration

The summarization agent can directly call MCP tools:

```markdown
# In summarize-context skill

## Task
1. Analyze the compacted content
2. Extract key information
3. Create structured summary
4. **Store the summary using store_summary tool**

## Implementation
After generating the summary, call:

```json
store_summary({
  session_id: "current_session_id",
  summary: {
    timestamp: "2025-12-23T04:30:00Z",
    compaction_trigger: "auto",
    summary: {
      executive: "Summary text...",
      key_decisions: [...],
      ...
    }
  }
})
```

## Advanced Features

### Vector Embeddings (Future)

The server is designed to support vector embeddings for better semantic search:

1. **Generate embeddings** when storing summaries
2. **Store vectors** in a vector database (ChromaDB, FAISS)
3. **Search by similarity** instead of text matching

To enable this, update the `calculateTextSimilarity` function to use actual embeddings.

### Cross-Project Knowledge

Store knowledge across multiple projects:

```typescript
// Project knowledge automatically aggregated
{
  "topic": "Authentication Patterns",
  "content": "JWT with refresh tokens is preferred...",
  "source_sessions": ["project_a_session_1", "project_b_session_2"],
  "confidence": 0.95
}
```

### Relevance Feedback

Improve search results based on usage:

```typescript
// Track which results users find helpful
// Adjust relevance scores over time
// Learn from user preferences
```

## Troubleshooting

### Server Not Starting

1. Check the path in `claude_desktop_config.json` is absolute
2. Verify Node.js is installed (`node --version`)
3. Check server logs (they go to stderr)

### Tools Not Available

1. Restart Claude Code after configuration changes
2. Check the config file syntax (valid JSON)
3. Verify the server process is running

### Summaries Not Storing

1. Check write permissions to `~/.config/claude/dcp/memory/`
2. Verify session_id is being passed correctly
3. Check server logs for errors

### Search Returns No Results

1. Verify summaries exist: `ls -la ~/.config/claude/dcp/memory/sessions/*/summaries/`
2. Try lowering `min_relevance` parameter
3. Search for broader terms

## Configuration Options

### Storage Location

By default, summaries are stored in:
```
~/.config/claude/dcp/memory/
```

To change this, modify `MEMORY_BASE_DIR` in `index.ts`:

```typescript
const MEMORY_BASE_DIR = path.join(
  process.env.DCP_MEMORY_DIR || path.join(homedir(), '.config', 'claude', 'dcp', 'memory')
);
```

Then set environment variable:
```json
{
  "mcpServers": {
    "context-memory": {
      "command": "node",
      "args": [...],
      "env": {
        "DCP_MEMORY_DIR": "/custom/path/to/memory"
      }
    }
  }
}
```

### Search Sensitivity

Adjust default relevance threshold in tool calls:

```typescript
// More permissive
search_memory({ query: "...", min_relevance: 0.1 })

// More strict
search_memory({ query: "...", min_relevance: 0.7 })
```

## Security Considerations

### Data Privacy

- Summaries are stored locally in your home directory
- No data is sent to external services (unless using embedding APIs)
- Sensitive information in summaries should be reviewed

### Access Control

- The MCP server runs with your user permissions
- Files are only accessible to your user account
- Consider encrypting sensitive project directories

### Session Isolation

- Each session has its own directory
- Sessions cannot access each other's data without explicit queries
- Use unique session IDs for isolation

## Performance

### Storage Growth

- Each summary is approximately 5-50 KB
- With 100 compactions: ~500 KB - 5 MB
- With 1000 compactions: ~5 MB - 50 MB

### Search Performance

- Text-based search: O(n) over all summaries
- With vector embeddings: O(log n) with proper indexing
- Typically fast for hundreds of summaries

### Optimization Tips

1. **Periodic cleanup**: Archive old sessions
2. **Limit search scope**: Use `session_id` parameter
3. **Increase relevance threshold**: Return fewer, better results
4. **Future: Vector indexing**: Much faster semantic search

## Next Steps

1. **Test the integration**: Store a test summary and search for it
2. **Integrate with PreCompact**: Automate summary generation
3. **Build project knowledge**: Let it accumulate over time
4. **Upgrade to vectors**: Add proper embedding support

## Resources

- [MCP Protocol Documentation](https://modelcontextprotocol.io)
- [Claude Code Documentation](https://docs.anthropic.com/claude/docs)
- [Project Repository](https://github.com/Tarquinen/opencode-dynamic-context-pruning)

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing documentation
- Review server logs for debugging
