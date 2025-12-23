/**
 * Vector Embeddings Module
 *
 * Provides vector embedding generation and similarity search capabilities
 * for semantic context retrieval. Supports multiple embedding providers:
 * - Anthropic API (Claude embeddings)
 * - OpenAI API (text-embedding-3-small/large)
 * - Local models (sentence-transformers via Python)
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// ============================================================================
// Configuration
// ============================================================================

export interface EmbeddingConfig {
  provider: 'anthropic' | 'openai' | 'local';
  model?: string;
  apiKey?: string;
  dimensions?: number;
  batchSize?: number;
}

export interface EmbeddingResult {
  vector: number[];
  dimensions: number;
  model: string;
}

export interface VectorSearchResult {
  id: string;
  score: number;
  metadata?: Record<string, any>;
}

// ============================================================================
// Anthropic Embeddings (Future Support)
// ============================================================================

/**
 * Generate embeddings using Anthropic's API
 * Note: As of Dec 2023, Anthropic doesn't have a public embeddings API
 * This is a placeholder for future support
 */
async function generateAnthropicEmbedding(
  text: string,
  config: EmbeddingConfig
): Promise<EmbeddingResult> {
  throw new Error('Anthropic embeddings API not yet available');

  // Future implementation would look like:
  // const response = await fetch('https://api.anthropic.com/v1/embeddings', {
  //   method: 'POST',
  //   headers: {
  //     'Content-Type': 'application/json',
  //     'x-api-key': config.apiKey || '',
  //   },
  //   body: JSON.stringify({
  //     model: config.model || 'claude-embedding-v1',
  //     input: text,
  //   }),
  // });
  // const data = await response.json();
  // return {
  //   vector: data.embedding,
  //   dimensions: data.embedding.length,
  //   model: config.model || 'claude-embedding-v1',
  // };
}

// ============================================================================
// OpenAI Embeddings
// ============================================================================

/**
 * Generate embeddings using OpenAI's API
 */
async function generateOpenAIEmbedding(
  text: string,
  config: EmbeddingConfig
): Promise<EmbeddingResult> {
  const apiKey = config.apiKey || process.env.OPENAI_API_KEY;

  if (!apiKey) {
    throw new Error('OpenAI API key not provided');
  }

  const model = config.model || 'text-embedding-3-small';

  try {
    const response = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        input: text,
        dimensions: config.dimensions,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`OpenAI API error: ${response.status} - ${error}`);
    }

    const data = await response.json();

    return {
      vector: data.data[0].embedding,
      dimensions: data.data[0].embedding.length,
      model,
    };
  } catch (error) {
    throw new Error(`Failed to generate OpenAI embedding: ${error}`);
  }
}

// ============================================================================
// Local Embeddings (sentence-transformers)
// ============================================================================

/**
 * Generate embeddings using local sentence-transformers model
 * Requires Python with sentence-transformers installed
 */
async function generateLocalEmbedding(
  text: string,
  config: EmbeddingConfig
): Promise<EmbeddingResult> {
  const model = config.model || 'all-MiniLM-L6-v2';

  // Create Python script for embedding generation
  const pythonScript = `
import sys
import json
from sentence_transformers import SentenceTransformer

try:
    model = SentenceTransformer('${model}')
    text = sys.stdin.read()
    embedding = model.encode(text).tolist()
    result = {
        "vector": embedding,
        "dimensions": len(embedding),
        "model": "${model}"
    }
    print(json.dumps(result))
except Exception as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
`;

  try {
    const { stdout, stderr } = await execAsync(
      'python3 -c \'' + pythonScript.replace(/'/g, "'\\''") + '\'',
      {
        input: text,
        maxBuffer: 10 * 1024 * 1024, // 10MB buffer
      }
    );

    const result = JSON.parse(stdout);

    if (result.error) {
      throw new Error(result.error);
    }

    return result as EmbeddingResult;
  } catch (error) {
    throw new Error(
      `Failed to generate local embedding. Ensure Python and sentence-transformers are installed: ${error}`
    );
  }
}

// ============================================================================
// Main Embedding Generator
// ============================================================================

/**
 * Generate embeddings using the configured provider
 */
export async function generateEmbedding(
  text: string,
  config: EmbeddingConfig
): Promise<EmbeddingResult> {
  // Truncate text if too long (most models have token limits)
  const maxLength = 8000; // Conservative limit
  const truncatedText = text.length > maxLength
    ? text.substring(0, maxLength)
    : text;

  switch (config.provider) {
    case 'anthropic':
      return await generateAnthropicEmbedding(truncatedText, config);

    case 'openai':
      return await generateOpenAIEmbedding(truncatedText, config);

    case 'local':
      return await generateLocalEmbedding(truncatedText, config);

    default:
      throw new Error(`Unknown embedding provider: ${config.provider}`);
  }
}

/**
 * Generate embeddings for multiple texts (batch processing)
 */
export async function generateEmbeddingBatch(
  texts: string[],
  config: EmbeddingConfig
): Promise<EmbeddingResult[]> {
  const batchSize = config.batchSize || 10;
  const results: EmbeddingResult[] = [];

  // Process in batches to avoid rate limits
  for (let i = 0; i < texts.length; i += batchSize) {
    const batch = texts.slice(i, i + batchSize);
    const batchResults = await Promise.all(
      batch.map(text => generateEmbedding(text, config))
    );
    results.push(...batchResults);

    // Small delay between batches
    if (i + batchSize < texts.length) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }

  return results;
}

// ============================================================================
// Vector Similarity Functions
// ============================================================================

/**
 * Calculate cosine similarity between two vectors
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error('Vectors must have the same dimensions');
  }

  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  normA = Math.sqrt(normA);
  normB = Math.sqrt(normB);

  if (normA === 0 || normB === 0) {
    return 0;
  }

  return dotProduct / (normA * normB);
}

/**
 * Calculate Euclidean distance between two vectors
 */
export function euclideanDistance(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error('Vectors must have the same dimensions');
  }

  let sum = 0;
  for (let i = 0; i < a.length; i++) {
    const diff = a[i] - b[i];
    sum += diff * diff;
  }

  return Math.sqrt(sum);
}

/**
 * Calculate dot product similarity
 */
export function dotProductSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error('Vectors must have the same dimensions');
  }

  let sum = 0;
  for (let i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }

  return sum;
}

// ============================================================================
// Vector Search
// ============================================================================

export interface VectorStore {
  id: string;
  vector: number[];
  metadata?: Record<string, any>;
}

/**
 * Search for similar vectors using cosine similarity
 */
export function searchVectors(
  queryVector: number[],
  vectors: VectorStore[],
  topK: number = 5,
  minScore: number = 0.7
): VectorSearchResult[] {
  const results: VectorSearchResult[] = [];

  for (const item of vectors) {
    const score = cosineSimilarity(queryVector, item.vector);

    if (score >= minScore) {
      results.push({
        id: item.id,
        score,
        metadata: item.metadata,
      });
    }
  }

  // Sort by score (descending) and take top K
  return results
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

// ============================================================================
// Persistence
// ============================================================================

/**
 * Save embeddings to a JSON file
 */
export async function saveEmbeddings(
  filePath: string,
  embeddings: VectorStore[]
): Promise<void> {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(
    filePath,
    JSON.stringify(embeddings, null, 2),
    'utf-8'
  );
}

/**
 * Load embeddings from a JSON file
 */
export async function loadEmbeddings(
  filePath: string
): Promise<VectorStore[]> {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      return [];
    }
    throw error;
  }
}

// ============================================================================
// Configuration Detection
// ============================================================================

/**
 * Auto-detect best available embedding provider
 */
export async function detectBestProvider(): Promise<EmbeddingConfig> {
  // Check for OpenAI API key
  if (process.env.OPENAI_API_KEY) {
    return {
      provider: 'openai',
      model: 'text-embedding-3-small',
      dimensions: 1536,
    };
  }

  // Check for Python and sentence-transformers
  try {
    await execAsync('python3 -c "import sentence_transformers"');
    return {
      provider: 'local',
      model: 'all-MiniLM-L6-v2',
    };
  } catch {
    // Fall back to basic text similarity (no embeddings)
    throw new Error(
      'No embedding provider available. Please install Python with sentence-transformers or set OPENAI_API_KEY'
    );
  }
}

/**
 * Test if embeddings are available and working
 */
export async function testEmbeddings(config: EmbeddingConfig): Promise<boolean> {
  try {
    const result = await generateEmbedding('test', config);
    return result.vector.length > 0;
  } catch {
    return false;
  }
}
