/**
 * Type definitions for Context Memory MCP Server
 *
 * These types define the structure of summaries, knowledge, and other data
 * stored and retrieved by the context memory system.
 */

/**
 * Represents a key decision made during a conversation segment
 */
export interface KeyDecision {
  /** Topic of the decision (e.g., "Authentication Strategy") */
  topic: string;

  /** The decision that was made */
  decision: string;

  /** Rationale explaining why this decision was made */
  rationale: string;

  /** Files affected by or related to this decision */
  files: string[];
}

/**
 * Represents a file that was modified during a conversation segment
 */
export interface FileModification {
  /** File path relative to project root */
  path: string;

  /** Type of modification performed */
  action: 'created' | 'modified' | 'deleted';

  /** Purpose or reason for the modification */
  purpose: string;
}

/**
 * Represents an important code snippet to preserve
 */
export interface CodeSnippet {
  /** File containing the code */
  file: string;

  /** Function or component name */
  function: string;

  /** The actual code snippet */
  code: string;

  /** Importance level for prioritizing retrieval */
  importance: 'high' | 'medium' | 'low';
}

/**
 * Core summary content extracted from a conversation segment
 */
export interface Summary {
  /** 1-2 paragraph executive summary of what happened */
  executive: string;

  /** Important architectural or implementation decisions */
  key_decisions: KeyDecision[];

  /** Files that were created, modified, or deleted */
  files_modified: FileModification[];

  /** Important code snippets to preserve */
  code_snippets: CodeSnippet[];

  /** Topics and tags for semantic search */
  topics: string[];

  /** Tasks that were completed in this segment */
  tasks_completed: string[];

  /** Tasks that are still pending */
  tasks_pending: string[];
}

/**
 * Vector embeddings for semantic search
 */
export interface Embeddings {
  /** Embedding vector for the entire summary */
  summary_vector?: number[];

  /** Embedding vectors for individual topics */
  topic_vectors?: Record<string, number[]>;
}

/**
 * Complete compaction summary stored for a conversation segment
 */
export interface CompactionSummary {
  /** ISO timestamp when this summary was created */
  timestamp: string;

  /** What triggered the compaction */
  compaction_trigger: 'auto' | 'manual' | 'size_limit';

  /** Token count before compaction (optional) */
  token_count_before?: number;

  /** Token count after compaction (optional) */
  token_count_after?: number;

  /** The actual summary content */
  summary: Summary;

  /** Vector embeddings for semantic search (optional) */
  embeddings?: Embeddings;

  /** Original message range that was compacted [start, end] */
  original_message_range?: [number, number];
}

/**
 * Metadata about a conversation session
 */
export interface SessionMetadata {
  /** Unique session identifier */
  session_id: string;

  /** Path to the project being worked on */
  project_path?: string;

  /** ISO timestamp when session was created */
  created_at: string;

  /** ISO timestamp of last update */
  last_updated: string;

  /** Total number of compactions in this session */
  total_compactions: number;
}

/**
 * Project-level knowledge accumulated across sessions
 */
export interface ProjectKnowledge {
  /** Topic or category of knowledge */
  topic: string;

  /** The knowledge content */
  content: string;

  /** Sessions that contributed to this knowledge */
  source_sessions: string[];

  /** Confidence score 0-1 based on consistency across sessions */
  confidence: number;

  /** ISO timestamp of last update */
  last_updated: string;
}

/**
 * Search result from semantic search
 */
export interface SearchResult {
  /** Session containing the result */
  session_id: string;

  /** Summary identifier */
  summary_id: string;

  /** The summary content */
  summary: Summary;

  /** Relevance score 0-1 */
  relevance: number;

  /** ISO timestamp of the summary */
  timestamp: string;

  /** Short snippet from the summary */
  snippet: string;
}

/**
 * Parameters for searching memory
 */
export interface SearchMemoryParams {
  /** Search query string */
  query: string;

  /** Maximum number of results (default: 5) */
  limit?: number;

  /** Optional: search within specific session only */
  session_id?: string | null;

  /** Minimum relevance score 0-1 (default: 0.3) */
  min_relevance?: number;
}

/**
 * Parameters for getting a specific summary
 */
export interface GetSummaryParams {
  /** Session identifier */
  session_id: string;

  /** Summary identifier */
  summary_id: string;
}

/**
 * Parameters for getting project knowledge
 */
export interface GetProjectKnowledgeParams {
  /** Optional: specific project ID */
  project_id?: string | null;

  /** Optional: filter by topic */
  topic?: string | null;
}

/**
 * Parameters for storing a summary
 */
export interface StoreSummaryParams {
  /** Current session ID */
  session_id: string;

  /** Summary to store */
  summary: CompactionSummary;
}

/**
 * Result from storing a summary
 */
export interface StoreSummaryResult {
  /** Whether the operation succeeded */
  success: boolean;

  /** Generated summary ID */
  summary_id: string;

  /** Full path where summary was stored */
  path: string;
}

/**
 * Parameters for getting session metadata
 */
export interface GetSessionMetadataParams {
  /** Session identifier */
  session_id: string;
}

/**
 * Result from listing sessions
 */
export interface ListSessionsResult {
  /** Total number of sessions */
  total_sessions: number;

  /** Session details */
  sessions: Array<{
    /** Session ID */
    session_id: string;

    /** Session metadata if available */
    metadata: SessionMetadata | null;
  }>;
}

/**
 * Result from searching memory
 */
export interface SearchMemoryResult {
  /** The search query that was executed */
  query: string;

  /** Total number of results found */
  total_results: number;

  /** Search results */
  results: Array<{
    /** Session containing the result */
    session_id: string;

    /** Summary identifier */
    summary_id: string;

    /** Relevance score as string */
    relevance: string;

    /** ISO timestamp */
    timestamp: string;

    /** Short snippet */
    snippet: string;

    /** Topics covered */
    topics: string[];

    /** Number of key decisions */
    key_decisions: number;

    /** Number of files modified */
    files_modified: number;
  }>;
}
