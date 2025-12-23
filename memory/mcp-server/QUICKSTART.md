# Quick Start Guide

Get the Context Memory MCP Server up and running in 5 minutes.

## Prerequisites

- Node.js 18 or higher
- Claude Code installed
- Basic familiarity with command line

## Step 1: Build the Server (2 minutes)

```bash
# Navigate to the MCP server directory
cd memory/mcp-server

# Install dependencies
npm install

# Build the TypeScript code
npm run build
```

You should see output like:
```
Successfully compiled TypeScript
Created dist/index.js
```

## Step 2: Configure Claude Code (1 minute)

1. Find your Claude Code config file:
   - macOS/Linux: `~/.config/claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

2. Add the MCP server (create the file if it doesn't exist):

```json
{
  "mcpServers": {
    "context-memory": {
      "command": "node",
      "args": [
        "/ABSOLUTE/PATH/TO/opencode-dynamic-context-pruning/memory/mcp-server/dist/index.js"
      ]
    }
  }
}
```

**Important**: Replace `/ABSOLUTE/PATH/TO/` with your actual path!

Get the absolute path:
```bash
# macOS/Linux
pwd

# Windows (PowerShell)
(Get-Location).Path
```

## Step 3: Restart Claude Code (30 seconds)

Completely quit and restart Claude Code to load the new MCP server.

## Step 4: Test the Integration (1 minute)

Open a new conversation in Claude Code and try:

```
Can you use the search_memory tool to search for "test"?
```

Claude should respond indicating it's using the tool. Even if no results are found (first run), the tool should execute successfully.

## Step 5: Store Your First Summary (1 minute)

Try storing a test summary:

```
Can you use the store_summary tool to save a test summary for session "test_123"
with an executive summary of "This is my first test of the context memory system"?
```

Claude will call the tool and you should get a success response with a summary_id.

## Verify Installation

You should now have:

1. **Server running**: MCP server loads when Claude Code starts
2. **Tools available**: All 6 tools accessible in conversations
3. **Storage created**: `~/.config/claude/dcp/memory/` directory exists
4. **First summary**: A test summary stored and searchable

## Test Search

Search for your test summary:

```
Can you search memory for "test" and show me the results?
```

You should see your test summary in the search results!

## Common Issues

### "Tool not found"

- Did you restart Claude Code?
- Check the config file path is correct
- Verify JSON syntax in config file

### "Command failed"

- Check the path in config is **absolute** not relative
- Verify Node.js is in your PATH: `node --version`
- Check file permissions on dist/index.js

### No results from search

- This is expected on first run (no summaries yet)
- Try storing a summary first
- Check `~/.config/claude/dcp/memory/sessions/` has content

## Next Steps

Now that it's working:

1. **Integrate with PreCompact**: Automatically save summaries during compaction
2. **Build project knowledge**: Let summaries accumulate over time
3. **Use semantic search**: Find relevant past context naturally
4. **Explore the API**: Check README.md for all available tools

## Useful Commands

```bash
# View stored sessions
ls -la ~/.config/claude/dcp/memory/sessions/

# View summaries for a session
ls -la ~/.config/claude/dcp/memory/sessions/SESSION_ID/summaries/

# Read a summary
cat ~/.config/claude/dcp/memory/sessions/SESSION_ID/summaries/SUMMARY_ID.json | jq

# Clean up test data
rm -rf ~/.config/claude/dcp/memory/sessions/test_*
```

## Getting Help

- Read the full [README.md](./README.md) for all features
- Check [INTEGRATION.md](./INTEGRATION.md) for advanced setup
- Review [types.ts](./types.ts) for data structures
- Open an issue on GitHub for bugs

## What's Next?

With the MCP server running, you now have:
- ✅ Persistent context storage
- ✅ Semantic search across sessions
- ✅ Project knowledge accumulation
- ✅ Session continuity

The system will automatically improve as you use Claude Code more!
