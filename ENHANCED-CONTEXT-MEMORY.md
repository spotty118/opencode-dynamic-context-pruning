# Enhanced Context Memory System for Claude Code

## Vision

Build a **hierarchical context management system** that extends Claude Code's effective memory beyond the token window by intelligently storing, compressing, and retrieving conversation history.

## The Problem

Current limitations:
- **Token Window Limits**: Claude has a finite context window (~200K tokens)
- **Compaction Loses Information**: When context is compacted, information is permanently lost
- **No Long-Term Memory**: Past conversations aren't accessible in new sessions
- **No Semantic Search**: Can't retrieve relevant past context based on current needs
- **Linear Context**: All context treated equally, no hierarchy

## The Solution: Multi-Tier Context Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     TIER 1: Active Window                   │
│                  (Claude's Direct Context)                  │
│                                                             │
│  • Current conversation (last ~50K tokens)                 │
│  • Full fidelity, all details preserved                    │
│  • Managed by Claude Code's native compaction              │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    (On compaction)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  TIER 2: Compressed History                 │
│              (Summarized Recent Conversations)              │
│                                                             │
│  • Agent-generated summaries of compacted content          │
│  • Key decisions, outcomes, and context preserved          │
│  • ~10x compression ratio                                  │
│  • Stored in session file                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
                  (Session persistence)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 TIER 3: Session Knowledge                   │
│                  (Persistent Session Store)                 │
│                                                             │
│  • Vector embeddings of all conversation segments          │
│  • Semantic search for relevant past context               │
│  • Retrievable summaries indexed by topic/file/task        │
│  • Persisted to ~/.config/claude/dcp/memory/               │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    (Cross-session)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                TIER 4: Project Knowledge Base               │
│              (Long-Term Persistent Memory)                  │
│                                                             │
│  • Project-level knowledge graph                           │
│  • Architectural decisions and rationale                   │
│  • Code patterns and conventions discovered                │
│  • Persistent across all sessions in project               │
└─────────────────────────────────────────────────────────────┘
```

## Architecture Components

### 1. PreCompact Context Capture

**Enhancement to existing PreCompact hook:**

```bash
# hooks/pre-compact.sh (enhanced)

# Before compaction, capture what's about to be removed
COMPACTED_CONTENT=$(extract_compacted_content "$TRANSCRIPT_PATH")

# Spawn summarization agent
spawn_agent "context-summarization" \
  --input "$COMPACTED_CONTENT" \
  --output "$CONFIG_DIR/memory/session_${SESSION_ID}/summaries/"
```

**Agent Task:**
- Read content being compacted
- Generate hierarchical summary:
  - Executive summary (1-2 paragraphs)
  - Key decisions made
  - Files modified and why
  - Important context to preserve
  - Relevant code snippets
- Create semantic embeddings
- Store in structured format

### 2. Persistent Memory Store

**Directory Structure:**
```
~/.config/claude/dcp/memory/
├── sessions/
│   ├── session_abc123/
│   │   ├── summaries/
│   │   │   ├── compact_001.json      # First compaction summary
│   │   │   ├── compact_002.json      # Second compaction
│   │   │   └── compact_003.json
│   │   ├── embeddings/
│   │   │   └── vectors.db            # Vector database
│   │   └── metadata.json             # Session info
│   └── session_def456/
│       └── ...
└── projects/
    ├── project_hash_12345/
    │   ├── knowledge_graph.json      # Architectural decisions
    │   ├── patterns.json             # Discovered patterns
    │   └── conventions.json          # Code conventions
    └── ...
```

**Summary Format (`compact_001.json`):**
```json
{
  "timestamp": "2025-12-23T04:30:00Z",
  "compaction_trigger": "auto",
  "token_count_before": 180000,
  "token_count_after": 120000,
  "summary": {
    "executive": "Implemented user authentication system with JWT tokens...",
    "key_decisions": [
      {
        "topic": "Authentication Strategy",
        "decision": "Use JWT with refresh tokens",
        "rationale": "Stateless auth for scalability",
        "files": ["src/auth/jwt.ts", "src/middleware/auth.ts"]
      }
    ],
    "files_modified": [
      {
        "path": "src/auth/jwt.ts",
        "action": "created",
        "purpose": "JWT token generation and validation"
      }
    ],
    "code_snippets": [
      {
        "file": "src/auth/jwt.ts",
        "function": "generateToken",
        "code": "export function generateToken(userId: string) {...}",
        "importance": "high"
      }
    ],
    "topics": ["authentication", "jwt", "security"],
    "tasks_completed": ["Implement JWT auth", "Add token refresh"],
    "tasks_pending": ["Add rate limiting", "Implement 2FA"]
  },
  "embeddings": {
    "summary_vector": [...],
    "topic_vectors": {...}
  },
  "original_message_range": [45, 120]
}
```

### 3. Semantic Retrieval System

**MCP Server for Context Retrieval:**

```typescript
// mcp-servers/context-memory/index.ts

export const memoryServer = {
  name: 'context-memory',
  tools: {
    // Search past context by semantic similarity
    search_memory: {
      description: "Search past conversation context by semantic similarity",
      parameters: {
        query: "string",           // What to search for
        limit: "number",           // How many results
        session: "string | null",  // Specific session or all
        min_relevance: "number"    // Threshold (0-1)
      },
      async execute({ query, limit = 5, session = null, min_relevance = 0.7 }) {
        // 1. Generate embedding for query
        const queryVector = await generateEmbedding(query)

        // 2. Search vector database
        const results = await vectorDB.search({
          vector: queryVector,
          limit,
          filter: session ? { session_id: session } : {},
          min_score: min_relevance
        })

        // 3. Return relevant summaries
        return results.map(r => ({
          summary: r.data.summary,
          relevance: r.score,
          session: r.metadata.session_id,
          timestamp: r.metadata.timestamp
        }))
      }
    },

    // Retrieve full summary by ID
    get_summary: {
      description: "Get full detailed summary from past compaction",
      parameters: {
        session_id: "string",
        summary_id: "string"
      },
      async execute({ session_id, summary_id }) {
        return await loadSummary(session_id, summary_id)
      }
    },

    // Get project knowledge
    get_project_knowledge: {
      description: "Retrieve project-level knowledge and decisions",
      parameters: {
        topic: "string | null"
      },
      async execute({ topic = null }) {
        const knowledge = await loadProjectKnowledge()
        if (topic) {
          return knowledge.filter(k => k.topics.includes(topic))
        }
        return knowledge
      }
    }
  }
}
```

### 4. Context Summarization Agent

**New Skill: `skills/summarize-context/SKILL.md`**

Invoked during PreCompact to create summaries:

```markdown
---
name: summarize-context
description: Creates hierarchical summaries of conversation context before compaction, preserving key decisions, code changes, and important context for future retrieval.
---

# Context Summarization Skill

## Purpose

When context is about to be compacted, this skill analyzes the content and creates
structured summaries that preserve critical information while drastically reducing
token usage.

## Input

- **Transcript segment**: Messages being compacted
- **Message range**: Start/end message IDs
- **Compaction reason**: manual/auto/size_limit

## Output

Structured JSON summary including:

### Executive Summary
1-2 paragraph overview of what happened in this segment

### Key Decisions
- Important architectural or implementation decisions
- Rationale for each decision
- Files affected

### Files Modified
- What files were created/modified/deleted
- Purpose of each change
- Important code snippets to preserve

### Topics Covered
- List of topics discussed
- Tags for semantic search

### Tasks
- Tasks completed in this segment
- Tasks still pending

### Important Context
- Anything else that would be valuable to recall later
- Error solutions discovered
- Patterns or conventions established

## Processing

1. Read the transcript segment
2. Analyze for:
   - Decision points
   - Code changes
   - Problem-solving
   - Important discussions
3. Extract and structure information
4. Generate embeddings for semantic search
5. Save to memory store
```

### 5. Smart Context Loading

**SessionStart Hook Enhancement:**

```bash
# hooks/session-start.sh (enhanced)

# On session start, check for past summaries
if [ -d "$MEMORY_DIR/sessions/$SESSION_ID" ]; then
    # Session continuation - load recent summaries

    echo "[DCP] Loading session memory..."

    # Load last 3 compaction summaries into context
    SUMMARIES=$(ls -t "$MEMORY_DIR/sessions/$SESSION_ID/summaries/" | head -3)

    # Create context file for Claude to read
    cat > "/tmp/session_${SESSION_ID}_context.md" <<EOF
# Session Context Loaded from Memory

You previously worked on this session. Here's what happened before:

$(for summary in $SUMMARIES; do
    echo "## Compaction $(basename $summary .json)"
    jq -r '.summary.executive' "$MEMORY_DIR/sessions/$SESSION_ID/summaries/$summary"
    echo ""
done)

For more details on any topic, use the 'search_memory' or 'get_summary' tools.
EOF

    echo "[DCP] Session memory loaded. Use 'search_memory' tool to retrieve specific context."
fi
```

### 6. Intelligent Context Retrieval

**During conversation, Claude can:**

```
User: What did we decide about authentication?

Claude: Let me search our past conversation...

[Uses search_memory tool]
search_memory({
  query: "authentication decision JWT tokens",
  limit: 3,
  min_relevance: 0.75
})

[Retrieves relevant summary]
Result:
- Session: abc123, Compaction 001
- Relevance: 0.92
- Summary: "Decided to use JWT tokens with refresh tokens for
           authentication. Rationale: stateless auth for scalability.
           Implemented in src/auth/jwt.ts"

Claude: Based on our previous discussion (from 2 hours ago, now compacted),
        we decided to use JWT tokens with refresh tokens for authentication.
        The rationale was to have stateless auth for better scalability.
        This was implemented in src/auth/jwt.ts.

        Would you like me to retrieve the full details or code snippets?
```

## Implementation Phases

### Phase 1: Summary Generation (Immediate)
- ✅ Enhance PreCompact hook to capture content
- ✅ Create context-summarization skill
- ✅ Store summaries in JSON format
- ✅ Basic session memory loading

**Timeline**: Can implement now with existing PreCompact infrastructure

### Phase 2: Semantic Search (Short-term)
- Add vector embedding generation
- Implement local vector database (ChromaDB, FAISS)
- Create MCP server for memory search
- Enable semantic retrieval

**Timeline**: 1-2 weeks

### Phase 3: Project Knowledge (Medium-term)
- Build knowledge graph across sessions
- Extract architectural patterns
- Persistent project-level memory
- Cross-session learning

**Timeline**: 1 month

### Phase 4: Advanced Features (Long-term)
- Auto-suggest relevant past context
- Proactive memory loading
- Memory consolidation
- Context prediction

**Timeline**: 2-3 months

## Benefits

**Immediate Value:**
- ✅ Never lose important context during compaction
- ✅ Retrieve past decisions and rationale
- ✅ Session continuity across restarts

**Long-term Value:**
- 🚀 Effective context window extends to gigabytes
- 🧠 Claude "remembers" entire project history
- 🔍 Semantic search across all past work
- 📚 Builds project knowledge base over time
- ⚡ Faster onboarding for new sessions

## Technical Stack

**Storage:**
- JSON files for summaries (human-readable, portable)
- SQLite for metadata and indexing
- Vector database (ChromaDB/FAISS) for embeddings

**Embeddings:**
- Use Anthropic's embeddings API (when available)
- Or local embedding model (sentence-transformers)

**Retrieval:**
- Semantic search via vector similarity
- Keyword search via full-text indexing
- Hybrid search combining both

**Integration:**
- MCP server for tool access
- PreCompact/SessionStart hooks for automation
- Agent-based summarization

## Example Usage Scenarios

### Scenario 1: Resuming After Compaction
```
User: What was the bug we fixed earlier?

Claude: [searches memory]
        Earlier in this session (now compacted), we fixed a race condition
        in the authentication middleware where tokens weren't being validated
        properly. The fix was to add proper async/await handling.

        Would you like me to retrieve the code snippet?
```

### Scenario 2: Cross-Session Recall
```
User: How did we implement caching last week?

Claude: [searches across sessions]
        In session from Dec 16, we implemented Redis caching for API responses.
        Key decision: Use TTL of 5 minutes for frequently accessed endpoints.
        Code is in src/cache/redis.ts.

        Would you like me to load the full implementation details?
```

### Scenario 3: Project Knowledge Query
```
User: What are our coding conventions for error handling?

Claude: [queries project knowledge]
        Based on past conversations, our error handling conventions:
        1. Always use custom error classes (src/errors/AppError.ts)
        2. Async functions must use try/catch with proper logging
        3. API errors return consistent JSON format

        These patterns were established across 5 sessions.
```

## Next Steps

Would you like me to:
1. **Start with Phase 1**: Implement summary generation and basic storage?
2. **Build MCP server**: Create the semantic search server first?
3. **Full implementation**: Build the complete multi-tier system?

This system would transform Claude Code from having ephemeral context to having
true long-term project memory! 🧠
