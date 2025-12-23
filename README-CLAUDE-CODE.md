# Dynamic Context Pruning for Claude Code

> Optimize token usage by analyzing and identifying pruneable tool outputs in your conversation history

## Overview

Dynamic Context Pruning (DCP) is a Claude Code plugin that helps you understand and optimize your conversation context. Using AI agents, it analyzes your conversation history to identify tool outputs that can be safely removed, reducing token usage and improving performance.

**Version:** 2.0.0 (Claude Code)
**Original Plugin:** [@tarquinen/opencode-dcp](https://www.npmjs.com/package/@tarquinen/opencode-dcp) for OpenCode

## How It Works

Unlike the OpenCode version which automatically prunes messages, the Claude Code version uses an **agent-based analysis approach**:

1. **You trigger analysis** via slash command (`/prune`) or Claude invokes it via skill
2. **A specialized agent is spawned** using the Task tool
3. **The agent analyzes** your conversation using three strategies:
   - **Deduplication**: Identifies repeated tool calls
   - **Supersede Writes**: Finds write operations superseded by reads
   - **Semantic Analysis**: Identifies outputs no longer relevant
4. **Results are reported** with estimated token savings
5. **You decide** whether to compact manually or wait for automatic compaction

## Installation

### Option 1: Install in Project

```bash
cd your-project
mkdir -p .claude
cd .claude
git clone https://github.com/Tarquinen/opencode-dynamic-context-pruning.git plugins/dcp
```

### Option 2: Install Globally

```bash
cd ~/.claude
mkdir -p plugins
cd plugins
git clone https://github.com/Tarquinen/opencode-dynamic-context-pruning.git dcp
```

### Enable the Plugin

Add to your Claude Code settings (`.claude/settings.json` or `~/.claude/settings.json`):

```json
{
  "plugins": [
    "dcp"
  ]
}
```

Or if installed globally:

```json
{
  "plugins": [
    "~/.claude/plugins/dcp"
  ]
}
```

## Usage

### Manual Analysis (Slash Command)

Type `/prune` in your conversation to trigger context analysis:

```
User: /prune
```

Claude will spawn an agent that analyzes your conversation and reports findings like:

```markdown
## Context Pruning Analysis

**Total Tool Calls**: 127
**Pruneable Outputs**: 43
**Estimated Token Savings**: ~8,400 tokens

### Breakdown by Strategy

#### Deduplication (23 outputs, ~4,200 tokens)
- Read /home/user/project/src/index.ts appears 5 times, keeping most recent
- Grep "function.*export" appears 3 times, keeping most recent
...

#### Supersede Writes (15 outputs, ~3,100 tokens)
- Write to config.json superseded by Read at later position
- Edit to src/utils.ts superseded by Read at later position
...

#### Semantic Analysis (5 outputs, ~1,100 tokens)
- Grep output from initial exploration no longer relevant
- Bash output from debugging session after bug was fixed
...

### Recommendation
Pruning 43 tool outputs would save approximately 8,400 tokens.
Consider using `/compact` to reduce context size.
```

### Automatic Invocation (Skill)

Claude can automatically invoke the context pruning skill when it detects:
- Conversation has grown large (50+ tool calls)
- Multiple repeated operations
- Context optimization would be beneficial

The skill works the same way as the slash command, spawning an agent to analyze and report findings.

### PreCompact Hook Integration (Advanced)

**NEW**: The plugin now integrates with Claude Code's `PreCompact` hook, triggered automatically before context compaction:

#### How It Works

1. **Trigger**: When you type `/compact` or automatic compaction kicks in
2. **Hook Fires**: `hooks/pre-compact.sh` receives compaction event with transcript path
3. **Quick Analysis**: Hook performs rapid heuristic analysis
4. **Agent Spawning**: Hook outputs instructions for Claude to spawn a detailed analysis agent
5. **Deep Analysis**: Agent reads transcript and applies all three pruning strategies
6. **Guidance**: Agent provides specific recommendations on what to preserve vs remove
7. **Compaction**: Claude uses guidance to perform intelligent compaction

#### Example Flow

```
User: /compact

[PreCompact Hook Triggers]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[DCP PreCompact] Context compaction triggered (manual)
[DCP] Analyzing transcript to provide compaction guidance...
[DCP] Quick Analysis:
  Tool calls: 127
  Messages: 89

[DCP Guidance] Large number of tool calls detected.
  Recommendation: Prioritize preserving recent tool results
  and active file states.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Claude: I see a compaction request. Let me spawn an agent to
        analyze the transcript and provide detailed guidance.

[Spawns precompact-analysis agent]

Agent Report:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## PreCompact Analysis Report

### 🟢 Preserve (High Priority)
- Last 25 messages: Active development work
- Tool 102-127: Recent file operations
- Task 5: Architecture analysis subagent
- Current TODO state (8 active items)

### 🟡 Can Remove (Lower Priority)
- Tools 5,12,28: Duplicate Read calls (keep most recent)
- Tools 10,15,22: Superseded writes
- Tools 1-20: Initial exploration (task complete)

### 📊 Token Analysis
- Preserve: ~15,200 tokens (68%)
- Can Remove: ~8,400 tokens (32%)
- Net savings: ~8,400 tokens

### 🎯 Recommendation
MODERATE compaction: Remove duplicates and superseded
content while preserving all active work context.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Claude: Based on the analysis, I recommend proceeding with
        moderate compaction. This will save ~8,400 tokens
        while preserving all critical context.

User: Proceed
[Compaction executes with intelligent guidance]
```

#### Configuration

Control PreCompact behavior in `~/.config/claude/dcp/config.json`:

```json
{
  "preCompact": {
    "enabled": true,                    // Enable PreCompact hook
    "showPreCompactAnalysis": true,     // Show quick analysis
    "autoAnalyze": true,                // Auto quick analysis
    "useAgent": true                    // Spawn agent for deep analysis
  }
}
```

**Options**:
- `enabled`: Enable/disable PreCompact hook entirely
- `showPreCompactAnalysis`: Show hook output with quick stats
- `autoAnalyze`: Run quick heuristic analysis in hook
- `useAgent`: Request agent spawning for detailed analysis (recommended)

#### Benefits

- **Proactive**: Analysis happens automatically before compaction
- **Intelligent**: AI agent makes context-aware decisions
- **Transparent**: See exactly what will be compacted and why
- **Optimal**: Balances token savings with context preservation

## Pruning Strategies

### 1. Deduplication Strategy

Identifies tool calls with identical names and parameters, keeping only the most recent.

**Example:**
```
Tool 5: Read /path/to/file.ts
Tool 12: Read /path/to/file.ts  (duplicate)
Tool 28: Read /path/to/file.ts  (duplicate)
→ Recommendation: Keep only Tool 28, prune Tools 5 and 12
```

### 2. Supersede Writes Strategy

Identifies write operations (Write, Edit, NotebookEdit) followed by Read operations on the same file. The write INPUT becomes redundant since the current state is in the read output.

**Example:**
```
Tool 10: Write /path/to/config.json (with large content)
Tool 25: Read /path/to/config.json
→ Recommendation: Prune Tool 10's input content (superseded by Tool 25)
```

### 3. Semantic Analysis

Identifies tool outputs that are no longer relevant to the current task.

**Example:**
```
Tool 3: Grep "TODO" in codebase (during initial exploration)
Tool 45: Current task is writing tests (exploration phase complete)
→ Recommendation: Prune Tool 3 (no longer relevant)
```

## Protected Tools

These tools are NEVER recommended for pruning:
- **Task** - Subagent invocations
- **TodoWrite/TodoRead** - Task tracking
- **Prune** - This plugin itself
- **Batch** - Batch operations

## Configuration

Configuration is stored in `~/.config/claude/dcp/config.json`:

```json
{
  "enabled": true,
  "debug": false,
  "strategies": {
    "deduplication": {
      "enabled": true,
      "protectedTools": []
    },
    "supersedeWrites": {
      "enabled": true
    },
    "semantic": {
      "enabled": true
    }
  },
  "preCompact": {
    "enabled": true,
    "showPreCompactAnalysis": true,
    "autoAnalyze": true,
    "useAgent": true
  },
  "notification": {
    "showOnSessionStart": true,
    "showAnalysisResults": true
  }
}
```

### Configuration Options

- **enabled**: Enable/disable the plugin (default: `true`)
- **debug**: Enable debug logging to `~/.config/claude/dcp/logs/` (default: `false`)
- **strategies.deduplication.enabled**: Enable deduplication strategy (default: `true`)
- **strategies.deduplication.protectedTools**: Additional tools to protect from deduplication (default: `[]`)
- **strategies.supersedeWrites.enabled**: Enable supersede writes strategy (default: `true`)
- **strategies.semantic.enabled**: Enable semantic analysis strategy (default: `true`)
- **preCompact.enabled**: Enable PreCompact hook integration (default: `true`)
- **preCompact.showPreCompactAnalysis**: Show hook output with quick analysis (default: `true`)
- **preCompact.autoAnalyze**: Run automatic quick analysis in hook (default: `true`)
- **preCompact.useAgent**: Request agent spawning for detailed analysis (default: `true`)
- **notification.showOnSessionStart**: Show welcome message on session start (default: `true`)
- **notification.showAnalysisResults**: Show detailed analysis results (default: `true`)

## Key Differences from OpenCode Version

| Feature | OpenCode Version | Claude Code Version |
|---------|-----------------|-------------------|
| **Pruning** | Automatic message transformation | Analysis only, recommendations |
| **Approach** | Hook-based, runs on every message | Agent-based, on-demand analysis |
| **System Prompt** | Injects pruning context automatically | Uses skills and slash commands |
| **Token Savings** | Immediate (prunes before LLM call) | Advisory (requires manual/auto compaction) |
| **Configuration** | `dcp.jsonc` with multiple precedence levels | `config.json` in Claude config directory |
| **Tools** | Registers `prune` tool for LLM | Uses agent spawning via Task tool |

## Architecture

### Plugin Structure

```
.claude-plugin/
├── plugin.json              # Plugin manifest
commands/
├── prune.md                 # /prune slash command
skills/
├── prune/
│   └── SKILL.md            # context-pruning skill
└── precompact/
    └── SKILL.md            # precompact-analysis skill
hooks/
├── session-start.sh        # SessionStart hook
└── pre-compact.sh          # PreCompact hook (NEW)
agents/
└── prune-analyzer.json     # Agent definition
settings.json               # Plugin settings
```

### Agent-Based Analysis Flow

#### Manual Analysis (/prune command)

```
User types /prune
    ↓
Claude reads slash command prompt
    ↓
Claude spawns Task agent with specialized instructions
    ↓
Agent analyzes conversation history
    ↓
Agent applies three strategies
    ↓
Agent generates detailed report
    ↓
Claude presents findings to user
    ↓
User decides: /compact or wait
```

#### PreCompact Hook Flow (NEW)

```
User types /compact (or auto-compaction triggers)
    ↓
PreCompact hook fires
    ↓
Hook receives: transcript path, trigger type, session ID
    ↓
Hook performs quick analysis (tool count, message count)
    ↓
Hook outputs analysis request with agent instructions
    ↓
Claude sees hook output
    ↓
Claude spawns precompact-analysis agent
    ↓
Agent reads transcript file
    ↓
Agent applies three strategies (dedup, supersede, semantic)
    ↓
Agent generates detailed compaction guidance
    ↓
Claude receives guidance: preserve X, remove Y
    ↓
Claude performs intelligent compaction
    ↓
Context optimized with ~30-50% token savings
```

## Limitations

Due to Claude Code's architecture:

1. **No Automatic Pruning**: Cannot modify messages before they're sent to the LLM
2. **Advisory Only**: Provides recommendations, but cannot enforce pruning
3. **Manual Compaction**: User must trigger `/compact` or wait for automatic compaction
4. **No System Prompt Injection**: Cannot automatically add pruning context to system prompts

## Benefits Despite Limitations

While the Claude Code version is advisory-only, it still provides significant value:

- **Transparency**: See exactly what would be pruned and why
- **Education**: Understand conversation context and token usage patterns
- **Validation**: Verify that automatic compaction won't remove important information
- **Control**: Make informed decisions about when to compact
- **Trust**: Agent-based analysis provides detailed explanations
- **PreCompact Integration**: Automatic analysis before every compaction ensures intelligent optimization
- **Token Savings**: Achieve 30-50% token reduction with AI-guided compaction
- **Context Preservation**: Never lose critical information during compaction

## Troubleshooting

### Plugin Not Loading

1. Check plugin path in settings.json
2. Verify `.claude-plugin/plugin.json` exists
3. Check Claude Code logs for errors

### Slash Command Not Working

1. Verify `commands/prune.md` exists
2. Check file has proper frontmatter with `description`
3. Restart Claude Code session

### Skill Not Triggering

1. Verify `skills/prune/SKILL.md` exists
2. Check skill has proper frontmatter with `name` and `description`
3. Ensure permissions allow Skill and Task tools in settings.json

### Hook Not Running

1. Verify hooks are executable:
```bash
chmod +x ~/.claude/plugins/dcp/hooks/*.sh
```
2. Check hook configuration in settings.json
3. Look for hook output in session logs

### PreCompact Hook Not Triggering

1. Ensure `preCompact.enabled: true` in config
2. Verify PreCompact hook registered in settings.json
3. Test manually:
```bash
CLAUDE_HOOK_TRANSCRIPT_PATH=/path/to/transcript.json \
CLAUDE_HOOK_TRIGGER=manual \
~/.claude/plugins/dcp/hooks/pre-compact.sh
```
4. Check logs: `~/.config/claude/dcp/logs/precompact.log` (if debug enabled)

## Contributing

This is an adaptation of the OpenCode DCP plugin for Claude Code. Contributions welcome!

### Development

```bash
# Clone the repository
git clone https://github.com/Tarquinen/opencode-dynamic-context-pruning.git
cd opencode-dynamic-context-pruning

# Make changes to Claude Code plugin files
# Test in your Claude Code environment

# Submit PR
```

## License

MIT

## Credits

- **Original Plugin**: [@tarquinen/opencode-dcp](https://www.npmjs.com/package/@tarquinen/opencode-dcp)
- **Author**: tarquinen
- **Claude Code Adaptation**: v2.0.0

## Links

- [GitHub Repository](https://github.com/Tarquinen/opencode-dynamic-context-pruning)
- [OpenCode Version](https://www.npmjs.com/package/@tarquinen/opencode-dcp)
- [Issues](https://github.com/Tarquinen/opencode-dynamic-context-pruning/issues)

## Support

For issues, questions, or feature requests:
- [Open an Issue](https://github.com/Tarquinen/opencode-dynamic-context-pruning/issues)
- [Discussions](https://github.com/Tarquinen/opencode-dynamic-context-pruning/discussions)

---

**Note**: This plugin is in active development. The Claude Code plugin API is evolving, and this plugin will be updated as new capabilities become available.
