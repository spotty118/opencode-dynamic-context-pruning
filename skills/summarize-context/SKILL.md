---
name: summarize-context
description: Generates structured JSON summaries of compacted conversation content for semantic search and context preservation. Use when context compaction occurs or when creating searchable memory archives of conversation segments.
allowed-tools: ["Read", "Write", "Grep", "Bash"]
---

# Context Summarization Skill

## When to Use This Skill

Invoke this skill when:
- Context compaction has occurred and you need to archive conversation content
- Creating searchable memory from compacted transcript segments
- User requests a structured summary of conversation history
- Post-compaction to preserve key decisions and insights
- Building embeddings metadata for semantic search
- Generating documentation from completed work sessions

## Purpose

This skill analyzes conversation transcript segments that have been or will be compacted, extracting and structuring the most important information into a JSON format optimized for:
- **Semantic search** - Topics and tags for finding relevant past conversations
- **Context restoration** - Key decisions and rationale for future reference
- **Code archaeology** - Tracking what changed, when, and why
- **Task continuity** - Preserving completed work and pending items
- **Knowledge preservation** - Important insights and problem-solving approaches

## How This Skill Works

You will spawn a specialized agent using the Task tool to analyze the transcript segment and generate a comprehensive structured summary in JSON format.

### Agent Instructions Template

When spawning the agent, provide these instructions (customize with actual transcript path):

```
You are a Context Summarization agent. Your task is to analyze a conversation transcript segment and generate a comprehensive structured JSON summary for archival and semantic search.

**Transcript File**: [path to transcript segment]

## Analysis Tasks

### 1. Read the Transcript Segment

Use the Read tool to load the conversation transcript. The transcript contains:
- User and assistant messages
- Tool invocations and results (Read, Write, Edit, Grep, Glob, etc.)
- Task/subagent invocations and their analysis
- TodoWrite operations showing task progression
- Code changes, file operations, and decisions

### 2. Extract Executive Summary

Create a 1-2 paragraph executive summary covering:
- **Primary objectives** - What was the user trying to accomplish?
- **Major accomplishments** - What was successfully completed?
- **Key outcomes** - What changed as a result of this work?
- **Technical scope** - What systems/files/features were involved?

**Guidelines**:
- Focus on "why" and "what" rather than implementation details
- Use clear, searchable language
- Capture business/technical context
- Mention specific technologies, frameworks, or patterns used

**Example**:
"Implemented authentication middleware for Express.js API to support JWT-based user sessions. The work involved creating token validation logic, integrating with existing user database models, and adding protected route wrappers. Successfully resolved CORS issues and added comprehensive error handling for expired tokens. This enables secure API access for the frontend React application."

### 3. Identify Key Decisions

For each significant decision point, extract:
- **topic** - What the decision was about (string)
- **decision** - The actual decision made (string)
- **rationale** - Why this approach was chosen (string)
- **files_affected** - Which files were impacted (array of paths)
- **timestamp** - When the decision occurred (ISO-8601 or message index)
- **alternatives_considered** - Other options that were discussed (array, optional)

**Examples of Key Decisions**:
- Architecture choices (state management, API design, database schema)
- Library/framework selections
- Code organization patterns
- Testing strategies
- Error handling approaches
- Performance optimization trade-offs
- Security implementations

**Example**:
```json
{
  "topic": "State Management Strategy",
  "decision": "Use React Context API instead of Redux",
  "rationale": "Application state is simple with only user auth and theme preferences. Context API reduces bundle size and eliminates boilerplate while meeting all current requirements.",
  "files_affected": [
    "/home/user/project/src/contexts/AuthContext.tsx",
    "/home/user/project/src/contexts/ThemeContext.tsx"
  ],
  "timestamp": "2025-12-23T10:15:00Z",
  "alternatives_considered": ["Redux Toolkit", "Zustand", "Jotai"]
}
```

### 4. Document Files Modified

For each file that was created or modified, extract:
- **path** - Absolute file path (string)
- **action** - Type of change: "created", "modified", "deleted", "refactored" (string)
- **purpose** - Why this file was changed (string)
- **changes_summary** - Brief description of what changed (string)
- **lines_changed** - Approximate number of lines added/removed (number, optional)
- **related_files** - Other files this change interacts with (array, optional)

**Guidelines**:
- Focus on significant changes, not trivial edits
- Capture the business/technical purpose
- Note dependencies and relationships
- Include both code and configuration files

**Example**:
```json
{
  "path": "/home/user/project/src/middleware/auth.ts",
  "action": "created",
  "purpose": "JWT authentication middleware for protecting API routes",
  "changes_summary": "Created middleware with token validation, user lookup, and request context attachment. Includes error handling for expired/invalid tokens.",
  "lines_changed": 85,
  "related_files": [
    "/home/user/project/src/models/User.ts",
    "/home/user/project/src/utils/jwt.ts"
  ]
}
```

### 5. Extract Code Snippets

For important code segments, extract:
- **file** - Source file path (string)
- **function_name** - Function/class/component name (string, optional)
- **code** - The actual code snippet (string)
- **purpose** - What this code does (string)
- **importance** - "critical", "high", "medium", "low" (string)
- **tags** - Searchable keywords (array)
- **line_range** - Start and end line numbers (object, optional)

**Criteria for Extraction**:
- **Critical**: Core algorithm, security logic, complex business rules
- **High**: Important utilities, key integrations, error handling
- **Medium**: Helper functions, configuration, standard patterns
- **Low**: Simple utilities, trivial implementations

**Guidelines**:
- Keep snippets focused (10-50 lines ideal)
- Include enough context to be self-explanatory
- Add comments if the snippet alone isn't clear
- Capture patterns worth reusing

**Example**:
```json
{
  "file": "/home/user/project/src/middleware/auth.ts",
  "function_name": "authenticateToken",
  "code": "export const authenticateToken = async (req: Request, res: Response, next: NextFunction) => {\n  const authHeader = req.headers['authorization'];\n  const token = authHeader?.split(' ')[1];\n\n  if (!token) {\n    return res.status(401).json({ error: 'Access token required' });\n  }\n\n  try {\n    const payload = jwt.verify(token, process.env.JWT_SECRET!);\n    const user = await User.findById(payload.userId);\n    \n    if (!user) {\n      return res.status(401).json({ error: 'Invalid token' });\n    }\n\n    req.user = user;\n    next();\n  } catch (err) {\n    return res.status(403).json({ error: 'Token expired or invalid' });\n  }\n};",
  "purpose": "Middleware to validate JWT tokens and attach authenticated user to request object",
  "importance": "critical",
  "tags": ["authentication", "jwt", "middleware", "security", "express"],
  "line_range": { "start": 15, "end": 35 }
}
```

### 6. Generate Topics and Tags

Create searchable metadata for semantic search:
- **primary_topics** - Main subject areas (3-5 topics)
- **technologies** - Languages, frameworks, tools used (array)
- **patterns** - Design patterns, architectural patterns (array)
- **features** - User-facing features or capabilities (array)
- **keywords** - Additional searchable terms (array)

**Guidelines**:
- Use consistent terminology (e.g., "react" not "React.js" and "reactjs")
- Include version numbers if relevant (e.g., "nextjs-14", "react-18")
- Add both generic and specific terms (e.g., ["authentication", "jwt-auth"])
- Include problem domains (e.g., "error-handling", "performance-optimization")

**Example**:
```json
{
  "primary_topics": [
    "authentication",
    "api-security",
    "middleware-development",
    "jwt-implementation",
    "express-backend"
  ],
  "technologies": [
    "typescript",
    "nodejs",
    "express",
    "jwt",
    "mongodb"
  ],
  "patterns": [
    "middleware-pattern",
    "token-based-auth",
    "request-context",
    "error-handling-middleware"
  ],
  "features": [
    "user-authentication",
    "protected-routes",
    "token-validation"
  ],
  "keywords": [
    "jwt-verify",
    "auth-middleware",
    "bearer-token",
    "request-user",
    "token-expiration",
    "cors-configuration"
  ]
}
```

### 7. Track Tasks Completed and Pending

Extract task information from TodoWrite operations and conversation flow:

**Tasks Completed**:
- **description** - What was accomplished (string)
- **status** - Always "completed" (string)
- **files_involved** - Files related to this task (array)
- **outcome** - Result or impact (string, optional)

**Tasks Pending**:
- **description** - What still needs to be done (string)
- **status** - "pending" or "blocked" (string)
- **priority** - "high", "medium", "low" (string, optional)
- **blockers** - What's preventing completion (string, optional)
- **context** - Additional context needed to resume (string, optional)

**Example**:
```json
{
  "tasks_completed": [
    {
      "description": "Implement JWT authentication middleware",
      "status": "completed",
      "files_involved": [
        "/home/user/project/src/middleware/auth.ts",
        "/home/user/project/src/utils/jwt.ts"
      ],
      "outcome": "Middleware successfully validates tokens and attaches user to request"
    },
    {
      "description": "Fix CORS issues with authentication headers",
      "status": "completed",
      "files_involved": [
        "/home/user/project/src/server.ts"
      ],
      "outcome": "CORS configured to allow Authorization header from frontend"
    }
  ],
  "tasks_pending": [
    {
      "description": "Add refresh token rotation mechanism",
      "status": "pending",
      "priority": "high",
      "context": "Current implementation uses only access tokens. Need to add refresh tokens for better security and UX."
    },
    {
      "description": "Write integration tests for auth middleware",
      "status": "pending",
      "priority": "medium",
      "context": "Unit tests exist but need end-to-end tests with real HTTP requests"
    }
  ]
}
```

### 8. Preserve Important Context

Capture critical information that doesn't fit other categories:
- **insights** - Important learnings or discoveries (array)
- **warnings** - Caveats, gotchas, or known issues (array)
- **follow_up_needed** - Actions required in the future (array)
- **references** - Documentation, URLs, or external resources cited (array)
- **environment_notes** - Configuration, dependencies, or setup requirements (array)

**Example**:
```json
{
  "insights": [
    "JWT_SECRET must be at least 256 bits for HS256 algorithm",
    "Express middleware order matters - auth must come before route handlers",
    "User lookup on every request impacts performance - consider caching strategies"
  ],
  "warnings": [
    "Token expiration is set to 1 hour - adjust based on security requirements",
    "No rate limiting on auth endpoint yet - vulnerable to brute force",
    "CORS allows all origins in development - restrict in production"
  ],
  "follow_up_needed": [
    "Implement token refresh mechanism before production",
    "Add rate limiting to authentication endpoints",
    "Configure CORS for production environment",
    "Set up token blacklist for logout functionality"
  ],
  "references": [
    "https://jwt.io/introduction",
    "https://expressjs.com/en/guide/using-middleware.html",
    "RFC 7519 - JSON Web Token (JWT)"
  ],
  "environment_notes": [
    "Requires JWT_SECRET environment variable",
    "MongoDB connection required for user lookup",
    "bcrypt dependency for password hashing"
  ]
}
```

## Output Format

Generate a complete JSON structure following this schema:

```json
{
  "metadata": {
    "timestamp": "ISO-8601 timestamp when summary was generated",
    "transcript_source": "path to the source transcript file",
    "message_range": "description of which messages were summarized (e.g., 'Messages 1-145')",
    "summary_version": "1.0",
    "agent": "summarize-context",
    "token_count_estimate": "estimated tokens in original segment"
  },
  "summary": {
    "executive": "1-2 paragraph executive summary",
    "key_decisions": [
      {
        "topic": "string",
        "decision": "string",
        "rationale": "string",
        "files_affected": ["array of paths"],
        "timestamp": "ISO-8601 or message index",
        "alternatives_considered": ["optional array"]
      }
    ],
    "files_modified": [
      {
        "path": "absolute file path",
        "action": "created|modified|deleted|refactored",
        "purpose": "string",
        "changes_summary": "string",
        "lines_changed": 0,
        "related_files": ["optional array"]
      }
    ],
    "code_snippets": [
      {
        "file": "file path",
        "function_name": "optional string",
        "code": "actual code",
        "purpose": "string",
        "importance": "critical|high|medium|low",
        "tags": ["array of keywords"],
        "line_range": { "start": 0, "end": 0 }
      }
    ],
    "topics": {
      "primary_topics": ["array"],
      "technologies": ["array"],
      "patterns": ["array"],
      "features": ["array"],
      "keywords": ["array"]
    },
    "tasks_completed": [
      {
        "description": "string",
        "status": "completed",
        "files_involved": ["array"],
        "outcome": "optional string"
      }
    ],
    "tasks_pending": [
      {
        "description": "string",
        "status": "pending|blocked",
        "priority": "high|medium|low",
        "blockers": "optional string",
        "context": "optional string"
      }
    ],
    "important_context": {
      "insights": ["array"],
      "warnings": ["array"],
      "follow_up_needed": ["array"],
      "references": ["array"],
      "environment_notes": ["array"]
    }
  },
  "embeddings_metadata": {
    "summary_text": "Concatenated searchable text for embedding generation",
    "search_terms": ["Flattened array of all searchable terms"],
    "importance_score": 0.0
  }
}
```

### Field: embeddings_metadata

This section prepares the summary for semantic search indexing:

**summary_text**: Concatenate these elements into a single searchable string:
- Executive summary
- All key decision topics and rationales
- All file purposes and change summaries
- All code snippet purposes
- All topics, technologies, patterns, features, keywords
- All insights and important context

**search_terms**: Flatten all searchable terms into a single array:
- Primary topics
- Technologies
- Patterns
- Features
- Keywords
- File names (basename only, without paths)
- Function names
- Task descriptions (completed and pending)

**importance_score**: Calculate based on:
- Number of key decisions (higher = more important)
- Number of files modified (higher = more important)
- Presence of critical code snippets (increases score)
- Number of tasks completed (higher = more important)
- Length and depth of executive summary

Score range: 0.0 to 1.0
- 0.0-0.3: Routine work, minor changes
- 0.3-0.6: Significant feature work, multiple files
- 0.6-0.8: Major feature or refactoring, architectural decisions
- 0.8-1.0: Critical work, major architectural changes, complex problem-solving

## Implementation Steps

When this skill is invoked:

1. **Extract transcript path** from user message or hook output
2. **Determine message range** to summarize (from compaction metadata or user request)
3. **Spawn Task agent** with general-purpose subagent type
4. **Provide detailed analysis instructions** (template above)
5. **Agent reads transcript** using Read tool
6. **Agent analyzes content** applying all extraction strategies
7. **Agent generates JSON** following the schema exactly
8. **Save summary to file** in memory/summaries directory with timestamp
9. **Present summary** to user with key highlights
10. **Optional**: Generate embeddings using summary_text field for semantic search

## Example Invocation

```
User: Summarize the conversation segment that was just compacted

Claude: I'll analyze the compacted segment and generate a structured summary.

[Spawns Task agent with summarization instructions]

Agent: [Reads transcript, extracts all required information, generates comprehensive JSON]

Claude: [Saves summary to memory/summaries/2025-12-23T14-30-00_auth-middleware.json]

I've created a comprehensive summary of the compacted conversation segment. Here are the highlights:

**Executive Summary**: Implemented JWT authentication middleware for Express.js API...

**Key Decisions** (3):
- State management: React Context API chosen over Redux
- Authentication: JWT tokens with 1-hour expiration
- CORS configuration: Allowing credentials for authentication headers

**Files Modified** (5):
- Created: src/middleware/auth.ts, src/utils/jwt.ts
- Modified: src/server.ts, src/routes/api.ts, .env.example

**Tasks Completed** (4):
- JWT middleware implementation
- CORS configuration
- Error handling for expired tokens
- Integration with user model

**Tasks Pending** (2):
- Add refresh token rotation (high priority)
- Write integration tests (medium priority)

**Importance Score**: 0.72 (Major feature work with architectural decisions)

The summary has been saved to: /home/user/opencode-dynamic-context-pruning/memory/summaries/2025-12-23T14-30-00_auth-middleware.json

This summary is optimized for semantic search and can be used to restore context or find related work in the future.
```

## Output File Naming Convention

Save summaries with descriptive timestamps and slugs:
- Format: `YYYY-MM-DDTHH-MM-SS_<slug>.json`
- Slug: 2-4 word description of the work (kebab-case)
- Location: `memory/summaries/` directory
- Example: `2025-12-23T14-30-00_auth-middleware.json`

## Benefits

- **Semantic Search**: Rich metadata enables finding past work by topic, technology, or problem
- **Context Restoration**: Detailed summaries help restore context after long breaks
- **Knowledge Base**: Accumulated summaries form a searchable knowledge base of the project
- **Onboarding**: New team members can understand project evolution and decisions
- **Debugging**: Track what changed when and why for troubleshooting
- **Documentation**: Summaries serve as living documentation of the codebase
- **Pattern Recognition**: Identify recurring patterns and solutions across conversations

## Integration with Memory System

This skill integrates with the broader context management system:

1. **PreCompact Hook** → Triggers before compaction to identify what to preserve
2. **Compaction** → Claude's native compaction process
3. **Post-Compaction** → This skill summarizes the compacted segment
4. **Memory Storage** → Summary saved to `memory/summaries/`
5. **Embedding Generation** → Summary text converted to vector embeddings
6. **Semantic Index** → Embeddings stored in vector database
7. **Context Retrieval** → Future conversations can search and restore relevant summaries

## Quality Guidelines

- **Accuracy**: Verify all file paths, function names, and code snippets
- **Completeness**: Don't skip important decisions or changes
- **Clarity**: Use clear, searchable language in all descriptions
- **Consistency**: Follow naming conventions and terminology consistently
- **Relevance**: Focus on information that will be useful for future reference
- **Conciseness**: Be thorough but avoid unnecessary verbosity

## Notes

- Token estimates should be based on original transcript size (1 token ≈ 4 characters)
- Importance scores help prioritize which summaries to load in future contexts
- The summary itself should be significantly smaller than the original transcript (target: 10-20% of original)
- All arrays should contain at least one element if the section is relevant (empty arrays indicate no data)
- ISO-8601 timestamps should include timezone (UTC preferred)
- File paths must be absolute, not relative
- Code snippets should be valid, runnable code (not pseudocode)
- This skill works best when invoked after significant work has been completed
