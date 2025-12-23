# Memory Storage Examples

## Directory Structure

When the PreCompact hook runs, it creates the following structure:

```
~/.config/claude/dcp/memory/sessions/${SESSION_ID}/
├── summaries/
│   ├── compact_1703001234.json
│   ├── compact_1703005678.json
│   └── compact_1703009999.json
└── captures/
    ├── compact_1703001234.txt
    ├── compact_1703005678.txt
    └── compact_1703009999.txt
```

## Summary File Format

**File**: `~/.config/claude/dcp/memory/sessions/${SESSION_ID}/summaries/compact_${TIMESTAMP}.json`

### Initial State (Created by Hook)

```json
{
  "timestamp": 1703001234,
  "timestamp_iso": "2024-12-19T10:30:34-05:00",
  "trigger": "auto",
  "session_id": "abc123def456",
  "transcript_path": "/path/to/transcript.json",
  "metrics": {
    "tool_calls": 127,
    "messages": 45
  },
  "analysis_request": "/home/user/.config/claude/dcp/analysis/precompact_abc123_1703001234.txt",
  "status": "pending_analysis",
  "summary": null
}
```

### After Agent Analysis (Updated by Agent)

```json
{
  "timestamp": 1703001234,
  "timestamp_iso": "2024-12-19T10:30:34-05:00",
  "trigger": "auto",
  "session_id": "abc123def456",
  "transcript_path": "/path/to/transcript.json",
  "metrics": {
    "tool_calls": 127,
    "messages": 45
  },
  "analysis_request": "/home/user/.config/claude/dcp/analysis/precompact_abc123_1703001234.txt",
  "status": "completed",
  "summary": {
    "preserve": {
      "critical_context": [
        "Current task: Implementing user authentication system",
        "Database schema decisions for user table",
        "API endpoint design for /auth/login and /auth/register"
      ],
      "recent_decisions": [
        "Use bcrypt for password hashing (cost factor: 12)",
        "JWT tokens with 1-hour expiration",
        "Session storage in Redis"
      ],
      "active_work": [
        "File: src/auth/login.js - in progress",
        "Test suite: tests/auth.test.js - pending",
        "Documentation: docs/api.md - needs update"
      ]
    },
    "remove": {
      "duplicates": [
        "Duplicate Read of package.json at positions 15, 23, 31",
        "Duplicate Grep for 'import' pattern at positions 18, 27"
      ],
      "superseded": [
        "Write to src/auth/login.js at position 45 (superseded by position 89)",
        "Edit to config.json at position 12 (superseded by position 67)"
      ],
      "obsolete": [
        "Early exploration of GraphQL approach (positions 5-12)",
        "Debugging output from resolved TypeError (positions 34-38)"
      ]
    },
    "token_analysis": {
      "removable_tokens": 3500,
      "critical_tokens": 2100,
      "net_savings": 3500
    },
    "recommendation": "Focus compaction on early exploration and duplicate tool calls. Preserve all recent file operations (last 20 messages) and authentication implementation context. Safe to remove: early GraphQL exploration, duplicate reads, and resolved debugging outputs."
  }
}
```

## Capture File Format

**File**: `~/.config/claude/dcp/memory/sessions/${SESSION_ID}/captures/compact_${TIMESTAMP}.txt`

Contains human-readable information about the compaction event and instructions for the agent to update the summary file.

## Usage in Future Conversations

These stored summaries can be retrieved to provide context in new sessions:

1. **Session Continuity**: Load previous session summaries to understand what was compacted
2. **Context Recovery**: Retrieve specific decisions or work items that were preserved
3. **Compaction Analysis**: Review patterns in what gets removed vs. preserved
4. **Token Optimization**: Track token savings across multiple compaction events

## Agent Update Process

When an agent analyzes a transcript during PreCompact:

1. Read the summary file: `~/.config/claude/dcp/memory/sessions/${SESSION_ID}/summaries/compact_${TIMESTAMP}.json`
2. Perform analysis of the transcript
3. Update the `summary` field with structured findings
4. Update `status` from "pending_analysis" to "completed"
5. Save the updated JSON back to the same file
