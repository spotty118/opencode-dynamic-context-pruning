---
name: context-pruning
description: Analyzes conversation history to identify and recommend removal of obsolete tool outputs, reducing token usage. Use when context grows large (>50 tool calls) or when optimizing for token efficiency.
allowed-tools: []
---

# Context Pruning Skill

## When to Use This Skill

Invoke this skill when:
- Conversation has accumulated 50+ tool results
- Multiple file reads of the same files have occurred
- Files have been written then subsequently read
- Context size is impacting performance
- User explicitly asks to optimize tokens or reduce context

## How This Skill Works

You will analyze the conversation history using three pruning strategies:

### 1. Deduplication Strategy
Identify repeated tool calls where:
- Same tool name (Read, Grep, Glob, etc.)
- Identical parameters (same file paths, patterns, etc.)
- Multiple occurrences exist

**Action**: Keep only the most recent occurrence, mark earlier ones as pruneable.

**Example**:
```
Tool 1: Read /home/user/project/src/index.ts
Tool 5: Read /home/user/project/src/index.ts (same file)
Tool 12: Read /home/user/project/src/index.ts (same file again)
→ Mark Tool 1 and Tool 5 for pruning, keep Tool 12
```

### 2. Supersede Writes Strategy
Identify write-then-read patterns:
- A file is modified using Write, Edit, or NotebookEdit
- The same file is later read using Read
- The write content is now redundant (current state is in the read)

**Action**: Mark the write tool INPUT (not output) for pruning.

**Example**:
```
Tool 3: Write /home/user/project/config.json (with content X)
Tool 8: Read /home/user/project/config.json
→ Mark Tool 3's input content for pruning (the actual file content written)
```

### 3. Semantic Analysis
Review tool outputs for relevance:
- Is this information still needed for the current task?
- Has the conversation moved to a different topic?
- Is this debugging output from a resolved issue?

**Protected Tools** (NEVER prune):
- Task (subagent invocations)
- TodoWrite, TodoRead
- Prune
- Batch
- Any tool currently pending or running

## Output Format

After analysis, provide a structured report:

```markdown
## Context Pruning Analysis

**Total Tool Calls**: [number]
**Pruneable Outputs**: [number]
**Estimated Token Savings**: ~[number] tokens

### Breakdown by Strategy

#### Deduplication ([X] outputs, ~[Y] tokens)
- [Tool name] at positions [list]: duplicate calls with identical parameters
- ...

#### Supersede Writes ([X] outputs, ~[Y] tokens)
- Write to [file] at position [N] superseded by Read at position [M]
- ...

#### Semantic Analysis ([X] outputs, ~[Y] tokens)
- [Tool name] at position [N]: [reason why no longer relevant]
- ...

### Recommendation

[Suggest whether pruning is beneficial and next steps]
```

## Important Notes

- **Token Calculation**: Estimate based on output length (1 token ≈ 4 characters)
- **Notification**: Always explain what would be pruned and why
- **User Confirmation**: Recommend user review before actual pruning
- **Claude Code Limitation**: Cannot automatically prune messages - analysis is advisory only
- **Manual Compaction**: Suggest user use `/compact` command after reviewing recommendations

## Implementation Approach

When this skill is invoked, you should:

1. **Spawn a specialized agent** using the Task tool with the general-purpose subagent type
2. **Provide the agent with detailed instructions** to analyze the conversation history using the three strategies above
3. **The agent will analyze** the conversation and identify pruneable tool outputs
4. **Report the agent's findings** to the user with clear explanations
5. **Suggest next steps**: manual compaction with `/compact` or wait for automatic compaction

### Agent Instructions Template

When spawning the agent, provide these instructions:

```
Analyze the conversation history to identify tool outputs that can be pruned to reduce token usage.

Apply three strategies:
1. **Deduplication**: Find repeated tool calls with identical parameters
2. **Supersede Writes**: Find write operations superseded by subsequent reads
3. **Semantic Analysis**: Identify outputs no longer relevant to current task

Protected tools (never prune): Task, TodoWrite, TodoRead, Prune, Batch

Generate a detailed report with:
- Total tool calls and pruneable outputs
- Estimated token savings
- Breakdown by strategy with specific examples
- Recommendation on whether pruning is beneficial

Return your final analysis as a structured markdown report.
```

This skill provides valuable analysis that helps users understand their context usage and make informed decisions about compaction.
