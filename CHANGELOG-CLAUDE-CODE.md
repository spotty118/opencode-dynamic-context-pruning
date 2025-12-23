# Changelog - Claude Code Adaptation

## Version 2.0.0 - Claude Code Support (2025-12-23)

### Added

#### Plugin Infrastructure
- `.claude-plugin/plugin.json` - Plugin manifest for Claude Code
- `settings.json` - Claude Code plugin settings with hooks and permissions
- Agent-based architecture for context analysis

#### Commands
- `commands/prune.md` - Slash command `/prune` for manual context analysis
  - Spawns specialized agent to analyze conversation
  - Provides detailed pruning recommendations
  - Reports estimated token savings

#### Skills
- `skills/prune/SKILL.md` - AI-invoked skill `context-pruning`
  - Automatically triggers when context optimization is beneficial
  - Uses agent-based analysis approach
  - Applies three pruning strategies

#### Hooks
- `hooks/session-start.sh` - SessionStart hook
  - Initializes plugin on session start
  - Creates default configuration
  - Shows welcome notification
  - Enables debug logging when configured

#### Agents
- `agents/prune-analyzer.json` - Specialized agent definition
  - Defines capabilities for context analysis
  - Specifies available tools
  - Documents agent purpose and behavior

#### CLI Tools (Experimental)
- `cli/analyze.ts` - TypeScript CLI for standalone analysis
  - Can analyze conversation history files
  - Uses existing OpenCode pruning strategies
  - Generates detailed reports

#### Documentation
- `README-CLAUDE-CODE.md` - Comprehensive Claude Code documentation
  - Installation instructions
  - Usage guide
  - Architecture overview
  - Troubleshooting tips
- `INSTALL-CLAUDE-CODE.md` - Step-by-step installation guide
  - Quick install instructions
  - Configuration examples
  - Verification steps
  - Troubleshooting solutions

### Changed

#### Architecture Shift
- **From**: Automatic message transformation (OpenCode)
- **To**: Agent-based analysis with recommendations (Claude Code)

| Aspect | OpenCode | Claude Code |
|--------|----------|-------------|
| Pruning | Automatic | Advisory only |
| Approach | Hook-based | Agent-based |
| Invocation | Every message | On-demand |
| Token Savings | Immediate | Requires compaction |

#### Analysis Flow
1. User invokes `/prune` or Claude triggers skill
2. Claude spawns Task agent with specialized instructions
3. Agent analyzes conversation using three strategies:
   - Deduplication
   - Supersede Writes
   - Semantic Analysis
4. Agent generates detailed report with token estimates
5. User decides whether to compact context

### Technical Details

#### Pruning Strategies (Adapted)

**1. Deduplication**
- Identifies repeated tool calls (same name + parameters)
- Keeps most recent occurrence
- Marks earlier instances as pruneable
- Example: Multiple Read calls for same file

**2. Supersede Writes**
- Finds Write/Edit operations followed by Read operations
- Write INPUT content becomes redundant after Read
- Current state captured in Read output
- Example: Write config.json then Read config.json

**3. Semantic Analysis**
- Reviews tool outputs for current relevance
- Identifies outputs from completed tasks
- Flags debugging output after resolution
- Example: Initial exploration Grep no longer needed

#### Protected Tools
Never recommended for pruning:
- Task (subagent invocations)
- TodoWrite/TodoRead (task tracking)
- Prune (this plugin)
- Batch (batch operations)

#### Configuration System

**Location**: `~/.config/claude/dcp/config.json`

**Default Configuration**:
```json
{
  "enabled": true,
  "debug": false,
  "strategies": {
    "deduplication": { "enabled": true, "protectedTools": [] },
    "supersedeWrites": { "enabled": true },
    "semantic": { "enabled": true }
  },
  "notification": {
    "showOnSessionStart": true,
    "showAnalysisResults": true
  }
}
```

### Limitations

#### Due to Claude Code Architecture
1. **No Automatic Pruning**: Cannot modify messages before LLM
2. **Advisory Only**: Provides recommendations, not enforcement
3. **Manual Compaction**: Requires `/compact` or auto-compaction
4. **No System Prompt Injection**: Cannot add automatic prompting

### Benefits Despite Limitations

1. **Transparency**: Clear visibility into what would be pruned
2. **Education**: Learn about context usage patterns
3. **Validation**: Verify important data won't be lost
4. **Control**: User makes final decision
5. **Trust**: Detailed explanations for all recommendations

### Migration from OpenCode

For users familiar with the OpenCode version:

| OpenCode Feature | Claude Code Equivalent |
|-----------------|----------------------|
| Automatic pruning | Manual analysis + compaction |
| `prune` tool | `/prune` slash command |
| Message transform hook | Agent-based analysis |
| System prompt injection | Skills with descriptions |
| Config in dcp.jsonc | Config in ~/.config/claude/dcp/ |
| Token savings notification | Analysis report |

### Installation

```bash
# Global installation (recommended)
mkdir -p ~/.claude/plugins
cd ~/.claude/plugins
git clone https://github.com/Tarquinen/opencode-dynamic-context-pruning.git dcp

# Add to ~/.claude/settings.json
{
  "plugins": ["~/.claude/plugins/dcp"]
}
```

### Usage Examples

#### Manual Analysis
```
User: /prune

Claude: [Spawns agent]

Agent Report:
## Context Pruning Analysis
**Total Tool Calls**: 127
**Pruneable Outputs**: 43
**Estimated Token Savings**: ~8,400 tokens

### Breakdown by Strategy
[Detailed analysis...]

### Recommendation
Pruning would save ~8,400 tokens. Consider `/compact`.
```

#### Automatic Invocation
Claude detects large context and invokes skill automatically:
```
Claude: I notice the conversation has grown quite large. Let me analyze
        the context to identify what can be safely compacted.
        [Spawns agent...]
```

### File Structure

```
opencode-dynamic-context-pruning/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── commands/
│   └── prune.md                 # /prune command
├── skills/
│   └── prune/
│       └── SKILL.md            # context-pruning skill
├── hooks/
│   └── session-start.sh        # SessionStart hook
├── agents/
│   └── prune-analyzer.json     # Agent definition
├── cli/
│   └── analyze.ts              # Standalone analyzer (experimental)
├── settings.json               # Plugin settings
├── README-CLAUDE-CODE.md       # Main documentation
├── INSTALL-CLAUDE-CODE.md      # Installation guide
└── CHANGELOG-CLAUDE-CODE.md    # This file
```

### Compatibility

- **Claude Code**: All versions with plugin support
- **Node.js**: Not required (uses shell hooks and agents)
- **TypeScript**: Only for experimental CLI tool
- **OpenCode**: Original plugin remains compatible

### Breaking Changes

None - this is a new adaptation for Claude Code, not a replacement for the OpenCode version.

### Known Issues

1. Cannot perform actual message pruning (architecture limitation)
2. Token estimates are approximate (1 token ≈ 4 characters)
3. Semantic analysis relies on agent judgment
4. No integration with Claude Code's built-in compaction system

### Future Enhancements

Possible future improvements:
- Integration with PreCompact hook
- Better token estimation using tiktoken
- Persistent analysis history
- Custom strategy configuration per project
- Export analysis reports

### Contributing

Contributions welcome! Areas for improvement:
- Enhanced semantic analysis strategies
- Better agent prompting for accuracy
- Integration with Claude Code compaction
- Performance optimizations
- Additional documentation

### Credits

- **Original Plugin**: @tarquinen/opencode-dcp for OpenCode
- **Claude Code Adaptation**: Version 2.0.0
- **Inspiration**: OpenCode's message transformation hooks

### License

MIT (same as original OpenCode plugin)

---

## Version 1.0.4 and Earlier

See main [CHANGELOG](../CHANGELOG.md) for OpenCode version history.
