#!/usr/bin/env node

/**
 * Test script for Context Memory MCP Server
 *
 * Provides utilities to test the MCP server functionality including:
 * - Storing test summaries
 * - Searching memory
 * - Retrieving summaries
 * - Managing sessions
 */

import { spawn } from 'child_process';
import * as readline from 'readline';

interface MCPRequest {
  jsonrpc: '2.0';
  id: number;
  method: string;
  params?: any;
}

interface MCPResponse {
  jsonrpc: '2.0';
  id: number;
  result?: any;
  error?: {
    code: number;
    message: string;
    data?: any;
  };
}

class MCPClient {
  private serverProcess: any;
  private requestId = 0;
  private pendingRequests = new Map<number, (response: MCPResponse) => void>();

  constructor(private serverPath: string) {}

  async start(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.serverProcess = spawn('node', [this.serverPath], {
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      this.serverProcess.on('error', reject);

      const rl = readline.createInterface({
        input: this.serverProcess.stdout,
        crlfDelay: Infinity,
      });

      rl.on('line', (line) => {
        try {
          const response = JSON.parse(line) as MCPResponse;
          const handler = this.pendingRequests.get(response.id);
          if (handler) {
            handler(response);
            this.pendingRequests.delete(response.id);
          }
        } catch (error) {
          console.error('Failed to parse response:', error);
        }
      });

      // Wait for server to be ready
      setTimeout(resolve, 1000);
    });
  }

  async request(method: string, params?: any): Promise<any> {
    const id = ++this.requestId;
    const request: MCPRequest = {
      jsonrpc: '2.0',
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      this.pendingRequests.set(id, (response) => {
        if (response.error) {
          reject(new Error(response.error.message));
        } else {
          resolve(response.result);
        }
      });

      this.serverProcess.stdin.write(JSON.stringify(request) + '\n');

      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error('Request timeout'));
        }
      }, 30000);
    });
  }

  async listTools(): Promise<any> {
    return this.request('tools/list');
  }

  async callTool(name: string, args: any): Promise<any> {
    return this.request('tools/call', {
      name,
      arguments: args,
    });
  }

  stop(): void {
    if (this.serverProcess) {
      this.serverProcess.kill();
    }
  }
}

// ============================================================================
// Test Functions
// ============================================================================

async function testListTools(client: MCPClient): Promise<void> {
  console.log('\n=== Testing tools/list ===');
  const tools = await client.listTools();
  console.log('Available tools:');
  tools.tools.forEach((tool: any) => {
    console.log(`  - ${tool.name}: ${tool.description}`);
  });
}

async function testStoreSummary(client: MCPClient, sessionId: string): Promise<any> {
  console.log('\n=== Testing store_summary ===');

  const summary = {
    timestamp: new Date().toISOString(),
    compaction_trigger: 'manual',
    token_count_before: 150000,
    token_count_after: 100000,
    summary: {
      executive: 'Test summary for MCP server validation. This is a test of the context memory storage system.',
      key_decisions: [
        {
          topic: 'Testing Strategy',
          decision: 'Use automated tests for MCP server',
          rationale: 'Ensures reliability and catches regressions early',
          files: ['memory/scripts/test-mcp-server.ts'],
        },
      ],
      files_modified: [
        {
          path: 'memory/mcp-server/index.ts',
          action: 'created',
          purpose: 'MCP server implementation with semantic search',
        },
      ],
      code_snippets: [],
      topics: ['testing', 'mcp', 'context-memory'],
      tasks_completed: ['Create MCP server', 'Implement search functionality'],
      tasks_pending: ['Add vector embeddings', 'Optimize search algorithm'],
    },
  };

  const result = await client.callTool('store_summary', {
    session_id: sessionId,
    summary,
  });

  console.log('Store result:', JSON.parse(result.content[0].text));
  return JSON.parse(result.content[0].text);
}

async function testSearchMemory(client: MCPClient, query: string): Promise<void> {
  console.log(`\n=== Testing search_memory: "${query}" ===`);

  const result = await client.callTool('search_memory', {
    query,
    limit: 5,
    min_relevance: 0.1,
  });

  console.log('Search results:', JSON.parse(result.content[0].text));
}

async function testGetSummary(
  client: MCPClient,
  sessionId: string,
  summaryId: string
): Promise<void> {
  console.log(`\n=== Testing get_summary: ${sessionId}/${summaryId} ===`);

  const result = await client.callTool('get_summary', {
    session_id: sessionId,
    summary_id: summaryId,
  });

  const summary = JSON.parse(result.content[0].text);
  console.log('Summary retrieved:');
  console.log('  Timestamp:', summary.timestamp);
  console.log('  Executive:', summary.summary.executive.substring(0, 100) + '...');
  console.log('  Topics:', summary.summary.topics.join(', '));
  console.log('  Key decisions:', summary.summary.key_decisions.length);
}

async function testListSessions(client: MCPClient): Promise<void> {
  console.log('\n=== Testing list_sessions ===');

  const result = await client.callTool('list_sessions', {});

  const data = JSON.parse(result.content[0].text);
  console.log(`Total sessions: ${data.total_sessions}`);
  data.sessions.forEach((session: any) => {
    console.log(`  - ${session.session_id}`);
    if (session.metadata) {
      console.log(`    Compactions: ${session.metadata.total_compactions}`);
      console.log(`    Last updated: ${session.metadata.last_updated}`);
    }
  });
}

async function testGetSessionMetadata(client: MCPClient, sessionId: string): Promise<void> {
  console.log(`\n=== Testing get_session_metadata: ${sessionId} ===`);

  const result = await client.callTool('get_session_metadata', {
    session_id: sessionId,
  });

  const metadata = JSON.parse(result.content[0].text);
  console.log('Session metadata:', metadata);
}

// ============================================================================
// Main Test Suite
// ============================================================================

async function runTests(): Promise<void> {
  const serverPath = process.argv[2] || '../mcp-server/dist/index.js';
  const testSessionId = `test_session_${Date.now()}`;

  console.log('Starting Context Memory MCP Server tests...');
  console.log('Server path:', serverPath);
  console.log('Test session ID:', testSessionId);

  const client = new MCPClient(serverPath);

  try {
    // Start the server
    console.log('\nStarting server...');
    await client.start();
    console.log('Server started successfully');

    // Run tests
    await testListTools(client);

    const storeResult = await testStoreSummary(client, testSessionId);
    const summaryId = storeResult.summary_id;

    await testSearchMemory(client, 'testing MCP');
    await testSearchMemory(client, 'vector embeddings');
    await testSearchMemory(client, 'context memory storage');

    if (summaryId) {
      await testGetSummary(client, testSessionId, summaryId);
    }

    await testListSessions(client);
    await testGetSessionMetadata(client, testSessionId);

    console.log('\n=== All tests completed successfully! ===');
  } catch (error) {
    console.error('\nTest failed:', error);
    process.exit(1);
  } finally {
    client.stop();
  }
}

// Run tests if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runTests().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { MCPClient, runTests };
