---
name: precompact-analysis
description: Analyzes conversation transcript before context compaction to provide intelligent guidance on what to preserve vs remove. Use when PreCompact hook triggers or when context compaction is imminent.
allowed-tools: ["Read", "Grep", "Bash"]
---

# PreCompact Analysis Skill

## When to Use This Skill

Invoke this skill when:
- PreCompact hook has triggered (manual or automatic compaction)
- User requests analysis before `/compact` command
- Context size is approaching limits
- You need to decide what's safe to compact

## Purpose

This skill analyzes the conversation transcript to provide **intelligent compaction guidance**, ensuring important context is preserved while removing redundant or obsolete information.

## How This Skill Works

You will spawn a specialized agent using the Task tool to analyze the transcript file and generate compaction recommendations.

### Agent Instructions Template

When spawning the agent, provide these instructions (customize with actual transcript path):

```
You are a PreCompact analysis agent. Your task is to analyze a conversation transcript and provide intelligent guidance for context compaction.

**Transcript File**: [path from hook output]

## Analysis Tasks

### 1. Read the Transcript
Use the Read tool to load the conversation transcript. Look for:
- Tool use messages (tool_use, tool_result)
- User and assistant messages
- File operations (Write, Edit, Read, Grep, etc.)
- Task invocations and subagents

### 2. Apply Pruning Strategies

#### A. Deduplication Strategy
Identify tool calls with identical:
- Tool name
- Parameters (file paths, patterns, etc.)

**Logic**: Keep only the MOST RECENT occurrence of each unique tool call.

**Example**:
```
Tool 5: Read /home/user/project/config.ts
Tool 12: Read /home/user/project/config.ts (duplicate)
Tool 28: Read /home/user/project/config.ts (duplicate)
→ PRESERVE: Tool 28, REMOVE: Tools 5, 12
```

#### B. Supersede Writes Strategy
Identify write-then-read patterns:
- File written using Write, Edit, or NotebookEdit
- Same file later read using Read

**Logic**: The write INPUT content is redundant since current state is in the read OUTPUT.

**Example**:
```
Tool 10: Write /home/user/config.json (large content)
Tool 25: Read /home/user/config.json
→ REMOVE: Tool 10 input content (superseded by Tool 25)
```

#### C. Semantic Analysis
Review tool outputs for current relevance:
- Is this information still needed for the current task?
- Has the conversation moved to a different topic?
- Is this debugging output from a resolved issue?
- Is this initial exploration that's no longer relevant?

**Examples**:
```
✗ REMOVE: Initial codebase exploration (task completed)
✓ PRESERVE: Recent file modifications (active work)
✗ REMOVE: Debugging grep outputs (bug fixed)
✓ PRESERVE: Current TODO list state
```

### 3. Protected Content (NEVER Remove)

Absolutely preserve:
- **Task invocations** - Subagent results critical for context
- **TodoWrite/TodoRead** - Task tracking and progress
- **Recent decisions** - Last 10-20 messages of active work
- **Current file states** - Most recent Read of files being modified
- **Error messages** - If issues are still unresolved
- **User instructions** - Explicit requirements and constraints

### 4. Token Estimation

Estimate token savings:
- 1 token ≈ 4 characters
- Count characters in removable content
- Distinguish critical vs removable tokens

## Output Format

Provide a structured analysis report:

```markdown
## PreCompact Analysis Report

**Transcript**: [path]
**Total Messages**: [count]
**Total Tool Calls**: [count]
**Analysis Time**: [timestamp]

---

### 🟢 Preserve (High Priority)

**Recent Active Work** (~X,XXX tokens)
- Tool [ID]: [Tool name] - [reason to keep]
  Example: Tool 145: Read src/index.ts - Current file being modified
- Tool [ID]: [Tool name] - [reason to keep]

**Critical Context** (~X,XXX tokens)
- Task [ID]: Subagent analysis of architecture
- TodoWrite [ID]: Current task list with 8 active items
- [Other critical items]

**Decision History** (~X,XXX tokens)
- Messages [ID range]: Discussion of implementation approach
- Messages [ID range]: User requirements and constraints

---

### 🟡 Can Remove (Lower Priority)

**Deduplication** (~X,XXX tokens)
- Tool [ID1, ID2, ID3]: Read /path/to/file.ts (3 duplicates, keeping most recent)
- Tool [ID4, ID5]: Grep "pattern" (2 duplicates, keeping most recent)
- [List all deduplicated tools]

**Superseded Writes** (~X,XXX tokens)
- Tool [ID]: Write /path/to/config.json (superseded by Read at Tool [ID2])
- Tool [ID]: Edit /path/to/utils.ts (superseded by Read at Tool [ID2])
- [List all superseded writes]

**Obsolete Exploration** (~X,XXX tokens)
- Tools [ID range]: Initial codebase exploration (task completed)
- Tool [ID]: Debugging Grep (issue resolved)
- Messages [ID range]: Early discussion (decisions finalized)
- [List obsolete content]

---

### 📊 Token Analysis

| Category | Tokens | Percentage |
|----------|--------|------------|
| **Preserve** | ~X,XXX | XX% |
| **Can Remove** | ~X,XXX | XX% |
| **Total Savings** | ~X,XXX | XX% |

**Breakdown**:
- Deduplication: ~X,XXX tokens (YY items)
- Superseded Writes: ~X,XXX tokens (ZZ items)
- Semantic Removal: ~X,XXX tokens (WW items)

---

### 🎯 Compaction Recommendation

[Provide specific guidance for Claude's compaction system]

**Strategy**: [Conservative | Moderate | Aggressive]

**Reasoning**: [Explain the recommended approach]

**Priority Guidelines**:
1. [First priority preservation rule]
2. [Second priority preservation rule]
3. [What can be safely removed]

**Example**:
"Recommend MODERATE compaction. Preserve last 30 messages of active development work and all recent file states. Remove duplicate tool calls (saves ~4,200 tokens) and superseded write inputs (saves ~3,100 tokens). Keep all Task invocations and current TODO state. Total estimated savings: ~7,300 tokens while preserving all critical context for ongoing work."

---

### ⚠️ Warnings

[Any potential issues or concerns]

Examples:
- "Caution: Removing exploration phase may lose architectural insights"
- "Note: 3 unresolved error messages preserved for debugging"
- "Warning: Large file contents in recent Reads (X,XXX tokens) but needed for active work"
```

## Implementation Steps

When this skill is invoked:

1. **Extract transcript path** from the PreCompact hook output or user message
2. **Spawn Task agent** with general-purpose subagent type
3. **Provide detailed analysis instructions** (template above)
4. **Agent reads transcript** using Read tool
5. **Agent applies strategies** (deduplication, supersede writes, semantic)
6. **Agent generates report** with specific recommendations
7. **Present report** to user or use to guide compaction decisions

## Example Invocation

```
User: [PreCompact hook triggered with transcript path /path/to/transcript.json]

Claude: I'll analyze the transcript to provide compaction guidance.

[Spawns Task agent with analysis instructions]

Agent: [Reads transcript, applies strategies, generates report]

Claude: [Presents report to user]

Based on the analysis, I recommend moderate compaction:
- Preserve: Recent 25 messages, current file states, all Task results
- Remove: 43 duplicate tool calls, 15 superseded writes
- Estimated savings: ~8,400 tokens (32% reduction)

Shall I proceed with compaction using these guidelines?
```

## Benefits

- **Intelligent Compaction**: Data-driven decisions on what to remove
- **Preserve Critical Context**: Never lose important information
- **Maximize Token Savings**: Remove redundant/obsolete content efficiently
- **Transparency**: Clear explanation of what will be compacted
- **User Control**: Recommendations require approval

## Notes

- This skill works best with the PreCompact hook integration
- Analysis is advisory - final compaction decisions respect user preferences
- Token estimates are approximate (1 token ≈ 4 characters)
- Always err on the side of preserving too much rather than too little
