# Deep Integration Proposal for Claude Code

This document outlines what Claude Code would need to support deep integration of the Dynamic Context Pruning plugin, similar to the OpenCode implementation.

## Current Limitations

### 1. No Message Transformation Hook

**Required:** `experimental.conversation.messages.transform`

```typescript
interface MessageTransformHook {
  (context: {
    messages: Message[];          // Full conversation history
    sessionId: string;
    isSubAgent: boolean;
  }): {
    messages: Message[];          // Modified messages
    metadata?: {
      pruned: number;
      tokensSaved: number;
    }
  }
}
```

**Use Case:** Prune obsolete tool outputs before sending to LLM

**Security:** Could require user permission: `"allow": ["MessageTransform"]`

### 2. No System Prompt Injection Hook

**Required:** `experimental.conversation.system.transform`

```typescript
interface SystemPromptHook {
  (context: {
    system: string[];            // Current system prompts
    sessionId: string;
  }): {
    system: string[];            // Modified system prompts
  }
}
```

**Use Case:** Inject pruning context and instructions

**Security:** Limited to appending, not replacing core instructions

### 3. Hooks Cannot Access Conversation State

**Required:** Environment variables or stdin for hooks

```bash
#!/bin/bash
# Hook receives conversation metadata via environment
# CLAUDE_TOOL_COUNT=127
# CLAUDE_SESSION_ID=abc123
# CLAUDE_CONTEXT_SIZE=45000

# Or conversation data via stdin
cat | jq '.messages | length'
```

**Use Case:** Make decisions based on conversation state

**Security:** Read-only access, no modification

### 4. No PreCompact Hook with Data Access

**Required:** `hooks.PreCompact` with conversation data

```typescript
interface PreCompactHook {
  (context: {
    messages: Message[];
    compactionReason: 'manual' | 'automatic' | 'size_limit';
    currentTokens: number;
    targetTokens: number;
  }): {
    analyzedMessages?: Message[];  // Optional modifications
    metadata?: {
      recommendation: string;
      tokensSaveable: number;
    }
  }
}
```

**Use Case:** Analyze what will be compacted, recommend specific removals

**Security:** Advisory mode by default, require permission for modifications

### 5. No Tool Registration Guarantees

**Current Issue:** Skills are invoked at Claude's discretion

**Required:** `experimental.guaranteedTools`

```json
{
  "experimental": {
    "guaranteedTools": {
      "prune": {
        "triggerWhen": {
          "toolCount": "> 50",
          "tokenCount": "> 40000",
          "or": "every 20 tools"
        },
        "mode": "automatic" | "suggestion"
      }
    }
  }
}
```

**Use Case:** Ensure pruning runs at appropriate intervals

**Security:** User explicitly enables in settings

## Proposed Implementation Levels

### Level 1: Read-Only Access (Low Risk)

Enable plugins to READ conversation state without modification:

```typescript
// New hook type
"experimental.conversation.analyze": {
  messages: Message[];          // Read-only
  stats: ConversationStats;     // Tool counts, token estimates
}
```

**Benefits:**
- Plugins can provide intelligent recommendations
- No risk of corrupting conversation
- Easy to sandbox and secure

**Limitations:**
- Still requires manual compaction
- Cannot automatically optimize

### Level 2: Advisory Modifications (Medium Risk)

Enable plugins to PROPOSE modifications:

```typescript
"experimental.conversation.propose": {
  input: {
    messages: Message[];
  },
  output: {
    proposedMessages: Message[];
    explanation: string;
    tokensSaved: number;
  },
  requiresApproval: true  // User must approve
}
```

**Benefits:**
- User maintains control
- Transparency in what changes
- Safe experimentation

**Limitations:**
- User friction for approvals
- Not truly automatic

### Level 3: Automatic Modifications (High Risk)

Enable plugins to AUTOMATICALLY modify messages:

```typescript
"experimental.conversation.transform": {
  input: {
    messages: Message[];
  },
  output: {
    messages: Message[];
    metadata: {
      modified: number;
      reason: string;
    }
  },
  permissions: ["MessageTransform"],  // Explicit permission required
  sandboxed: true                      // Run in isolated context
}
```

**Benefits:**
- Full automatic optimization
- Zero user friction
- Maximum token savings

**Risks:**
- Could corrupt conversation
- Loss of transparency
- Security concerns

**Mitigations:**
- Require explicit permission in settings
- Audit log of all modifications
- Ability to disable per-plugin
- Conversation rollback capability

## Security Model

### Permission System

```json
{
  "permissions": {
    "allow": [
      "ReadConversation",      // Read messages (Level 1)
      "ProposeChanges",        // Suggest modifications (Level 2)
      "TransformMessages"      // Automatic modifications (Level 3)
    ]
  }
}
```

### Audit Trail

```typescript
interface AuditLog {
  timestamp: string;
  plugin: string;
  action: 'read' | 'propose' | 'transform';
  details: {
    messagesAffected: number;
    operation: string;
    tokensSaved?: number;
  }
}
```

Logged to: `~/.claude/logs/plugin-audit.jsonl`

### Rollback Capability

```bash
# User can rollback plugin modifications
claude conversation rollback --to <timestamp>

# Or disable plugin modifications
claude settings set plugins.dcp.allowTransform false
```

## Implementation Roadmap

### Phase 1: Read-Only Analysis (Immediate)
- Add `experimental.conversation.analyze` hook
- Enable plugins to read conversation state
- Hook scripts receive conversation via stdin
- Implement DCP using advisory analysis

**Timeline:** Could ship today
**Risk:** Minimal

### Phase 2: Advisory Modifications (Short-term)
- Add `experimental.conversation.propose` hook
- Plugins suggest changes with explanations
- User approval UI for modifications
- Audit logging

**Timeline:** 1-2 months
**Risk:** Low (user approval required)

### Phase 3: Automatic Modifications (Long-term)
- Add `experimental.conversation.transform` hook
- Explicit permissions system
- Full audit trail
- Rollback capability
- DCP achieves feature parity with OpenCode

**Timeline:** 3-6 months
**Risk:** Medium (requires security review)

## Benefits of Deep Integration

### For Users

1. **Automatic Token Savings**
   - Reduce costs by 30-50% in long conversations
   - Avoid hitting context limits
   - Faster responses (less data to process)

2. **Zero Effort**
   - No manual `/compact` commands
   - No reviewing recommendations
   - Just works automatically

3. **Smarter Context**
   - Keep only relevant information
   - Preserve important history
   - Remove redundant data

### For Plugin Ecosystem

1. **More Powerful Plugins**
   - Context management plugins
   - Conversation summarization
   - Auto-documentation from conversations
   - Session replay/debugging tools

2. **Better Integration**
   - Plugins can optimize for each other
   - Shared context understanding
   - Coordinated behavior

## Alternative Approaches

If deep integration isn't feasible, alternatives include:

### 1. MCP Server Integration

```typescript
// DCP as an MCP server
const mcpServer = {
  name: 'dcp',
  tools: {
    analyze_context: async () => { /* ... */ },
    suggest_pruning: async () => { /* ... */ }
  }
}
```

**Pros:** Uses existing MCP infrastructure
**Cons:** Still can't automatically modify messages

### 2. Built-in Feature

Make context pruning a native Claude Code feature:

```json
{
  "experimental": {
    "contextOptimization": {
      "enabled": true,
      "strategies": ["deduplication", "supersede-writes"],
      "automatic": true
    }
  }
}
```

**Pros:** Deeply integrated, fully optimized
**Cons:** Not plugin-based, less flexible

### 3. Proxy/Middleware Approach

Run Claude Code through a proxy that modifies messages:

```
User → Proxy (DCP) → Claude Code → Anthropic API
```

**Pros:** Full control over messages
**Cons:** Complex setup, breaks updates, security risks

## Recommendation

**Best Path Forward:**

1. **Short-term:** Implement Phase 1 (Read-Only Access)
   - Low risk, high value
   - Enables better analysis and recommendations
   - Foundation for future enhancements

2. **Medium-term:** Implement Phase 2 (Advisory Modifications)
   - Balanced approach
   - User maintains control
   - Validates use cases

3. **Long-term:** Evaluate Phase 3 based on user feedback
   - If Phase 2 proves valuable and safe
   - If users want automatic behavior
   - If security concerns can be addressed

## Questions for Claude Code Team

1. **Architecture:** Is message transformation philosophically aligned with Claude Code's goals?

2. **Security:** What security model would make message transformation acceptable?

3. **Performance:** What's the overhead budget for plugin hooks on every message?

4. **API Stability:** Would `experimental.*` APIs be maintained across versions?

5. **User Experience:** How to balance power with simplicity for non-technical users?

## Conclusion

Deep integration is **technically possible** but requires **architectural changes** to Claude Code's plugin system. The benefits are significant (30-50% token savings, better context management), but so are the security and complexity considerations.

A phased approach starting with read-only access would validate the use case while minimizing risk.

---

**Contact:** For discussion, questions, or feedback on this proposal:
- GitHub Issues: https://github.com/Tarquinen/opencode-dynamic-context-pruning/issues
- Email: [maintainer email]
