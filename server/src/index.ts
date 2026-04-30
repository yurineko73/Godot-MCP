import { FastMCP } from 'fastmcp';
import { nodeTools } from './tools/node_tools.js';
import { scriptTools } from './tools/script_tools.js';
import { sceneTools } from './tools/scene_tools.js';
import { editorTools } from './tools/editor_tools.js';
import { debugTools } from './tools/debug_tools.js';
import { getGodotConnection } from './utils/godot_connection.js';

// Import resources
import { 
  sceneListResource, 
  sceneStructureResource 
} from './resources/scene_resources.js';
import { 
  scriptResource, 
  scriptListResource,
  scriptMetadataResource 
} from './resources/script_resources.js';
import { 
  projectStructureResource,
  projectSettingsResource,
  projectResourcesResource 
} from './resources/project_resources.js';
import { 
  editorStateResource,
  selectedNodeResource,
  currentScriptResource 
} from './resources/editor_resources.js';

// Supress all debug output during startup to keep stdout clean for MCP stdio transport.
// Any output to stdout or stderr before the transport is ready will corrupt the protocol.
const originalConsoleError = console.error;
const originalConsoleWarn = console.warn;
const originalConsoleLog = console.log;
const noop = () => {};
console.error = noop;
console.warn = noop;
console.log = noop;

/**
 * Main entry point for the Godot MCP server
 */
async function main() {

  // Create FastMCP instance
  const server = new FastMCP({
    name: 'GodotMCP',
    version: '1.0.0',
  });

  // Register all tools
  [...nodeTools, ...scriptTools, ...sceneTools, ...editorTools, ...debugTools].forEach(tool => {
    server.addTool(tool);
  });

  // Register all resources
  // Static resources
  server.addResource(sceneListResource);
  server.addResource(scriptListResource);
  server.addResource(projectStructureResource);
  server.addResource(projectSettingsResource);
  server.addResource(projectResourcesResource);
  server.addResource(editorStateResource);
  server.addResource(selectedNodeResource);
  server.addResource(currentScriptResource);
  server.addResource(sceneStructureResource);
  server.addResource(scriptResource);
  server.addResource(scriptMetadataResource);

  // Try to connect to Godot
  try {
    const godot = getGodotConnection();
    await godot.connect();
  } catch (error) {
    // Godot not running is expected; tools will reconnect on demand
  }

  // Start the transport BEFORE restoring console output
  await server.start({
    transportType: 'stdio',
  });

  // Transport is now active - it's safe to restore stderr logging.
  // stdout must remain MCP-only; stderr can be used for user-facing logs.
  console.error = originalConsoleError;
  console.warn = originalConsoleWarn;
  // console.log remains suppressed to keep stdout clean

  console.error('Godot MCP server started');

  // Handle cleanup
  const cleanup = () => {
    console.error('Shutting down Godot MCP server...');
    const godot = getGodotConnection();
    godot.disconnect();
    process.exit(0);
  };

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);
}

// Start the server
main().catch(error => {
  originalConsoleError('Failed to start Godot MCP server:', error);
  process.exit(1);
});
