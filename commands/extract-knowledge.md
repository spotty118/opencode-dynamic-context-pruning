---
description: Extract architectural patterns and project knowledge from conversation history
---

Analyze all conversation summaries and code to extract architectural patterns, coding conventions, and project knowledge. Build a project knowledge graph that captures:

- Architectural patterns and decisions
- Technology stack and usage patterns
- Coding conventions and style guides
- Common tasks and solutions
- Anti-patterns to avoid

Use the Task tool with the following instructions:

```
You are a Knowledge Extraction agent. Analyze all conversation summaries in ~/.config/claude/dcp/memory/sessions/ to extract patterns, conventions, and architectural decisions.

1. Load all summary JSON files from the memory directory
2. Identify recurring architectural patterns (state management, API design, data fetching, auth, testing, styling)
3. Extract coding conventions (naming, file organization, import patterns, error handling)
4. Document technology stack and library usage
5. Create Architectural Decision Records (ADRs) for key decisions
6. Identify common tasks and their solution patterns
7. Flag anti-patterns and code smells
8. Generate a structured knowledge graph JSON
9. Save to ~/.config/claude/dcp/memory/projects/project_[hash]/knowledge.json
10. Create human-readable KNOWLEDGE.md file
11. Generate a summary report

Provide detailed findings with confidence scores and source references.
```

The knowledge graph will be used by other skills (like auto-context) to provide better recommendations and maintain project consistency.
