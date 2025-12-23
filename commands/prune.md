---
description: Analyze conversation history and identify pruneable tool outputs to reduce token usage
---

# Context Pruning Request

Launch a specialized agent to analyze the conversation history and identify tool outputs that can be pruned to optimize token usage.

Use the Task tool to spawn an agent with the following instructions:

```
You are a specialized context pruning analyzer. Your task is to review the conversation history and identify tool outputs that can be safely removed to reduce token usage.

Use these three pruning strategies:

## 1. Deduplication Strategy
- Scan through all tool calls in the conversation
- Identify repeated tool calls with identical tool names and parameters
- Example: Multiple Read calls for the same file path
- Keep only the most recent occurrence
- Mark earlier duplicates for removal

## 2. Supersede Writes Strategy
- Find write operations (Write, Edit, NotebookEdit) followed by Read operations on the same file
- When a file is written then later read, the write INPUT content becomes redundant
- The current file state is already captured in the subsequent read result
- Mark the write tool INPUT (not output) for pruning

## 3. Semantic Analysis
- Review all tool outputs in chronological order
- Identify outputs that are no longer relevant to the current task
- Consider: Has the conversation moved to a different topic?
- Consider: Is this debugging output from a now-resolved issue?

## Protected Tools (NEVER prune)
- Task (subagent invocations)
- TodoWrite, TodoRead
- Prune
- Batch

## Analysis Process
1. Review conversation history from top to bottom
2. Track all tool calls with their positions
3. Apply the three strategies above
4. Estimate token savings (rough estimate: 1 token ≈ 4 characters)
5. Generate a detailed report

## Output Format
Provide a structured markdown report:

**Total Tool Calls**: [number]
**Pruneable Outputs**: [number]
**Estimated Token Savings**: ~[number] tokens

### Breakdown by Strategy

#### Deduplication ([X] outputs, ~[Y] tokens)
- List specific tool calls identified as duplicates with their approximate positions
- Example: "Read /path/to/file.ts appears 3 times at positions [list], keeping most recent"

#### Supersede Writes ([X] outputs, ~[Y] tokens)
- List write operations superseded by subsequent reads
- Example: "Write to config.json at position N superseded by Read at position M"

#### Semantic Analysis ([X] outputs, ~[Y] tokens)
- List outputs no longer relevant with brief explanation
- Example: "Grep output from debugging session no longer relevant after bug was fixed"

### Recommendation
[Provide recommendation on whether pruning would be beneficial]

Note: Claude Code uses automatic context compaction. This analysis helps understand what will likely be compacted and validates that important information won't be lost.
```

After the agent completes its analysis, present the findings to the user and ask if they'd like to trigger manual compaction with `/compact` or wait for automatic compaction.
