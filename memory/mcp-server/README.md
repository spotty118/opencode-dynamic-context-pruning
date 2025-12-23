# Context Memory MCP Server

A Model Context Protocol (MCP) server that provides semantic search and retrieval tools for conversation context summaries in Claude Code.

## Features

- **Semantic Search**: Search across all past conversation summaries using text similarity
- **Summary Storage**: Store and retrieve detailed compaction summaries
- **Project Knowledge**: Query project-level knowledge across sessions
- **Session Management**: Track and manage multiple conversation sessions
- **Vector Search Ready**: Architecture supports future vector embeddings integration

## Installation

```bash
cd memory/mcp-server
npm install
npm run build
```

## Usage

### Running the Server

The MCP server communicates via stdio and is typically launched by Claude Code:

```bash
node dist/index.js
```

### Configuration in Claude Code

Add to your Claude Code MCP configuration:

```json
{
  "mcpServers": {
    "context-memory": {
      "command": "node",
      "args": ["/path/to/opencode-dynamic-context-pruning/memory/mcp-server/dist/index.js"]
    }
  }
}
```

## Available Tools

### 1. `search_memory`

Search past conversation context using semantic similarity.

**Parameters:**
- `query` (string, required): Search query describing what you're looking for
- `limit` (number, optional): Maximum results to return (default: 5)
- `session_id` (string, optional): Search within specific session only
- `min_relevance` (number, optional): Minimum relevance score 0-1 (default: 0.3)

**Example:**
```typescript
{
  "query": "authentication JWT implementation",
  "limit": 3,
  "min_relevance": 0.5
}
```

**Response:**
```json
{
  "query": "authentication JWT implementation",
  "total_results": 2,
  "results": [
    {
      "session_id": "session_abc123",
      "summary_id": "compact_2025-12-23T04-30-00-000Z",
      "relevance": "0.850",
      "timestamp": "2025-12-23T04:30:00Z",
      "snippet": "Implemented JWT authentication system with refresh tokens...",
      "topics": ["authentication", "jwt", "security"],
      "key_decisions": 3,
      "files_modified": 5
    }
  ]
}
```

### 2. `get_summary`

Retrieve a specific summary by session and summary ID.

**Parameters:**
- `session_id` (string, required): Session identifier
- `summary_id` (string, required): Summary identifier

**Example:**
```typescript
{
  "session_id": "session_abc123",
  "summary_id": "compact_2025-12-23T04-30-00-000Z"
}
```

**Response:**
Full `CompactionSummary` object with executive summary, key decisions, files modified, code snippets, topics, tasks, and embeddings.

### 3. `get_project_knowledge`

Query project-level knowledge base.

**Parameters:**
- `project_id` (string, optional): Specific project ID
- `topic` (string, optional): Filter by topic (e.g., "authentication", "caching")

**Example:**
```typescript
{
  "topic": "authentication"
}
```

**Response:**
```json
{
  "total_items": 3,
  "knowledge": [
    {
      "topic": "Authentication Strategy",
      "content": "Use JWT with refresh tokens for stateless auth",
      "source_sessions": ["session_abc123", "session_def456"],
      "confidence": 0.95,
      "last_updated": "2025-12-23T04:30:00Z"
    }
  ]
}
```

### 4. `store_summary`

Store a new compaction summary (typically called by PreCompact hook).

**Parameters:**
- `session_id` (string, required): Current session ID
- `summary` (object, required): Compaction summary data

**Example:**
```typescript
{
  "session_id": "session_abc123",
  "summary": {
    "timestamp": "2025-12-23T04:30:00Z",
    "compaction_trigger": "auto",
    "token_count_before": 180000,
    "token_count_after": 120000,
    "summary": {
      "executive": "Implemented user authentication...",
      "key_decisions": [...],
      "files_modified": [...],
      "code_snippets": [...],
      "topics": ["authentication", "jwt"],
      "tasks_completed": ["Implement JWT"],
      "tasks_pending": ["Add 2FA"]
    }
  }
}
```

**Response:**
```json
{
  "success": true,
  "summary_id": "compact_2025-12-23T04-30-00-000Z",
  "path": "/home/user/.config/claude/dcp/memory/sessions/session_abc123/summaries/compact_2025-12-23T04-30-00-000Z.json"
}
```

### 5. `get_session_metadata`

Get metadata about a specific session.

**Parameters:**
- `session_id` (string, required): Session identifier

**Response:**
```json
{
  "session_id": "session_abc123",
  "project_path": "/path/to/project",
  "created_at": "2025-12-23T02:00:00Z",
  "last_updated": "2025-12-23T04:30:00Z",
  "total_compactions": 3
}
```

### 6. `list_sessions`

List all available sessions with stored summaries.

**Response:**
```json
{
  "total_sessions": 5,
  "sessions": [
    {
      "session_id": "session_abc123",
      "metadata": {
        "session_id": "session_abc123",
        "created_at": "2025-12-23T02:00:00Z",
        "last_updated": "2025-12-23T04:30:00Z",
        "total_compactions": 3
      }
    }
  ]
}
```

## Storage Structure

Summaries are stored in:
```
~/.config/claude/dcp/memory/
├── sessions/
│   ├── session_abc123/
│   │   ├── summaries/
│   │   │   ├── compact_2025-12-23T04-30-00-000Z.json
│   │   │   └── compact_2025-12-23T05-15-00-000Z.json
│   │   └── metadata.json
│   └── session_def456/
│       └── ...
└── projects/
    └── project_hash_12345/
        ├── knowledge.json
        └── patterns.json
```

## Text Similarity Algorithm

Currently uses a hybrid approach:

1. **Jaccard Similarity**: Token set overlap between query and text
2. **Sequence Matching**: Boost for exact phrase matches
3. **Multi-field Search**: Searches across executive summary, topics, decisions, files, and tasks

**Future Enhancement**: Replace with proper vector embeddings using:
- Anthropic's embeddings API
- Local embedding models (sentence-transformers)
- Vector databases (ChromaDB, FAISS, Pinecone)

## Integration with PreCompact Hook

Example usage in `hooks/pre-compact.sh`:

```bash
#!/bin/bash
# Extract content being compacted
CONTENT=$(extract_compaction_content)

# Call summarization agent
SUMMARY=$(claude-agent summarize-context --input "$CONTENT")

# Store via MCP server
echo "$SUMMARY" | node dist/index.js store_summary \
  --session-id "$SESSION_ID" \
  --summary -
```

## Development

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Watch mode for development
npm run dev

# Clean build artifacts
npm run clean
```

## TypeScript Types

All types are defined in `index.ts`:

- `CompactionSummary`: Complete summary structure
- `Summary`: Core summary content
- `KeyDecision`: Decision with rationale and files
- `FileModification`: File changes with purpose
- `CodeSnippet`: Important code with context
- `SearchResult`: Search result with relevance
- `SessionMetadata`: Session tracking info
- `ProjectKnowledge`: Cross-session knowledge

## Error Handling

The server returns structured error responses:

```json
{
  "content": [
    {
      "type": "text",
      "text": "Error: Summary not found: session_abc123/compact_001"
    }
  ],
  "isError": true
}
```

## Future Enhancements

- [ ] Vector embeddings integration (Anthropic API or local models)
- [ ] Vector database backend (ChromaDB, FAISS)
- [ ] Hybrid search (semantic + keyword)
- [ ] Auto-summarization of project knowledge
- [ ] Cross-session pattern detection
- [ ] Relevance feedback and learning
- [ ] Export/import capabilities
- [ ] Summary deduplication
- [ ] Compression and archival

## License

MIT
