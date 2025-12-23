#!/usr/bin/env node
/**
 * CLI tool for analyzing conversation history and identifying pruneable tool outputs
 * Adapted for Claude Code from OpenCode plugin
 */

import { readFileSync } from 'fs'
import { deduplicate } from '../lib/strategies/deduplication'
import { supersedeWrites } from '../lib/strategies/supersede-writes'
import { createSessionState } from '../lib/state'
import { Logger } from '../lib/logger'
import type { Config } from '../lib/config'

interface Message {
  role: string
  content: Array<{ type: string; text?: string; name?: string; input?: unknown; output?: unknown }>
}

interface AnalysisResult {
  totalToolCalls: number
  pruneableOutputs: number
  estimatedTokenSavings: number
  breakdown: {
    deduplication: { count: number; tokens: number; details: string[] }
    supersedeWrites: { count: number; tokens: number; details: string[] }
    semantic: { count: number; tokens: number; details: string[] }
  }
}

/**
 * Load conversation history from stdin or file
 */
function loadConversationHistory(): Message[] {
  const input = process.argv[2]

  if (!input) {
    console.error('Error: No input provided. Usage: analyze.ts <conversation-file.json>')
    process.exit(1)
  }

  try {
    const content = readFileSync(input, 'utf-8')
    return JSON.parse(content)
  } catch (error) {
    console.error(`Error reading conversation file: ${error}`)
    process.exit(1)
  }
}

/**
 * Estimate token count for text content
 * Rough approximation: 1 token ≈ 4 characters
 */
function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4)
}

/**
 * Analyze conversation and identify pruneable outputs
 */
function analyzeConversation(messages: Message[]): AnalysisResult {
  const state = createSessionState()
  const logger = new Logger(false)

  // Default config for analysis
  const config: Config = {
    enabled: true,
    debug: false,
    pruningSummary: 'detailed',
    strategies: {
      deduplication: {
        enabled: true,
        protectedTools: []
      },
      supersedeWrites: {
        enabled: true
      },
      pruneTool: {
        enabled: false,
        protectedTools: [],
        nudge: { enabled: false, frequency: 10 }
      },
      onIdle: {
        enabled: false,
        protectedTools: [],
        showModelErrorToasts: false,
        strictModelSelection: false
      }
    }
  }

  // Create a copy of messages to analyze
  const messagesCopy = JSON.parse(JSON.stringify(messages))

  // Track tool calls before pruning
  let totalToolCalls = 0
  for (const msg of messagesCopy) {
    if (Array.isArray(msg.content)) {
      for (const block of msg.content) {
        if (block.type === 'tool_use' || block.type === 'tool_result') {
          totalToolCalls++
        }
      }
    }
  }

  // Run deduplication strategy
  const dedupResult = deduplicate(state, logger, config, messagesCopy)

  // Run supersede writes strategy
  const supersedeResult = supersedeWrites(state, logger, config, messagesCopy)

  // Calculate results
  const result: AnalysisResult = {
    totalToolCalls,
    pruneableOutputs: state.prunedToolIds.size,
    estimatedTokenSavings: state.stats.tokensSaved,
    breakdown: {
      deduplication: {
        count: dedupResult?.count || 0,
        tokens: dedupResult?.tokens || 0,
        details: dedupResult?.details || []
      },
      supersedeWrites: {
        count: supersedeResult?.count || 0,
        tokens: supersedeResult?.tokens || 0,
        details: supersedeResult?.details || []
      },
      semantic: {
        count: 0,
        tokens: 0,
        details: []
      }
    }
  }

  return result
}

/**
 * Format and print analysis results
 */
function printResults(result: AnalysisResult): void {
  console.log('\n## Context Pruning Analysis\n')
  console.log(`**Total Tool Calls**: ${result.totalToolCalls}`)
  console.log(`**Pruneable Outputs**: ${result.pruneableOutputs}`)
  console.log(`**Estimated Token Savings**: ~${result.estimatedTokenSavings} tokens\n`)

  console.log('### Breakdown by Strategy\n')

  // Deduplication
  const { deduplication, supersedeWrites, semantic } = result.breakdown

  if (deduplication.count > 0) {
    console.log(`#### Deduplication (${deduplication.count} outputs, ~${deduplication.tokens} tokens)`)
    for (const detail of deduplication.details) {
      console.log(`- ${detail}`)
    }
    console.log()
  }

  // Supersede writes
  if (supersedeWrites.count > 0) {
    console.log(`#### Supersede Writes (${supersedeWrites.count} outputs, ~${supersedeWrites.tokens} tokens)`)
    for (const detail of supersedeWrites.details) {
      console.log(`- ${detail}`)
    }
    console.log()
  }

  // Semantic (placeholder for future implementation)
  if (semantic.count > 0) {
    console.log(`#### Semantic Analysis (${semantic.count} outputs, ~${semantic.tokens} tokens)`)
    for (const detail of semantic.details) {
      console.log(`- ${detail}`)
    }
    console.log()
  }

  // Recommendation
  console.log('### Recommendation\n')
  if (result.pruneableOutputs > 0) {
    console.log(`Pruning ${result.pruneableOutputs} tool outputs would save approximately ${result.estimatedTokenSavings} tokens.`)
    console.log('Consider using the `/compact` command to reduce context size.')
  } else {
    console.log('No obvious pruning opportunities found. Context is already optimized.')
  }
}

/**
 * Main execution
 */
function main(): void {
  const messages = loadConversationHistory()
  const result = analyzeConversation(messages)
  printResults(result)
}

main()
