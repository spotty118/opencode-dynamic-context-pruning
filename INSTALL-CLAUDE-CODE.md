# Installation Guide for Claude Code

This guide will help you install and configure the Dynamic Context Pruning plugin for Claude Code.

## Prerequisites

- Claude Code CLI installed and configured
- Basic familiarity with Claude Code plugins

## Quick Install

### Step 1: Clone the Repository

```bash
# Install globally (recommended)
mkdir -p ~/.claude/plugins
cd ~/.claude/plugins
git clone https://github.com/Tarquinen/opencode-dynamic-context-pruning.git dcp

# OR install in project
cd your-project
mkdir -p .claude/plugins
cd .claude/plugins
git clone https://github.com/Tarquinen/opencode-dynamic-context-pruning.git dcp
```

### Step 2: Enable the Plugin

**For Global Installation:**

Edit `~/.claude/settings.json`:

```json
{
  "plugins": [
    "~/.claude/plugins/dcp"
  ]
}
```

**For Project Installation:**

Edit `your-project/.claude/settings.json`:

```json
{
  "plugins": [
    ".claude/plugins/dcp"
  ]
}
```

### Step 3: Verify Installation

Start a new Claude Code session:

```bash
claude
```

You should see:

```
[Dynamic Context Pruning v2.0.0]
Plugin loaded. Use /prune to analyze conversation context.
Commands: /prune | Skills: context-pruning
```

### Step 4: Test the Plugin

Type `/prune` in your conversation:

```
User: /prune
```

Claude should spawn an agent to analyze your conversation context.

## Configuration

The plugin creates a default configuration file at:

```
~/.config/claude/dcp/config.json
```

### Default Configuration

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
  "notification": {
    "showOnSessionStart": true,
    "showAnalysisResults": true
  }
}
```

### Customizing Configuration

Edit `~/.config/claude/dcp/config.json` to customize:

**Disable Session Start Notification:**
```json
{
  "notification": {
    "showOnSessionStart": false
  }
}
```

**Enable Debug Logging:**
```json
{
  "debug": true
}
```

Debug logs will be written to `~/.config/claude/dcp/logs/`

**Add Protected Tools:**
```json
{
  "strategies": {
    "deduplication": {
      "protectedTools": ["CustomTool", "AnotherTool"]
    }
  }
}
```

**Disable a Strategy:**
```json
{
  "strategies": {
    "semantic": {
      "enabled": false
    }
  }
}
```

## Usage

### Manual Analysis (Slash Command)

Type `/prune` to trigger context analysis:

```
User: /prune
```

Claude will spawn an agent that analyzes your conversation and provides a detailed report.

### Automatic Invocation (Skill)

Claude can automatically invoke the context-pruning skill when it detects that context optimization would be beneficial.

## Troubleshooting

### Plugin Not Loading

**Problem:** Plugin doesn't load on session start

**Solutions:**
1. Check that the plugin path in `settings.json` is correct
2. Verify `.claude-plugin/plugin.json` exists in the plugin directory
3. Make sure the plugin directory is readable

```bash
ls -la ~/.claude/plugins/dcp/.claude-plugin/plugin.json
```

### Slash Command Not Working

**Problem:** `/prune` command not recognized

**Solutions:**
1. Verify `commands/prune.md` exists
2. Check file permissions:
```bash
ls -la ~/.claude/plugins/dcp/commands/prune.md
```
3. Restart Claude Code session

### Hook Not Executing

**Problem:** No welcome message on session start

**Solutions:**
1. Check hook is executable:
```bash
chmod +x ~/.claude/plugins/dcp/hooks/session-start.sh
```
2. Verify hook configuration in `settings.json`
3. Check for shell errors:
```bash
~/.claude/plugins/dcp/hooks/session-start.sh
```

### Permission Errors

**Problem:** Permission denied errors

**Solution:** Ensure all files are readable:
```bash
chmod -R u+r ~/.claude/plugins/dcp/
chmod +x ~/.claude/plugins/dcp/hooks/session-start.sh
```

## Verifying Installation

### Check Plugin Files

```bash
cd ~/.claude/plugins/dcp

# Check structure
ls -la .claude-plugin/
ls -la commands/
ls -la skills/prune/
ls -la hooks/
ls -la agents/

# Verify key files exist
test -f .claude-plugin/plugin.json && echo "✓ Plugin manifest found"
test -f commands/prune.md && echo "✓ Prune command found"
test -f skills/prune/SKILL.md && echo "✓ Prune skill found"
test -x hooks/session-start.sh && echo "✓ Session hook executable"
```

### Check Configuration

```bash
# View config
cat ~/.config/claude/dcp/config.json

# Check debug logs (if enabled)
ls -la ~/.config/claude/dcp/logs/
```

## Uninstalling

### Remove Plugin

```bash
# For global installation
rm -rf ~/.claude/plugins/dcp

# For project installation
rm -rf .claude/plugins/dcp
```

### Remove from Settings

Edit your `settings.json` and remove the plugin entry.

### Remove Configuration

```bash
rm -rf ~/.config/claude/dcp
```

## Next Steps

- Read [README-CLAUDE-CODE.md](README-CLAUDE-CODE.md) for detailed documentation
- Try the `/prune` command in a conversation with many tool calls
- Customize the configuration to your needs
- Report issues at [GitHub Issues](https://github.com/Tarquinen/opencode-dynamic-context-pruning/issues)

## Advanced Configuration

### Custom Hook Behavior

Edit `hooks/session-start.sh` to customize session start behavior.

### Adding Protected Tools

If you have custom tools that should never be pruned, add them to the config:

```json
{
  "strategies": {
    "deduplication": {
      "protectedTools": ["MyCustomTool"]
    }
  }
}
```

### Integration with Other Plugins

The DCP plugin can work alongside other Claude Code plugins. Just add them to your `settings.json`:

```json
{
  "plugins": [
    "~/.claude/plugins/dcp",
    "~/.claude/plugins/other-plugin"
  ]
}
```

## Support

Need help? Check these resources:

- [Full Documentation](README-CLAUDE-CODE.md)
- [GitHub Issues](https://github.com/Tarquinen/opencode-dynamic-context-pruning/issues)
- [Discussions](https://github.com/Tarquinen/opencode-dynamic-context-pruning/discussions)

---

Happy pruning! 🌿
