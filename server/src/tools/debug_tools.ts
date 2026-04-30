import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

interface ReadLogsParams {
  source: 'editor' | 'runtime';
  type?: string[];
  count?: number;
  offset?: number;
  order?: 'asc' | 'desc';
}

function sanitizeLogText(value: unknown): string {
  const message = typeof value === 'string' ? value : JSON.stringify(value);
  return message
    .replace(/\u001b\[[0-9;]*m/g, '')
    .replace(/^\[[0-9;]*m/, '')
    .replace(/\[[0-9;]*m$/g, '')
    .replace(/[\u0000-\u0008\u000B-\u001F\u007F]/g, '')
    .trimEnd();
}

export const debugTools: MCPTool[] = [
  {
    name: 'read_logs',
    description: 'Read editor or runtime logs from Godot with pagination, sorting, and total count',
    parameters: z.object({
      source: z.enum(['editor', 'runtime'])
        .describe('Log source: "editor" for editor output panel, "runtime" for user://logs/godot.log'),
      type: z.array(z.enum(['General', 'Warning', 'Error', 'Script', 'info'])).optional()
        .describe('Log types to filter (e.g., ["Error", "Warning"]). If not provided, returns all types.'),
      count: z.number().int().min(1).max(1000).optional().default(10)
        .describe('Number of log entries to return (1-1000, default 10)'),
      offset: z.number().int().min(0).optional().default(0)
        .describe('Zero-based starting index (default 0)'),
      order: z.enum(['asc', 'desc']).optional().default('desc')
        .describe('Sort order: "desc" newest first (default), "asc" oldest first'),
    }),
    execute: async ({ source, type = [], count = 10, offset = 0, order = 'desc' }: ReadLogsParams): Promise<string> => {
      const godot = getGodotConnection();
      try {
        const result = await godot.sendCommand<CommandResult>('read_logs', {
          source,
          type: type.length ? type : undefined,
          count,
          offset,
          order,
        });

        const total = result.total_count ?? 0;
        const logs = Array.isArray(result.logs) ? result.logs : [];
        const typeInfo = type.length ? `types=${type.join(', ')}, ` : '';
        const header = `Source: ${source}\nReturned: ${logs.length}/${total} (${typeInfo}offset=${offset}, order=${order})`;

        if (logs.length === 0) {
          return `${header}\n\nNo log entries matched.`;
        }

        const formattedLogs = logs
          .map((entry, index) => {
            const logIndex = entry.index ?? index;
            const logType = entry.type ?? 'unknown';
            const message = sanitizeLogText(entry.message);
            return `[${logIndex}] ${logType}: ${message}`;
          })
          .join('\n');

        return `${header}\n\n${formattedLogs}`;
      } catch (error) {
        throw new Error(`Failed to read logs: ${(error as Error).message}`);
      }
    },
  },
];