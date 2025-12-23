# Agent-Based Context Window Features

This document describes the advanced agent-based features for extending Claude Code's context window through intelligent memory management and semantic retrieval.

## Overview

The context window system now includes **4 new agent-based features**:

1. **Vector Embeddings Module** - Semantic search with multiple providers
2. **Auto-Context Retrieval** - Proactive memory search when starting tasks
3. **Knowledge Extraction** - Build project knowledge graphs from conversation history
4. **Context-Aware Assistant** - Enhanced agent that automatically uses memory

## 1. Vector Embeddings Module

**Location**: `memory/mcp-server/embeddings.ts`

### Purpose

Upgrades the MCP server from basic text similarity to true semantic search using vector embeddings.

### Features

- **Multiple Providers**:
  - OpenAI (text-embedding-3-small/large)
  - Local models (sentence-transformers via Python)
  - Future: Anthropic embeddings API

- **Vector Operations**:
  - Cosine similarity
  - Euclidean distance
  - Dot product similarity
  - Batch processing

- **Auto-Detection**:
  - Automatically selects best available provider
  - Falls back gracefully if no provider available

### Usage

```typescript
import { generateEmbedding, searchVectors, detectBestProvider } from './embeddings';

// Auto-detect best provider
const config = await detectBestProvider();

// Generate embedding
const result = await generateEmbedding("How do we handle authentication?", config);
// { vector: [0.123, -0.456, ...], dimensions: 1536, model: "text-embedding-3-small" }

// Search similar vectors
const results = searchVectors(queryVector, storedVectors, 5, 0.7);
// [{ id: "summary_001", score: 0.89, metadata: {...} }, ...]
```

### Configuration

**OpenAI** (requires API key):
```bash
export OPENAI_API_KEY="sk-..."
```

**Local** (requires Python):
```bash
pip install sentence-transformers
```

### Integration with MCP Server

The MCP server can be upgraded to use embeddings:

1. Generate embeddings when storing summaries
2. Store vectors alongside summary JSON
3. Use vector search instead of text similarity
4. 10-100x better search accuracy

## 2. Auto-Context Retrieval Skill

**Location**: `skills/auto-context/SKILL.md`

### Purpose

Proactively searches conversation memory for relevant past context when starting a new task.

### When to Use

Automatically invoke when:
- User requests implementation of a new feature
- User asks to debug or fix an issue
- User wants to continue previous work
- Starting a complex task that might benefit from past context

### How It Works

1. **Extract Search Queries** - Analyze user request for topics, technologies, files
2. **Search Memory** - Query MCP server or search JSON files directly
3. **Analyze Context** - Score relevance, extract insights
4. **Generate Report** - Structured markdown with recommendations

### Example Output

```markdown
# Auto-Context Report

## Current Task
Add rate limiting to API endpoints

## Relevant Past Context

### High Relevance (9/10)

#### 2025-11-15 - API Middleware Implementation
**Topics**: express, middleware, authentication

**Key Decisions**:
- Used express middleware pattern for all API concerns
- Placed middleware in src/middleware/
- Applied middleware at route level, not globally

**Relevant Code**:
- File: src/middleware/auth.ts
- Pattern: Export middleware function, apply per-route

**Applicable to Current Task**:
Rate limiting should follow the same middleware pattern for consistency

## Recommendations

1. **Reuse Pattern**: Follow existing middleware structure
2. **Consider Files**: src/middleware/auth.ts as template
3. **Check Dependency**: See if express-rate-limit is already installed

## Action Items

- [ ] Review src/middleware/auth.ts for middleware pattern
- [ ] Check package.json for rate limiting libraries
- [ ] Apply at route level like other middleware
```

### Integration

Invoke via Task tool or automatically when Claude detects a task that might benefit from context.

## 3. Knowledge Extraction Agent

**Location**: `skills/extract-knowledge/SKILL.md`, `commands/extract-knowledge.md`

### Purpose

Analyzes all conversation summaries to extract:
- Architectural patterns and decisions
- Coding conventions and style guides
- Technology stack and library usage
- Common tasks and their solutions
- Anti-patterns to avoid

Builds a **Project Knowledge Graph** for long-term institutional knowledge.

### When to Use

- Periodically (weekly/monthly) to update knowledge graph
- After completing major features
- When asked "what patterns do we use?"
- Before onboarding new team members

### What It Extracts

#### 1. Architectural Patterns

```json
{
  "pattern": "React Context for global state",
  "category": "state_management",
  "confidence": 0.95,
  "frequency": 12,
  "when_to_use": "Global state needed across many components",
  "example_files": ["src/contexts/AuthContext.tsx"]
}
```

#### 2. Architectural Decision Records (ADRs)

```json
{
  "decision_id": "adr-001",
  "title": "Use React Query for data fetching",
  "context": "Needed robust data fetching with caching",
  "decision": "Adopted React Query",
  "rationale": [
    "Built-in caching reduces API calls",
    "Automatic background refetch",
    "Better loading/error state management"
  ],
  "alternatives_considered": [
    {"option": "SWR", "rejected_reason": "Less flexible cache config"},
    {"option": "Custom hooks", "rejected_reason": "Would need to rebuild caching"}
  ],
  "status": "accepted",
  "confidence": 0.90
}
```

#### 3. Coding Conventions

```json
{
  "naming": {
    "files": "kebab-case for components",
    "functions": "Verb-first (getUserData)",
    "components": "PascalCase",
    "confidence": 0.90
  },
  "organization": {
    "components": "src/components/[feature]/[Component].tsx",
    "utilities": "src/utils/[utility].ts",
    "confidence": 0.85
  }
}
```

#### 4. Common Tasks

```json
{
  "task": "Add new API endpoint",
  "frequency": 12,
  "pattern": {
    "steps": [
      "1. Define route in src/routes/",
      "2. Create controller in src/controllers/",
      "3. Add validation schema with zod"
    ],
    "files_typically_modified": ["src/routes/*.ts", "src/controllers/*.ts"]
  }
}
```

### Output

- **knowledge.json** - Machine-readable knowledge graph
- **KNOWLEDGE.md** - Human-readable documentation
- **Summary report** - Findings with confidence scores

### Usage

```bash
# Via slash command
/extract-knowledge

# Or invoke auto-context skill which uses the knowledge graph
```

### Knowledge Graph Location

```
~/.config/claude/dcp/memory/projects/project_[hash]/
├── knowledge.json          # Full knowledge graph
├── KNOWLEDGE.md           # Human-readable docs
└── patterns-report.json   # Detailed pattern analysis
```

## 4. Context-Aware Assistant Agent

**Location**: `agents/context-aware-assistant.json`

### Purpose

An enhanced agent that **automatically** uses conversation memory and project knowledge to provide better recommendations.

### Capabilities

- **Automatic Memory Search** - Searches memory when tasks start
- **Knowledge Graph Access** - Consults established patterns
- **Proactive Suggestions** - Recommends approaches consistent with past work
- **Consistency Checking** - Flags conflicts with existing architecture

### Behavior

When invoked for a task:

1. **Before responding**:
   - Search memory for related past work
   - Load project knowledge graph
   - Check for established patterns
   - Review past architectural decisions

2. **During implementation**:
   - Reference successful solutions from memory
   - Avoid repeating past mistakes
   - Maintain consistency with project conventions

3. **After completion**:
   - Extract new patterns learned
   - Update knowledge graph

### Example Usage

**User**: "Add user authentication to the API"

**Context-Aware Assistant**:
```
I found that we implemented JWT authentication 2 months ago (session_abc123).
The project knowledge graph shows JWT with refresh tokens is our established
pattern. I recommend following the same approach for consistency:

1. Create middleware in src/middleware/auth.ts (following existing pattern)
2. Use same token storage approach (httpOnly cookies)
3. Follow project convention of auth logic in src/auth/

This approach:
✓ Matches existing auth middleware
✓ Uses the same token storage pattern
✓ Avoids issues we encountered before (CORS with Authorization header)

Shall I proceed with this approach?
```

### Configuration

```json
{
  "memory_search_threshold": 0.7,
  "max_context_results": 5,
  "pattern_confidence_threshold": 0.75,
  "auto_load_knowledge_graph": true
}
```

### Integration

Invoke via Task tool when you want enhanced context awareness:

```
Use Task tool with agent type "context-aware-assistant" for the following task:
[user request]
```

The agent will automatically leverage memory and knowledge graph.

## 5. Pattern Detection Utility

**Location**: `memory/scripts/pattern-detector.sh`

### Purpose

Standalone utility to analyze conversation summaries and detect patterns. Can be run from command line or called by agents.

### Features

- Detects architectural patterns (state management, API design, auth, etc.)
- Identifies naming conventions (kebab-case, PascalCase, etc.)
- Discovers technology stack
- Outputs JSON, Markdown, or text format

### Usage

```bash
# Detect all patterns
./memory/scripts/pattern-detector.sh

# Detect architectural patterns only
./pattern-detector.sh --type architectural

# Analyze recent sessions
./pattern-detector.sh --scope recent --min-occurrences 2

# Generate markdown report
./pattern-detector.sh --output markdown

# Customize thresholds
./pattern-detector.sh --min-occurrences 3 --min-confidence 0.7
```

### Example Output (JSON)

```json
{
  "analysis_timestamp": "2025-12-23T10:30:00Z",
  "patterns": {
    "architectural": [
      {
        "pattern": "state_management_react_context",
        "occurrences": 12,
        "confidence": 0.92
      },
      {
        "pattern": "auth_jwt",
        "occurrences": 8,
        "confidence": 0.85
      },
      {
        "pattern": "api_rest",
        "occurrences": 15,
        "confidence": 0.95
      }
    ]
  }
}
```

### Patterns Detected

**Architectural**:
- State Management (React Context, Redux, Zustand)
- API Design (REST, GraphQL)
- Authentication (JWT, Sessions)
- Databases (PostgreSQL, MongoDB)
- Testing (Jest, Vitest)
- Styling (Tailwind, CSS Modules)

**Naming Conventions**:
- File naming (kebab-case, camelCase, PascalCase)
- Function naming patterns
- Component naming

**Technology Stack**:
- Frontend frameworks (React, Vue, Angular)
- Backend frameworks (Express, Fastify)
- Languages (TypeScript, Python)

## Integration Across Features

These features work together:

```
┌─────────────────────────────────────────────────────────┐
│                    User Request                          │
│              "Add authentication to API"                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Auto-Context Retrieval Skill                   │
│  • Searches memory for "authentication" and "API"       │
│  • Finds past JWT implementation                        │
│  • Loads relevant summaries                             │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Knowledge Extraction Agent                     │
│  • Loads project knowledge graph                        │
│  • Confirms JWT is established pattern                  │
│  • Provides conventions and file structure              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│         Context-Aware Assistant Agent                    │
│  • Synthesizes memory + knowledge                       │
│  • Proposes solution consistent with past               │
│  • References specific files and decisions              │
│  • Implements with full context                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Implementation Complete                     │
│  • New patterns extracted                               │
│  • Knowledge graph updated                              │
│  • Memory stored for future sessions                    │
└─────────────────────────────────────────────────────────┘
```

## Setup and Installation

### 1. Install Memory System (if not already done)

```bash
cd memory
./install.sh
./setup-mcp.sh
```

### 2. Enable Vector Embeddings (Optional but Recommended)

**Option A: OpenAI**
```bash
export OPENAI_API_KEY="sk-..."
```

**Option B: Local**
```bash
pip install sentence-transformers
```

### 3. Test the System

```bash
# Test memory system
./memory/test-memory-system.sh

# Test pattern detection
./memory/scripts/pattern-detector.sh --output markdown
```

### 4. Generate Initial Knowledge Graph

After accumulating some conversation summaries:

```bash
# Via Claude Code
/extract-knowledge
```

## Best Practices

### When to Use Each Feature

1. **Auto-Context Retrieval**:
   - Start of each significant task
   - When user mentions past work
   - Before making architectural decisions

2. **Knowledge Extraction**:
   - Weekly or after major milestones
   - Before team onboarding
   - When documenting project

3. **Context-Aware Assistant**:
   - Complex features requiring consistency
   - Long-term projects with established patterns
   - When you want proactive memory usage

4. **Pattern Detection**:
   - Curious about project conventions
   - Validating consistency
   - Generating reports for team

### Memory Hygiene

- **Run PreCompact analysis** - Ensures quality summaries
- **Periodic knowledge extraction** - Keeps knowledge graph current
- **Review auto-context results** - Validate relevance of retrieved context
- **Update patterns** - Mark outdated patterns in knowledge graph

## Performance

- **Auto-Context Search**: ~5-20 seconds
- **Knowledge Extraction**: ~30-120 seconds (depends on summary count)
- **Pattern Detection**: ~10-30 seconds
- **Vector Embeddings**: ~1-2 seconds per embedding (OpenAI), ~5-10 seconds (local)

## Future Enhancements

### Phase 3 (Planned)

- [ ] **Hybrid Search** - Combine vector + keyword search
- [ ] **Cross-Project Patterns** - Learn from multiple projects
- [ ] **Auto-Suggest Context** - Proactively offer relevant context during conversation
- [ ] **Pattern Evolution Tracking** - Track how patterns change over time
- [ ] **Conflict Detection** - Warn when new code conflicts with established patterns
- [ ] **Memory Consolidation** - Merge related summaries to reduce storage

### Advanced Features

- [ ] **Knowledge Graph Visualization** - Visual representation of patterns and connections
- [ ] **Team Knowledge Sharing** - Export/import knowledge graphs
- [ ] **ADR Generation** - Auto-generate architectural decision records
- [ ] **Code Convention Linting** - Validate code against detected conventions
- [ ] **Pattern Templates** - Generate code scaffolding from patterns

## Troubleshooting

### Auto-Context Not Finding Results

- **Check**: Do you have conversation summaries? (need at least 3-5)
- **Check**: Is memory system installed? (`ls ~/.config/claude/dcp/memory`)
- **Try**: Lower min_relevance threshold
- **Try**: Use broader search terms

### Knowledge Extraction Returns Low Confidence

- **Reason**: Not enough data (need 10+ summaries for reliable patterns)
- **Solution**: Continue working, let more summaries accumulate
- **Workaround**: Lower min_pattern_occurrences to 2

### Vector Embeddings Not Available

- **Check**: OpenAI API key set? (`echo $OPENAI_API_KEY`)
- **Check**: Python installed? (`python3 --version`)
- **Check**: sentence-transformers installed? (`pip list | grep sentence`)
- **Fallback**: System works fine with text similarity (just less accurate)

### Pattern Detector Shows No Patterns

- **Reason**: Not enough variation in summaries
- **Check**: Do summaries contain technical details? (not just "fixed bug")
- **Solution**: Ensure summarize-context skill extracts code snippets and decisions

## Version History

- **v2.3.0** (2025-12-23): Added agent-based features
  - Vector embeddings module
  - Auto-context retrieval skill
  - Knowledge extraction agent
  - Context-aware assistant agent
  - Pattern detection utility

- **v2.2.0** (2025-12-20): Enhanced Context Memory System
  - MCP server implementation
  - Persistent memory storage
  - Context summarization skill

- **v2.1.0** (2025-12-15): PreCompact hook integration
  - Agent-based compaction analysis

- **v2.0.0** (2025-12-01): Claude Code adaptation
  - Initial DCP plugin for Claude Code