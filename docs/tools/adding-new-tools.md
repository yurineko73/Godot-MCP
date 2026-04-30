# Adding Custom Tools to Godot MCP

This guide explains how to extend the Godot MCP system with custom tools. Adding a new tool requires modifying files on both the TypeScript server side and the Godot addon side.

## Architecture Overview

```
Claude (MCP client) → FastMCP Server (TypeScript) → WebSocket → Godot Editor (GDScript)
```

The command name string bridges the two sides. A single command name (e.g., `"my_new_tool"`) must match in three places:

1. The MCP tool `name` field in TypeScript
2. The `sendCommand` type string in TypeScript
3. The `match` case string in GDScript

## Files to Create or Modify

| Step | File | Action | Language |
|------|------|--------|----------|
| 1 | `server/src/tools/XXXX_tools.ts` | **Create** new tool array | TypeScript |
| 2 | `server/src/index.ts` | **Edit** import and register | TypeScript |
| 3 | `addons/godot_mcp/commands/XXXX_commands.gd` | **Create** command processor | GDScript |
| 4 | `addons/godot_mcp/command_handler.gd` | **Edit** instantiate and register | GDScript |

## Step 1: Define the MCP Tool (TypeScript)

Create a new file in `server/src/tools/`. Choose a descriptive name that reflects what the tool does.

```typescript
import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

interface MyNewToolParams {
  param1: string;
  param2?: number;
}

export const myNewTools: MCPTool[] = [
  {
    name: 'my_new_tool',
    description: 'Description of what the tool does for Claude',
    parameters: z.object({
      param1: z.string()
        .describe('Description for Claude'),
      param2: z.number().optional()
        .describe('Optional parameter description'),
    }),
    execute: async ({ param1, param2 }: MyNewToolParams): Promise<string> => {
      const godot = getGodotConnection();

      try {
        const result = await godot.sendCommand<CommandResult>('my_new_tool', {
          param1,
          param2,
        });
        return `Operation completed: ${JSON.stringify(result)}`;
      } catch (error) {
        throw new Error(`Failed: ${(error as Error).message}`);
      }
    },
  },
];
```

### Key points

- The `name` field (`"my_new_tool"`) is the identifier Claude sees and the key sent to Godot
- `parameters` uses Zod for validation; Zod types determine what the MCP client sees and validates
- `execute` receives the validated parameters and returns a `Promise<string>` — this string is shown to the user
- `getGodotConnection()` returns a singleton; `sendCommand<T>(type, params)` sends the request via WebSocket and returns a `Promise<T>` resolved with the `result` field from Godot's response

## Step 2: Register the Tool (TypeScript)

Edit `server/src/index.ts`. Add two lines: an import and a spread into the registration array.

```typescript
// Add import at top
import { myNewTools } from './tools/my_new_tools.js';

// Inside main(), update the array:
[...nodeTools, ...scriptTools, ...sceneTools, ...editorTools, ...myNewTools].forEach(tool => {
  server.addTool(tool);
});
```

After registration, rebuild the server: `cd server && npm run build`

## Step 3: Create the Command Processor (GDScript)

Create a new file in `addons/godot_mcp/commands/`. The class must extend `MCPBaseCommandProcessor` and override `process_command()`.

```gdscript
@tool
class_name MCPMyNewCommands
extends MCPBaseCommandProcessor

func process_command(
    client_id: int,
    command_type: String,
    params: Dictionary,
    command_id: String
) -> bool:
    match command_type:
        "my_new_tool":
            _my_new_tool(client_id, params, command_id)
            return true
    return false  # Not handled by this processor


func _my_new_tool(
    client_id: int,
    params: Dictionary,
    command_id: String
) -> void:
    var param1: String = params.get("param1", "")
    var param2: int = params.get("param2", 0)

    # Your logic here — interact with Godot's API
    # ...

    _send_success(client_id, {"result_key": "some_value"}, command_id)
```

### Inherited helper methods from `MCPBaseCommandProcessor`

| Method | Purpose |
|--------|---------|
| `_send_success(client_id, result_dict, command_id)` | Send a success response back. `result_dict` can contain any JSON-serializable data. |
| `_send_error(client_id, message, command_id)` | Send an error response. `message` is a human-readable string. |
| `_get_editor_node(path)` | Resolve a node path (e.g., `"/root/Player"`) to a `Node` reference. Returns `null` if not found. |
| `_mark_scene_modified()` | Mark the edited scene as modified so the user is prompted to save. |
| `_get_undo_redo()` | Get the `EditorUndoRedoManager` for proper undo/redo support. |
| `_parse_property_value(value)` | Parse string representations of Godot types (Vector3, Color, etc.) into native objects. |

### Response format expected by the server

The server expects a JSON response with:
- `status`: `"success"` or `"error"`
- `result`: an object with any data (only on success)
- `message`: error description (only on error)
- `commandId`: must echo the incoming `commandId` for the server to correlate the response

The `_send_success` and `_send_error` methods handle this formatting automatically.

## Step 4: Register the Command Processor (GDScript)

Edit `addons/godot_mcp/command_handler.gd`. Add three lines in `_initialize_command_processors()`:

```gdscript
# Under "Create and add all command processors":
var my_new_commands = MCPMyNewCommands.new()

# Set server reference:
my_new_commands._websocket_server = _websocket_server

# Add to processor list:
_command_processors.append(my_new_commands)

# Add as child:
add_child(my_new_commands)
```

## Request/Response Flow

```
1. Claude invokes my_new_tool with {"param1": "hello", "param2": 42}
2. FastMCP validates parameters against Zod schema
3. myNewTools[0].execute() calls godotConnection.sendCommand('my_new_tool', {...})
4. WebSocket sends: {"type":"my_new_tool","params":{...},"commandId":"cmd_0"}
5. MCPCommandHandler._handle_command() iterates command processors
6. MCPMyNewCommands.process_command() matches "my_new_tool", runs _my_new_tool()
7. Godot sends response: {"status":"success","result":{...},"commandId":"cmd_0"}
8. godotConnection resolves the pending promise
9. execute() returns the formatted string to Claude
```

## Error Handling

- **Validation errors**: If Zod validation fails, the MCP client receives a parameter error before any WebSocket communication happens
- **Connection errors**: If the WebSocket is not connected, `sendCommand()` attempts to connect first, then rejects with a connection error
- **Command timeout**: If Godot does not respond within 20 seconds, the promise rejects with a timeout error
- **Godot-side errors**: Use `_send_error()` in GDScript to return structured error responses

## Example: Adding a `rotate_node` Tool

### TypeScript (`server/src/tools/rotate_tools.ts`)

```typescript
import { z } from 'zod';
import { getGodotConnection } from '../utils/godot_connection.js';
import { MCPTool, CommandResult } from '../utils/types.js';

interface RotateNodeParams {
  node_path: string;
  axis: string;
  degrees: number;
}

export const rotateTools: MCPTool[] = [
  {
    name: 'rotate_node',
    description: 'Rotate a node around a given axis by the specified degrees',
    parameters: z.object({
      node_path: z.string()
        .describe('Path to the node to rotate'),
      axis: z.enum(['x', 'y', 'z'])
        .describe('Axis to rotate around'),
      degrees: z.number()
        .describe('Degrees to rotate'),
    }),
    execute: async ({ node_path, axis, degrees }: RotateNodeParams): Promise<string> => {
      const godot = getGodotConnection();
      try {
        const result = await godot.sendCommand<CommandResult>('rotate_node', {
          node_path,
          axis,
          degrees,
        });
        return `Rotated ${node_path} around ${axis}-axis by ${degrees} degrees`;
      } catch (error) {
        throw new Error(`Failed to rotate node: ${(error as Error).message}`);
      }
    },
  },
];
```

### GDScript (`addons/godot_mcp/commands/rotate_commands.gd`)

```gdscript
@tool
class_name MCPRotateCommands
extends MCPBaseCommandProcessor

func process_command(
    client_id: int,
    command_type: String,
    params: Dictionary,
    command_id: String
) -> bool:
    match command_type:
        "rotate_node":
            _rotate_node(client_id, params, command_id)
            return true
    return false


func _rotate_node(
    client_id: int,
    params: Dictionary,
    command_id: String
) -> void:
    var node_path: String = params.get("node_path", "")
    var axis: String = params.get("axis", "y")
    var degrees: float = params.get("degrees", 0.0)

    var node = _get_editor_node(node_path)
    if not node:
        _send_error(client_id, "Node not found: %s" % node_path, command_id)
        return

    var radians = deg_to_rad(degrees)

    match axis:
        "x":
            node.rotate_x(radians)
        "y":
            node.rotate_y(radians)
        "z":
            node.rotate_z(radians)

    _mark_scene_modified()

    _send_success(client_id, {
        "node_path": node_path,
        "axis": axis,
        "degrees": degrees
    }, command_id)
```

## WebSocket Protocol

The protocol between the TypeScript server and Godot editor is a JSON-based request/response model:

### Command (Server → Godot)
```json
{
  "type": "command_name",
  "params": {
    "key": "value"
  },
  "commandId": "cmd_0"
}
```

### Success Response (Godot → Server)
```json
{
  "status": "success",
  "result": {
    "key": "value"
  },
  "commandId": "cmd_0"
}
```

### Error Response (Godot → Server)
```json
{
  "status": "error",
  "message": "Description of what went wrong",
  "commandId": "cmd_0"
}
```

## Troubleshooting

| Symptom | Likely cause | Check |
|---------|-------------|-------|
| Tool not available in Claude | MCP server wasn't rebuilt | Run `npm run build` in `server/` |
| "Unknown command" error | Command name mismatch | Verify the string matches in TypeScript `name`, `sendCommand`, and GDScript `match` |
| "Parent node not found" | Invalid path format | Use `/root` for root, `/root/ChildName` for children |
| "Node not found" | Scene not open or wrong path | Verify scene is open in editor, path format is correct |
| Timeout | Godot not responding | Check MCP panel in Godot shows server is running |
| "Cannot access EditorInterface" | Plugin not enabled | Enable the godot_mcp plugin in Project Settings → Plugins |

## File Structure Summary

```
godot-mcp/
├── server/
│   └── src/
│       ├── index.ts                       # ← Edit: import + register
│       └── tools/
│           ├── node_tools.ts
│           ├── script_tools.ts
│           ├── scene_tools.ts
│           ├── editor_tools.ts
│           └── XXXX_tools.ts              # ← Create
├── addons/
│   └── godot_mcp/
│       ├── command_handler.gd             # ← Edit: instantiate + register
│       └── commands/
│           ├── base_command_processor.gd
│           ├── node_commands.gd
│           ├── script_commands.gd
│           ├── scene_commands.gd
│           ├── project_commands.gd
│           ├── editor_commands.gd
│           └── XXXX_commands.gd           # ← Create
└── docs/
    └── adding-new-tools.md                # This file
```