#!/usr/bin/env node

/**
 * Context Memory MCP Server
 *
 * Provides semantic search and retrieval tools for conversation context summaries.
 * Integrates with Claude Code's PreCompact hook to preserve and retrieve context
 * across compactions and sessions.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import { homedir } from 'os';

// ============================================================================
// Type Definitions
// ============================================================================

interface KeyDecision {
  topic: string;
  decision: string;
  rationale: string;
  files: string[];
}

interface FileModification {
  path: string;
  action: 'created' | 'modified' | 'deleted';
  purpose: string;
}

interface CodeSnippet {
  file: string;
  function: string;
  code: string;
  importance: 'high' | 'medium' | 'low';
}

interface Summary {
  executive: string;
  key_decisions: KeyDecision[];
  files_modified: FileModification[];
  code_snippets: CodeSnippet[];
  topics: string[];
  tasks_completed: string[];
  tasks_pending: string[];
}

interface Embeddings {
  summary_vector?: number[];
  topic_vectors?: Record<string, number[]>;
}

interface CompactionSummary {
  timestamp: string;
  compaction_trigger: 'auto' | 'manual' | 'size_limit';
  token_count_before?: number;
  token_count_after?: number;
  summary: Summary;
  embeddings?: Embeddings;
  original_message_range?: [number, number];
}

interface SessionMetadata {
  session_id: string;
  project_path?: string;
  created_at: string;
  last_updated: string;
  total_compactions: number;
}

interface ProjectKnowledge {
  topic: string;
  content: string;
  source_sessions: string[];
  confidence: number;
  last_updated: string;
}

interface SearchResult {
  session_id: string;
  summary_id: string;
  summary: Summary;
  relevance: number;
  timestamp: string;
  snippet: string;
}

// ============================================================================
// Configuration
// ============================================================================

const MEMORY_BASE_DIR = path.join(homedir(), '.config', 'claude', 'dcp', 'memory');
const SESSIONS_DIR = path.join(MEMORY_BASE_DIR, 'sessions');
const PROJECTS_DIR = path.join(MEMORY_BASE_DIR, 'projects');

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Ensures a directory exists, creating it if necessary
 */
async function ensureDir(dirPath: string): Promise<void> {
  try {
    await fs.mkdir(dirPath, { recursive: true });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'EEXIST') {
      throw error;
    }
  }
}

/**
 * Safely reads and parses a JSON file
 */
async function readJsonFile<T>(filePath: string): Promise<T | null> {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(content) as T;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      return null;
    }
    throw error;
  }
}

/**
 * Writes an object to a JSON file
 */
async function writeJsonFile<T>(filePath: string, data: T): Promise<void> {
  await ensureDir(path.dirname(filePath));
  await fs.writeFile(filePath, JSON.stringify(data, null, 2), 'utf-8');
}

/**
 * Lists all session directories
 */
async function listSessions(): Promise<string[]> {
  try {
    await ensureDir(SESSIONS_DIR);
    const entries = await fs.readdir(SESSIONS_DIR, { withFileTypes: true });
    return entries
      .filter(entry => entry.isDirectory())
      .map(entry => entry.name);
  } catch (error) {
    return [];
  }
}

/**
 * Lists all summary files in a session
 */
async function listSummaries(sessionId: string): Promise<string[]> {
  const summariesDir = path.join(SESSIONS_DIR, sessionId, 'summaries');
  try {
    const files = await fs.readdir(summariesDir);
    return files.filter(f => f.endsWith('.json')).sort();
  } catch (error) {
    return [];
  }
}

/**
 * Generates a simple text-based similarity score (placeholder for embeddings)
 * Uses basic keyword matching and token overlap
 */
function calculateTextSimilarity(query: string, text: string): number {
  const queryTokens = query.toLowerCase().split(/\s+/);
  const textTokens = text.toLowerCase().split(/\s+/);

  // Calculate Jaccard similarity
  const querySet = new Set(queryTokens);
  const textSet = new Set(textTokens);

  const intersection = new Set([...querySet].filter(x => textSet.has(x)));
  const union = new Set([...querySet, ...textSet]);

  const jaccardScore = intersection.size / union.size;

  // Boost score if query terms appear in sequence
  let sequenceBoost = 0;
  const queryLower = query.toLowerCase();
  const textLower = text.toLowerCase();
  if (textLower.includes(queryLower)) {
    sequenceBoost = 0.3;
  }

  return Math.min(jaccardScore + sequenceBoost, 1.0);
}

/**
 * Searches summaries across sessions using text similarity
 */
async function searchSummaries(
  query: string,
  limit: number = 5,
  sessionId: string | null = null,
  minRelevance: number = 0.3
): Promise<SearchResult[]> {
  const results: SearchResult[] = [];

  const sessions = sessionId ? [sessionId] : await listSessions();

  for (const session of sessions) {
    const summaryFiles = await listSummaries(session);

    for (const file of summaryFiles) {
      const filePath = path.join(SESSIONS_DIR, session, 'summaries', file);
      const data = await readJsonFile<CompactionSummary>(filePath);

      if (!data) continue;

      // Calculate relevance by searching in different fields
      const searchableText = [
        data.summary.executive,
        ...data.summary.topics,
        ...data.summary.key_decisions.map(d => `${d.topic} ${d.decision} ${d.rationale}`),
        ...data.summary.files_modified.map(f => `${f.path} ${f.purpose}`),
        ...data.summary.tasks_completed,
        ...data.summary.tasks_pending,
      ].join(' ');

      const relevance = calculateTextSimilarity(query, searchableText);

      if (relevance >= minRelevance) {
        // Create a snippet from the executive summary
        const snippet = data.summary.executive.length > 200
          ? data.summary.executive.substring(0, 200) + '...'
          : data.summary.executive;

        results.push({
          session_id: session,
          summary_id: file.replace('.json', ''),
          summary: data.summary,
          relevance,
          timestamp: data.timestamp,
          snippet,
        });
      }
    }
  }

  // Sort by relevance and limit results
  return results
    .sort((a, b) => b.relevance - a.relevance)
    .slice(0, limit);
}

/**
 * Retrieves a specific summary by session and summary ID
 */
async function getSummary(
  sessionId: string,
  summaryId: string
): Promise<CompactionSummary | null> {
  const filePath = path.join(SESSIONS_DIR, sessionId, 'summaries', `${summaryId}.json`);
  return await readJsonFile<CompactionSummary>(filePath);
}

/**
 * Retrieves project knowledge, optionally filtered by topic
 */
async function getProjectKnowledge(
  projectId: string | null = null,
  topic: string | null = null
): Promise<ProjectKnowledge[]> {
  await ensureDir(PROJECTS_DIR);

  const projects = projectId
    ? [projectId]
    : (await fs.readdir(PROJECTS_DIR, { withFileTypes: true }))
        .filter(e => e.isDirectory())
        .map(e => e.name);

  const allKnowledge: ProjectKnowledge[] = [];

  for (const project of projects) {
    const knowledgePath = path.join(PROJECTS_DIR, project, 'knowledge.json');
    const knowledge = await readJsonFile<ProjectKnowledge[]>(knowledgePath);

    if (knowledge) {
      const filtered = topic
        ? knowledge.filter(k => k.topic.toLowerCase().includes(topic.toLowerCase()))
        : knowledge;

      allKnowledge.push(...filtered);
    }
  }

  return allKnowledge;
}

/**
 * Stores a new summary (called by PreCompact hook)
 */
async function storeSummary(
  sessionId: string,
  summary: CompactionSummary
): Promise<{ success: boolean; summary_id: string; path: string }> {
  // Ensure directories exist
  const sessionDir = path.join(SESSIONS_DIR, sessionId);
  const summariesDir = path.join(sessionDir, 'summaries');
  await ensureDir(summariesDir);

  // Generate summary ID based on timestamp
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const summaryId = `compact_${timestamp}`;
  const filePath = path.join(summariesDir, `${summaryId}.json`);

  // Write summary
  await writeJsonFile(filePath, summary);

  // Update session metadata
  const metadataPath = path.join(sessionDir, 'metadata.json');
  let metadata = await readJsonFile<SessionMetadata>(metadataPath);

  if (!metadata) {
    metadata = {
      session_id: sessionId,
      created_at: new Date().toISOString(),
      last_updated: new Date().toISOString(),
      total_compactions: 0,
    };
  }

  metadata.last_updated = new Date().toISOString();
  metadata.total_compactions += 1;

  await writeJsonFile(metadataPath, metadata);

  return {
    success: true,
    summary_id: summaryId,
    path: filePath,
  };
}

/**
 * Gets session metadata
 */
async function getSessionMetadata(sessionId: string): Promise<SessionMetadata | null> {
  const metadataPath = path.join(SESSIONS_DIR, sessionId, 'metadata.json');
  return await readJsonFile<SessionMetadata>(metadataPath);
}

// ============================================================================
// MCP Server Implementation
// ============================================================================

class ContextMemoryServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: 'context-memory',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  private setupHandlers(): void {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: this.getTools(),
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'search_memory':
            return await this.handleSearchMemory(args);

          case 'get_summary':
            return await this.handleGetSummary(args);

          case 'get_project_knowledge':
            return await this.handleGetProjectKnowledge(args);

          case 'store_summary':
            return await this.handleStoreSummary(args);

          case 'get_session_metadata':
            return await this.handleGetSessionMetadata(args);

          case 'list_sessions':
            return await this.handleListSessions();

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${errorMessage}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  private getTools(): Tool[] {
    return [
      {
        name: 'search_memory',
        description: 'Search past conversation context using semantic similarity. Searches across all session summaries to find relevant past discussions, decisions, and code changes.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query - describe what you\'re looking for',
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results to return (default: 5)',
              default: 5,
            },
            session_id: {
              type: 'string',
              description: 'Optional: Search within a specific session only',
            },
            min_relevance: {
              type: 'number',
              description: 'Minimum relevance score 0-1 (default: 0.3)',
              default: 0.3,
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'get_summary',
        description: 'Retrieve a specific summary by session and summary ID. Returns full detailed information about a past compaction including decisions, files, and code snippets.',
        inputSchema: {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'Session ID',
            },
            summary_id: {
              type: 'string',
              description: 'Summary ID (e.g., "compact_001")',
            },
          },
          required: ['session_id', 'summary_id'],
        },
      },
      {
        name: 'get_project_knowledge',
        description: 'Query project-level knowledge base. Retrieves architectural decisions, patterns, and conventions discovered across all sessions in the project.',
        inputSchema: {
          type: 'object',
          properties: {
            project_id: {
              type: 'string',
              description: 'Optional: Specific project ID',
            },
            topic: {
              type: 'string',
              description: 'Optional: Filter by topic (e.g., "authentication", "caching")',
            },
          },
        },
      },
      {
        name: 'store_summary',
        description: 'Store a new compaction summary. Called by PreCompact hook to save context before it\'s removed from active conversation.',
        inputSchema: {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'Current session ID',
            },
            summary: {
              type: 'object',
              description: 'Compaction summary data',
              properties: {
                timestamp: { type: 'string' },
                compaction_trigger: {
                  type: 'string',
                  enum: ['auto', 'manual', 'size_limit'],
                },
                token_count_before: { type: 'number' },
                token_count_after: { type: 'number' },
                summary: {
                  type: 'object',
                  properties: {
                    executive: { type: 'string' },
                    key_decisions: { type: 'array' },
                    files_modified: { type: 'array' },
                    code_snippets: { type: 'array' },
                    topics: { type: 'array' },
                    tasks_completed: { type: 'array' },
                    tasks_pending: { type: 'array' },
                  },
                  required: ['executive', 'topics'],
                },
              },
              required: ['timestamp', 'compaction_trigger', 'summary'],
            },
          },
          required: ['session_id', 'summary'],
        },
      },
      {
        name: 'get_session_metadata',
        description: 'Get metadata about a specific session including creation time, number of compactions, etc.',
        inputSchema: {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'Session ID',
            },
          },
          required: ['session_id'],
        },
      },
      {
        name: 'list_sessions',
        description: 'List all available session IDs that have stored summaries.',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
    ];
  }

  private async handleSearchMemory(args: any) {
    const {
      query,
      limit = 5,
      session_id = null,
      min_relevance = 0.3,
    } = args;

    if (!query) {
      throw new Error('Query parameter is required');
    }

    const results = await searchSummaries(
      query,
      limit,
      session_id,
      min_relevance
    );

    const formattedResults = results.map(r => ({
      session_id: r.session_id,
      summary_id: r.summary_id,
      relevance: r.relevance.toFixed(3),
      timestamp: r.timestamp,
      snippet: r.snippet,
      topics: r.summary.topics,
      key_decisions: r.summary.key_decisions.length,
      files_modified: r.summary.files_modified.length,
    }));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            query,
            total_results: results.length,
            results: formattedResults,
          }, null, 2),
        },
      ],
    };
  }

  private async handleGetSummary(args: any) {
    const { session_id, summary_id } = args;

    if (!session_id || !summary_id) {
      throw new Error('Both session_id and summary_id are required');
    }

    const summary = await getSummary(session_id, summary_id);

    if (!summary) {
      throw new Error(`Summary not found: ${session_id}/${summary_id}`);
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(summary, null, 2),
        },
      ],
    };
  }

  private async handleGetProjectKnowledge(args: any) {
    const { project_id = null, topic = null } = args;

    const knowledge = await getProjectKnowledge(project_id, topic);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            total_items: knowledge.length,
            knowledge,
          }, null, 2),
        },
      ],
    };
  }

  private async handleStoreSummary(args: any) {
    const { session_id, summary } = args;

    if (!session_id || !summary) {
      throw new Error('Both session_id and summary are required');
    }

    const result = await storeSummary(session_id, summary as CompactionSummary);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }

  private async handleGetSessionMetadata(args: any) {
    const { session_id } = args;

    if (!session_id) {
      throw new Error('session_id is required');
    }

    const metadata = await getSessionMetadata(session_id);

    if (!metadata) {
      throw new Error(`Session not found: ${session_id}`);
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(metadata, null, 2),
        },
      ],
    };
  }

  private async handleListSessions() {
    const sessions = await listSessions();

    const sessionDetails = await Promise.all(
      sessions.map(async (sessionId) => {
        const metadata = await getSessionMetadata(sessionId);
        return {
          session_id: sessionId,
          metadata,
        };
      })
    );

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            total_sessions: sessions.length,
            sessions: sessionDetails,
          }, null, 2),
        },
      ],
    };
  }

  async run(): Promise<void> {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);

    // Log to stderr (stdout is reserved for MCP protocol)
    console.error('Context Memory MCP Server running on stdio');
  }
}

// ============================================================================
// Main
// ============================================================================

async function main() {
  const server = new ContextMemoryServer();
  await server.run();
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
