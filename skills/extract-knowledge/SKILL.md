---
name: extract-knowledge
description: Analyzes conversation summaries and code to extract architectural patterns, conventions, and project knowledge. Use periodically to build the project knowledge graph or when asked to document project patterns.
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Task"]
---

# Knowledge Extraction Skill

## When to Use This Skill

Invoke this skill when:
- User asks to "document project patterns" or "extract knowledge"
- You want to build/update the project knowledge base
- After completing major features (to capture architectural decisions)
- Periodically (e.g., once per day/week) to accumulate knowledge
- When onboarding new team members (generate knowledge report)
- User asks "what are our coding conventions?" or "what patterns do we use?"

## Purpose

This skill analyzes:
1. **Conversation summaries** - Past sessions and compaction summaries
2. **Code patterns** - Recurring code structures and conventions
3. **Architectural decisions** - Why things are built certain ways
4. **Technology stack** - What libraries/frameworks are used and how

It builds a **Project Knowledge Graph** that captures institutional knowledge about the codebase.

## How This Skill Works

You will spawn a specialized agent using the Task tool to analyze summaries and code, extract patterns, and build/update the knowledge graph.

### Agent Instructions Template

```
You are a Knowledge Extraction agent. Your task is to analyze conversation summaries and code to extract architectural patterns, conventions, and project knowledge.

## Analysis Tasks

### 1. Load All Conversation Summaries

Search for all summary files:
```bash
find ~/.config/claude/dcp/memory/sessions -name "*.json" -type f | sort
```

For each summary file, extract:
```bash
cat [summary_file] | jq '{
  timestamp,
  topics: .summary.topics,
  key_decisions: .summary.key_decisions,
  files_modified: .summary.files_modified,
  code_snippets: .summary.code_snippets
}'
```

### 2. Pattern Detection

#### Architectural Patterns

Look for recurring architectural decisions across summaries:

**State Management**:
- What state management approach is used? (Redux, Context, MobX, Zustand)
- Where is state defined?
- How is state updated?
- Pattern frequency: X sessions

**API Design**:
- REST, GraphQL, RPC?
- How are routes/endpoints defined?
- How are requests authenticated?
- Error handling patterns?
- Pattern frequency: X sessions

**Data Fetching**:
- What libraries? (fetch, axios, react-query, SWR)
- How are loading states handled?
- How are errors handled?
- Caching strategy?
- Pattern frequency: X sessions

**Authentication**:
- What auth strategy? (JWT, sessions, OAuth)
- Where are tokens stored?
- How is protected access enforced?
- Pattern frequency: X sessions

**Testing**:
- What test framework? (Jest, Vitest, Playwright)
- What's tested? (unit, integration, e2e)
- Test file naming convention?
- Pattern frequency: X sessions

**Styling**:
- CSS approach? (CSS modules, styled-components, Tailwind)
- Theme management?
- Responsive design approach?
- Pattern frequency: X sessions

#### Code Conventions

Extract from code snippets in summaries:

**Naming Conventions**:
- File naming: camelCase, PascalCase, kebab-case?
- Function naming: verbs (getUserData, fetchPosts)?
- Component naming: PascalCase?
- Constant naming: UPPER_SNAKE_CASE?

**File Organization**:
- Directory structure patterns
- Where do components go?
- Where do utilities go?
- Where are types/interfaces defined?

**Import Patterns**:
- Path aliases used? (@/, ~/)
- Import order conventions?
- Named vs default exports?

**Error Handling**:
- try/catch patterns
- Error boundary usage
- Error logging approach

**Code Style**:
- Function vs class components (React)?
- Arrow functions vs function declarations?
- Async/await vs promises?
- Optional chaining usage?

### 3. Technology Stack Analysis

Identify technologies and how they're used:

**Core Technologies**:
```json
{
  "frontend": {
    "framework": "React",
    "version": "18.x",
    "usage": "Primary UI framework",
    "confidence": 0.95,
    "evidence_count": 23
  },
  "backend": {
    "framework": "Express",
    "version": "4.x",
    "usage": "API server",
    "confidence": 0.90,
    "evidence_count": 15
  }
}
```

**Libraries**:
```json
{
  "react-query": {
    "purpose": "Data fetching and caching",
    "usage_pattern": "Used for all API calls",
    "confidence": 0.85,
    "evidence_count": 12
  },
  "zod": {
    "purpose": "Schema validation",
    "usage_pattern": "Validate API responses and form inputs",
    "confidence": 0.80,
    "evidence_count": 8
  }
}
```

### 4. Architectural Decision Records (ADRs)

Extract key decisions that shaped the project:

For each significant decision found in summaries:

```json
{
  "decision_id": "adr-001",
  "date": "2025-12-15",
  "title": "Use React Query for data fetching",
  "context": "Needed robust data fetching with caching and automatic refetch",
  "decision": "Adopted React Query instead of custom fetch hooks",
  "rationale": [
    "Built-in caching reduces API calls",
    "Automatic background refetch keeps data fresh",
    "Better loading and error state management",
    "Well-maintained library with good TypeScript support"
  ],
  "alternatives_considered": [
    {
      "option": "SWR",
      "rejected_reason": "Less flexible cache configuration"
    },
    {
      "option": "Custom hooks with fetch",
      "rejected_reason": "Would need to rebuild caching logic"
    }
  ],
  "consequences": [
    "All new API calls should use React Query",
    "Need to configure query client in app root",
    "Team needs to learn React Query patterns"
  ],
  "status": "accepted",
  "confidence": 0.90,
  "source_sessions": ["session_abc123", "session_def456"]
}
```

### 5. Common Tasks and Solutions

Extract recurring tasks and how they're solved:

**Adding a New API Endpoint**:
```json
{
  "task": "Add new API endpoint",
  "frequency": 12,
  "pattern": {
    "steps": [
      "1. Define route in src/routes/",
      "2. Create controller in src/controllers/",
      "3. Add validation schema with zod",
      "4. Update API types in src/types/api.ts",
      "5. Add tests in src/routes/__tests__/"
    ],
    "files_typically_modified": [
      "src/routes/*.ts",
      "src/controllers/*.ts",
      "src/types/api.ts"
    ],
    "common_patterns": [
      "Use async/await for database calls",
      "Return consistent error format",
      "Validate input with zod schema"
    ]
  },
  "examples": [
    "session_abc123/compact_002",
    "session_def456/compact_005"
  ]
}
```

### 6. Code Smells and Anti-Patterns

Identify patterns to avoid:

```json
{
  "anti_pattern": "Direct DOM manipulation in React",
  "occurrences": 2,
  "problem": "Bypasses React's virtual DOM",
  "better_approach": "Use refs or state",
  "status": "resolved_in_later_sessions",
  "notes": "Early sessions had this, later corrected"
}
```

### 7. Generate Knowledge Graph

Combine all extracted information into a structured knowledge graph:

```json
{
  "project_id": "[hash of project path]",
  "last_updated": "2025-12-23T10:30:00Z",
  "total_sessions_analyzed": 15,
  "total_summaries_analyzed": 45,
  "confidence_threshold": 0.7,

  "architecture": {
    "patterns": [
      {
        "category": "state_management",
        "pattern": "React Context for global state",
        "confidence": 0.95,
        "frequency": 12,
        "description": "Use React Context API for theme and auth state",
        "when_to_use": "Global state needed across many components",
        "example_files": ["src/contexts/AuthContext.tsx"],
        "source_sessions": ["session_1", "session_2"]
      }
    ],
    "decisions": [
      /* ADRs from step 4 */
    ]
  },

  "technology_stack": {
    "frontend": {
      /* From step 3 */
    },
    "backend": {
      /* From step 3 */
    },
    "libraries": {
      /* From step 3 */
    }
  },

  "conventions": {
    "naming": {
      "files": "kebab-case for components, camelCase for utilities",
      "functions": "Verb-first (getUserData, not dataOfUser)",
      "components": "PascalCase",
      "constants": "UPPER_SNAKE_CASE",
      "confidence": 0.90
    },
    "organization": {
      "components": "src/components/[feature]/[Component].tsx",
      "utilities": "src/utils/[utility].ts",
      "types": "src/types/[domain].ts",
      "tests": "src/__tests__/ or colocated *.test.ts",
      "confidence": 0.85
    },
    "style": {
      "functions": "Arrow functions preferred",
      "async": "async/await over .then()",
      "imports": "Named imports over default",
      "confidence": 0.80
    }
  },

  "common_tasks": [
    /* From step 5 */
  ],

  "anti_patterns": [
    /* From step 6 */
  ],

  "metadata": {
    "total_files_analyzed": 150,
    "most_modified_files": [
      {"path": "src/api/routes.ts", "modifications": 8},
      {"path": "src/components/UserProfile.tsx", "modifications": 6}
    ],
    "most_discussed_topics": [
      {"topic": "authentication", "occurrences": 15},
      {"topic": "api", "occurrences": 12},
      {"topic": "performance", "occurrences": 8}
    ]
  }
}
```

### 8. Save Knowledge Graph

Save to the project knowledge directory:

```bash
# Determine project hash
PROJECT_PATH=$(pwd)
PROJECT_HASH=$(echo -n "$PROJECT_PATH" | md5sum | cut -d' ' -f1)

# Create knowledge directory
KNOWLEDGE_DIR="$HOME/.config/claude/dcp/memory/projects/project_$PROJECT_HASH"
mkdir -p "$KNOWLEDGE_DIR"

# Save knowledge graph
cat > "$KNOWLEDGE_DIR/knowledge.json" <<EOF
[knowledge graph JSON from step 7]
EOF

# Also save human-readable markdown version
cat > "$KNOWLEDGE_DIR/KNOWLEDGE.md" <<EOF
# Project Knowledge Graph
Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Architecture Patterns
[formatted patterns]

## Technology Stack
[formatted stack]

## Coding Conventions
[formatted conventions]

## Common Tasks
[formatted tasks]

## Architectural Decisions
[formatted ADRs]
EOF
```

### 9. Generate Summary Report

Create a report for the user:

```markdown
# Knowledge Extraction Report

## Summary

- **Summaries Analyzed**: 45 from 15 sessions
- **Date Range**: 2025-10-01 to 2025-12-23
- **Patterns Identified**: 23
- **Technologies Documented**: 15
- **Architectural Decisions**: 8

## Key Findings

### Established Patterns (Confidence > 90%)

1. **State Management**: React Context API
   - Used in 12 sessions
   - Files: src/contexts/
   - Recommendation: Continue using for global state

2. **API Design**: REST with Express
   - Used in 15 sessions
   - Pattern: routes → controllers → services
   - Recommendation: Follow established structure

### Emerging Patterns (Confidence 70-90%)

1. **Data Validation**: Zod schemas
   - Used in 8 sessions
   - Growing adoption
   - Recommendation: Standardize on this

### Technology Stack

**Frontend**:
- React 18.x (95% confidence)
- TypeScript (90% confidence)
- React Query for data fetching (85% confidence)

**Backend**:
- Express 4.x (90% confidence)
- PostgreSQL (85% confidence)

### Conventions

**Naming**:
- Files: kebab-case ✓
- Components: PascalCase ✓
- Functions: camelCase with verb-first ✓

**Structure**:
- Feature-based organization in src/
- Colocated tests preferred

### Anti-Patterns to Avoid

1. Direct DOM manipulation (found in 2 early sessions, now avoided)
2. Inline styles (migrated to Tailwind)

## Recommendations

1. ✅ **Keep Using**: React Context, React Query, Zod
2. 🤔 **Consider Standardizing**: Error logging, API error format
3. ❌ **Avoid**: Direct DOM manipulation, inline styles
4. 📝 **Document Better**: Database schema decisions, API versioning

## Knowledge Graph

Saved to: `~/.config/claude/dcp/memory/projects/project_[hash]/`
- `knowledge.json` - Machine-readable
- `KNOWLEDGE.md` - Human-readable

## Next Steps

- Use knowledge graph for auto-context retrieval
- Reference ADRs when making similar decisions
- Update knowledge graph monthly or after major features
- Share KNOWLEDGE.md with team
```

## Advanced Analysis

### Pattern Evolution Tracking

Track how patterns change over time:

```json
{
  "pattern": "state_management",
  "evolution": [
    {
      "period": "2025-10-01 to 2025-10-15",
      "approach": "useState hooks only",
      "sessions": 3
    },
    {
      "period": "2025-10-16 to 2025-11-30",
      "approach": "Introduced Context API for auth",
      "sessions": 7,
      "reason": "Prop drilling became unmaintainable"
    },
    {
      "period": "2025-12-01 to 2025-12-23",
      "approach": "Context API for all global state",
      "sessions": 5,
      "reason": "Standardized on successful auth pattern"
    }
  ],
  "current_recommendation": "Use Context API for global state",
  "stability": "high"
}
```

### Cross-Project Patterns

If multiple projects are analyzed:

```json
{
  "pattern": "api_authentication",
  "approach": "JWT with refresh tokens",
  "seen_in_projects": 3,
  "consistency": "high",
  "notes": "This appears to be a personal/team preference across projects"
}
```

## Error Handling

**No Summaries Found**:
```markdown
# Knowledge Extraction Report

## Status

No conversation summaries found.

**Possible Reasons**:
- Memory system not set up
- No compactions have occurred yet
- Memory directory empty

**To generate knowledge**:
1. Work on the project for a session
2. Let context compaction occur (or use `/compact`)
3. Run summarize-context skill after compaction
4. Re-run this knowledge extraction skill

For now, knowledge graph cannot be built.
```

**Partial Data**:
```markdown
## Warning

Only X summaries found. Knowledge graph will have low confidence.

**Recommendation**: Wait until at least 10 summaries exist for reliable patterns.

Generating preliminary knowledge graph with low confidence scores...
```

## Integration

This skill can be:
1. **Manually invoked** - `/extract-knowledge` command
2. **Scheduled** - Run weekly via cron/scheduler
3. **Triggered** - After major features or milestones
4. **OnBoarding** - Generate knowledge report for new team members

The knowledge graph is then used by:
- `auto-context` skill for better search results
- `precompact` skill for preserving important patterns
- New sessions for understanding project conventions

## Performance

- Fast analysis: < 30 seconds for 50 summaries
- Incremental updates: Only process new summaries
- Caching: Store intermediate results

## Output Files

- `knowledge.json` - Machine-readable knowledge graph
- `KNOWLEDGE.md` - Human-readable documentation
- `patterns-report.json` - Detailed pattern analysis
- `adr/` - Individual ADR files (optional)
```

Now let me create the corresponding slash command:

