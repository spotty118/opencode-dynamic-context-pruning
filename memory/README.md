# Context Memory System

A semantic memory and retrieval system for Claude Code that provides persistent context across conversation sessions.

## Quick Start

### 1. Installation

Run the installation script to set up the complete memory system:

```bash
./memory/install.sh
```

This script will:
- Check dependencies (Node.js, npm, jq)
- Build the MCP server
- Create configuration directories
- Set up Claude Code MCP integration
- Make all scripts executable

### 2. Test the System

Verify everything is working:

```bash
./memory/test-memory-system.sh
```

For detailed test output:

```bash
./memory/test-memory-system.sh --verbose
```

### 3. Manual MCP Setup (if needed)

If you skipped MCP setup during installation or need to reconfigure:

```bash
./memory/setup-mcp.sh
```

## Directory Structure

```
memory/
├── install.sh                 # Main installation script
├── setup-mcp.sh              # MCP configuration script
├── test-memory-system.sh     # Comprehensive test suite
├── mcp-server/               # MCP server implementation
│   ├── index.ts              # Main server code
│   ├── types.ts              # TypeScript type definitions
│   ├── package.json          # Node.js dependencies
│   ├── tsconfig.json         # TypeScript configuration
│   ├── README.md             # Server documentation
│   ├── QUICKSTART.md         # Quick start guide
│   └── INTEGRATION.md        # Integration guide
├── scripts/                  # Testing utilities
│   └── test-mcp-server.ts   # TypeScript test client
└── templates/                # Example data
    └── example-summary.json # Sample summary structure
```

## Scripts

### install.sh

Complete installation and setup script.

**Usage:**
```bash
./memory/install.sh [--skip-mcp-setup]
```

**Options:**
- `--skip-mcp-setup` - Skip automatic MCP configuration

**What it does:**
1. Checks for required dependencies (Node.js ≥18, npm, jq)
2. Installs MCP server dependencies (`npm install`)
3. Builds TypeScript code (`npm run build`)
4. Creates configuration directories (~/.config/claude/dcp/memory)
5. Makes all scripts executable
6. Runs MCP setup (unless skipped)
7. Provides next steps and documentation links

### setup-mcp.sh

Configures Claude Code to use the Context Memory MCP server.

**Usage:**
```bash
./memory/setup-mcp.sh [--config-path PATH]
```

**Options:**
- `--config-path PATH` - Specify custom Claude config file path

**What it does:**
1. Detects Claude Code configuration location
2. Verifies MCP server is built
3. Backs up existing configuration
4. Adds/updates MCP server entry
5. Validates JSON configuration
6. Tests server connection

**Configuration locations checked:**
- `~/.config/claude-code/settings.json`
- `~/.claude-code/settings.json`
- `~/.config/claude/settings.json`
- `~/.claude/settings.json`
- `~/Library/Application Support/claude-code/settings.json` (macOS)
- `~/Library/Application Support/Claude/settings.json` (macOS)

### test-memory-system.sh

Comprehensive test suite for the entire memory system.

**Usage:**
```bash
./memory/test-memory-system.sh [--verbose]
```

**Options:**
- `--verbose` - Show detailed test output

**Tests performed:**
1. **Pre-flight checks**
   - Node.js installation
   - MCP server build
   - Memory storage directory

2. **MCP server tests**
   - Server initialization
   - Tool listing

3. **Storage tests**
   - Store test summary
   - Verify file creation

4. **Search tests**
   - Semantic search (multiple queries)
   - Relevance scoring
   - Non-existent content handling

5. **Retrieval tests**
   - Get specific summary
   - Session metadata retrieval

6. **Session management tests**
   - List all sessions
   - Get session metadata

7. **Configuration tests**
   - Claude Code MCP configuration

8. **File system tests**
   - Summary file creation
   - Metadata file creation

9. **Performance tests**
   - Search query performance

**Output:**
- Colored test results (✓ pass, ✗ fail, ⚠ warning)
- Test summary with pass/fail counts
- Performance metrics
- Cleanup instructions

## MCP Server Features

The Context Memory MCP server provides these tools to Claude Code:

### Available Tools

1. **search_memory** - Semantic search across conversation summaries
2. **store_summary** - Store compaction summaries
3. **get_summary** - Retrieve specific summary
4. **list_sessions** - List all sessions with summaries
5. **get_session_metadata** - Get session information
6. **get_project_knowledge** - Query project-level knowledge

See [mcp-server/README.md](mcp-server/README.md) for detailed API documentation.

## Storage Structure

Summaries are stored in:

```
~/.config/claude/dcp/memory/
├── sessions/
│   ├── session_abc123/
│   │   ├── summaries/
│   │   │   ├── compact_2025-12-23T04-30-00-000Z.json
│   │   │   └── compact_2025-12-23T05-15-00-000Z.json
│   │   └── metadata.json
│   └── session_def456/
│       └── ...
└── projects/
    └── project_hash_12345/
        ├── knowledge.json
        └── patterns.json
```

## Requirements

- **Node.js** ≥18.0.0
- **npm** (any recent version)
- **jq** (optional, for JSON manipulation)

### Installing Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install nodejs npm jq
```

**macOS:**
```bash
brew install node jq
```

**Windows (WSL):**
```bash
sudo apt-get update
sudo apt-get install nodejs npm jq
```

## Troubleshooting

### Installation Issues

**"Node.js version must be >= 18.0.0"**
```bash
# Update Node.js using nvm
nvm install 18
nvm use 18
```

**"MCP server not found"**
```bash
cd memory/mcp-server
npm install
npm run build
```

### MCP Configuration Issues

**"Configuration file was not created"**
```bash
# Manually create config
mkdir -p ~/.config/claude-code
./memory/setup-mcp.sh
```

**"jq not found" warnings**
```bash
# Install jq (optional but recommended)
sudo apt-get install jq  # Ubuntu/Debian
brew install jq          # macOS
```

### Test Failures

**"Search performance slower than expected"**
- Normal for first run (cold start)
- Performance improves with more summaries
- Consider optimizing search algorithm

**"Test summary not found in search results"**
- May have low relevance score
- Check `min_relevance` parameter
- Verify summary was stored correctly

### Runtime Issues

**MCP server not responding**
```bash
# Test server manually
node memory/mcp-server/dist/index.js
# Should wait for input (Ctrl+C to exit)
```

**"Session directory not created"**
```bash
# Create manually
mkdir -p ~/.config/claude/dcp/memory/sessions
chmod 755 ~/.config/claude/dcp/memory/sessions
```

## Development

### Building the MCP Server

```bash
cd memory/mcp-server

# Install dependencies
npm install

# Build TypeScript
npm run build

# Watch mode (auto-rebuild)
npm run dev

# Clean build artifacts
npm run clean
```

### Running Tests

```bash
# Run test suite
./memory/test-memory-system.sh

# Verbose output
./memory/test-memory-system.sh --verbose

# TypeScript test client
cd memory/scripts
npx tsx test-mcp-server.ts
```

### Manual Testing

```bash
# Start server
cd memory/mcp-server
npm start

# Send test request (in another terminal)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node dist/index.js
```

## Integration

### PreCompact Hook Integration

Example hook script:

```bash
#!/bin/bash
# hooks/pre-compact.sh

# Extract content being compacted
CONTENT=$(cat)

# Generate summary using Claude
SUMMARY=$(echo "$CONTENT" | claude-agent summarize)

# Store via MCP server
echo "$SUMMARY" | node memory/mcp-server/dist/index.js \
  --method store_summary \
  --session-id "$SESSION_ID"
```

See [mcp-server/INTEGRATION.md](mcp-server/INTEGRATION.md) for detailed integration guide.

## Documentation

- [MCP Server README](mcp-server/README.md) - Server API and features
- [Quick Start Guide](mcp-server/QUICKSTART.md) - Getting started quickly
- [Integration Guide](mcp-server/INTEGRATION.md) - Deep integration with Claude Code

## Future Enhancements

- [ ] Vector embeddings (Anthropic API or local models)
- [ ] Vector database backend (ChromaDB, FAISS)
- [ ] Hybrid search (semantic + keyword)
- [ ] Auto-summarization
- [ ] Cross-session pattern detection
- [ ] Export/import capabilities
- [ ] Summary deduplication
- [ ] Compression and archival

## License

MIT

## Support

For issues and questions:
- GitHub: https://github.com/Opencode-DCP/opencode-dynamic-context-pruning
- Documentation: memory/mcp-server/README.md
