---
name: auto-context
description: Proactively searches conversation memory for relevant past context when starting a new task. Use when beginning work on features, debugging issues, or continuing previous work to retrieve relevant decisions, patterns, and insights.
allowed-tools: ["Read", "Bash", "Task"]
---

# Auto-Context Retrieval Skill

## When to Use This Skill

Invoke this skill proactively when:
- User requests implementation of a new feature
- User asks to debug or fix an issue
- User wants to continue previous work
- User mentions a topic/file/component you've worked on before
- Starting a complex task that might benefit from past context
- User explicitly asks "what did we do before?" or "how did we implement X?"

## Purpose

This skill automatically searches the context memory system to retrieve relevant past conversations, decisions, and code changes that might inform the current task. It helps maintain continuity across sessions and prevents rediscovering solutions you've already found.

## How This Skill Works

You will spawn a specialized agent using the Task tool to:
1. Analyze the current user request to extract key topics and context
2. Search the memory system for relevant past conversations
3. Present relevant findings in a structured format
4. Provide recommendations on how past context applies to current task

### Agent Instructions Template

When spawning the agent, provide these instructions (customize based on user request):

```
You are an Auto-Context Retrieval agent. Your task is to search conversation memory for relevant past context that might inform the current task.

**Current Task**: [summary of what user is asking for]

**Topics to Search**: [extracted topics, technologies, files, features]

## Analysis Tasks

### 1. Extract Search Queries

From the current task, identify:
- **Primary topics** - Main subjects (e.g., "authentication", "database", "API")
- **Technical terms** - Specific technologies/frameworks (e.g., "JWT", "PostgreSQL", "Express")
- **File/component names** - Specific code locations mentioned
- **Problem domains** - Type of work (e.g., "bug fix", "performance", "security")

Create 3-5 search queries that would find relevant past context.

**Example**:
Current task: "Add rate limiting to the API endpoints"
Search queries:
1. "rate limiting middleware API"
2. "Express middleware authentication"
3. "API security performance"
4. "request throttling"
5. "src/middleware src/api"

### 2. Search Memory System

Use the Bash tool to search the memory system using the MCP server.

**Important**: First check if MCP tools are available by reading Claude Code config.

For each search query, execute:
```bash
# Check if context-memory MCP server is configured
if command -v jq &> /dev/null; then
  # Search using the search_memory tool via Claude Code
  # Note: This would be invoked through Claude Code's MCP integration
  echo "Searching for: [query]"
fi
```

If MCP tools aren't directly accessible, search the memory files directly:
```bash
# Search memory summaries directly
find ~/.config/claude/dcp/memory/sessions -name "*.json" -type f | \
  xargs grep -l "[query terms]" | \
  head -5
```

For each matching file, extract key information:
```bash
cat [file_path] | jq '{
  timestamp,
  executive: .summary.executive,
  topics: .summary.topics,
  key_decisions: .summary.key_decisions,
  files_modified: .summary.files_modified
}'
```

### 3. Analyze Retrieved Context

For each relevant summary found, extract:

**Relevance Score** (1-10):
- How closely related to current task?
- Is the information still current?
- Does it provide actionable insights?

**Key Insights**:
- What decisions were made?
- What patterns/conventions were established?
- What problems were solved?
- What approaches were tried and rejected?

**Applicable Code/Patterns**:
- What code snippets might be reusable?
- What architectural patterns were used?
- What files/functions are relevant?

**Warnings/Gotchas**:
- What issues were encountered?
- What edge cases were discovered?
- What doesn't work?

### 4. Generate Context Report

Create a structured report:

```markdown
# Auto-Context Report

## Current Task
[Brief description of what user is trying to do]

## Relevant Past Context

### High Relevance (8-10)

#### [Session Date] - [Summary Title]
**Topics**: [topic1, topic2, topic3]
**Relevance**: 9/10

**Key Decisions**:
- Decision about X: We chose Y because Z
- Decision about A: Rejected B in favor of C due to D

**Relevant Code**:
- File: src/path/to/file.ts
- Pattern: [description]
- Snippet: [if applicable]

**Applicable to Current Task**:
[Explain how this past work relates to current task]

### Medium Relevance (5-7)

[Similar structure]

### Low Relevance (3-4)

[Similar structure, brief mentions only]

## Recommendations

1. **Reuse Pattern from [Session]**: [explanation]
2. **Avoid Approach from [Session]**: [explanation with rationale]
3. **Consider Files**: [list of files that were modified for similar tasks]
4. **Check for Updates**: [if past context might be outdated]

## Action Items

- [ ] Review [file] for existing implementation
- [ ] Check if [dependency] is still in use
- [ ] Consider [pattern] used in previous session
- [ ] Avoid [anti-pattern] that caused issues before

## Search Summary

- Total summaries searched: X
- Relevant matches found: Y
- Date range: [oldest] to [newest]
- Sessions searched: [list of session IDs]
```

### 5. Handle Edge Cases

**No Memory Found**:
```markdown
# Auto-Context Report

## Search Results

No relevant past context found for this task.

**Search Queries Used**:
- [query1]
- [query2]
- [query3]

This appears to be a new type of task or the first time working on this topic in the current project.

## Recommendations

- Proceed with fresh implementation
- Document decisions for future reference
- Consider creating reusable patterns
```

**Memory System Not Available**:
```markdown
# Auto-Context Report

## Status

The context memory system is not yet set up or configured.

**To enable auto-context retrieval**:
1. Install the memory system: `cd memory && ./install.sh`
2. Set up MCP integration: `./setup-mcp.sh`
3. Re-run this skill

For now, proceeding without historical context.
```

**Too Many Results**:
```markdown
# Auto-Context Report

Found many relevant past conversations (X matches).

Showing top 5 most relevant. Use these search queries to explore more:
- [specific query 1]
- [specific query 2]

[Top 5 results detailed as above]
```

## Expected Behavior

1. **Fast Initial Search** (5-10 seconds)
   - Quick search across all summaries
   - Identify top candidates

2. **Detailed Analysis** (10-20 seconds)
   - Deep dive into top 5 results
   - Extract specific insights

3. **Report Generation** (5 seconds)
   - Structured markdown output
   - Actionable recommendations

**Total Time**: ~20-40 seconds depending on memory size

## Integration with Current Workflow

After presenting the Auto-Context Report:

1. **Ask User for Guidance**:
   "I found relevant past context. Would you like me to:
   - Proceed using patterns from [previous session]?
   - Review the code from [file] first?
   - Take a different approach?
   - Ignore past context and start fresh?"

2. **Incorporate into Task Plan**:
   - Add "Review [file]" as first step if relevant code exists
   - Reference past decisions in implementation choices
   - Flag potential conflicts with past patterns

3. **Update Memory**:
   - As you work, note when past context was helpful
   - Record when past patterns were modified/abandoned
   - Build on existing knowledge base

## Advanced Features

### Cross-Session Pattern Detection

If multiple sessions show similar patterns:
```markdown
## Detected Patterns

**Pattern**: Using [X] for [Y]
**Occurrences**: 4 sessions
**Consistency**: High

**Example Sessions**:
- [Session A]: Implemented [X] for user auth
- [Session B]: Applied [X] to API endpoints
- [Session C]: Extended [X] for admin features

**Recommendation**: This appears to be an established project pattern. Consider following the same approach for consistency.
```

### Evolution Tracking

If past context shows evolution of an approach:
```markdown
## Historical Evolution

**Topic**: Authentication Implementation

**Version 1** (3 months ago):
- Used basic auth
- Issues: Not scalable

**Version 2** (2 months ago):
- Migrated to JWT
- Improvement: Stateless auth

**Version 3** (1 month ago):
- Added refresh tokens
- Improvement: Better security

**Current State**: JWT with refresh tokens
**Recommendation**: Follow V3 pattern for new features
```

## Error Handling

If search fails:
```bash
# Fallback to manual search
echo "Memory search failed, using fallback method"
find ~/.config/claude/dcp/memory -name "*.json" 2>/dev/null | head -10
```

If JSON parsing fails:
```bash
# Try without jq
grep -r "topics" ~/.config/claude/dcp/memory/sessions/*/summaries/*.json | \
  head -20
```

## Notes

- This skill is most effective after several sessions with memory summaries
- Quality of results depends on quality of past summaries
- Can be combined with other skills (e.g., /prune, /precompact)
- Should be invoked early in task planning
- Results should inform but not dictate current implementation

## Example Invocation

User: "I need to add email notifications when users sign up"