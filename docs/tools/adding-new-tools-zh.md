# 为 Godot MCP 添加自定义工具

本指南说明如何用自定义工具扩展 Godot MCP 系统。添加新工具需要同时修改 TypeScript 服务端和 Godot 插件端两边的文件。

## 架构概览

```
Claude (MCP 客户端) → FastMCP 服务器 (TypeScript) → WebSocket → Godot 编辑器 (GDScript)
```

命令名字符串连接着两端。同一个命令名（例如 `"my_new_tool"`）必须在三个位置保持精确一致：

1. TypeScript 中 MCP 工具的 `name` 字段
2. TypeScript 中 `sendCommand` 的类型字符串
3. GDScript 中 `match` 分支的字符串

## 需要创建或修改的文件

| 步骤 | 文件 | 操作 | 语言 |
|------|------|--------|----------|
| 1 | `server/src/tools/XXXX_tools.ts` | **新建**工具数组 | TypeScript |
| 2 | `server/src/index.ts` | **编辑**导入并注册 | TypeScript |
| 3 | `addons/godot_mcp/commands/XXXX_commands.gd` | **新建**命令处理器 | GDScript |
| 4 | `addons/godot_mcp/command_handler.gd` | **编辑**实例化并注册 | GDScript |

## 第一步：定义 MCP 工具（TypeScript）

在 `server/src/tools/` 下新建文件。选择一个能反映工具功能的描述性名称。

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
    description: '向 Claude 描述该工具的功能',
    parameters: z.object({
      param1: z.string()
        .describe('面向 Claude 的参数说明'),
      param2: z.number().optional()
        .describe('可选参数的说明'),
    }),
    execute: async ({ param1, param2 }: MyNewToolParams): Promise<string> => {
      const godot = getGodotConnection();

      try {
        const result = await godot.sendCommand<CommandResult>('my_new_tool', {
          param1,
          param2,
        });
        return `操作完成：${JSON.stringify(result)}`;
      } catch (error) {
        throw new Error(`失败：${(error as Error).message}`);
      }
    },
  },
];
```

### 要点

- `name` 字段（`"my_new_tool"`）是 Claude 看到的标识符，同时也是发给 Godot 的键名
- `parameters` 使用 Zod 进行校验；Zod 类型决定了 MCP 客户端看到并验证的内容
- `execute` 接收验证后的参数，返回 `Promise<string>`——这个字符串会展示给用户
- `getGodotConnection()` 返回单例；`sendCommand<T>(type, params)` 通过 WebSocket 发送请求，返回的 `Promise<T>` 会解析为 Godot 响应中的 `result` 字段

## 第二步：注册工具（TypeScript）

编辑 `server/src/index.ts`。添加两行：一个导入语句和注册数组中的展开。

```typescript
// 在文件顶部添加导入
import { myNewTools } from './tools/my_new_tools.js';

// 在 main() 函数中，更新数组：
[...nodeTools, ...scriptTools, ...sceneTools, ...editorTools, ...myNewTools].forEach(tool => {
  server.addTool(tool);
});
```

注册完成后，重新构建服务端：`cd server && npm run build`

## 第三步：创建命令处理器（GDScript）

在 `addons/godot_mcp/commands/` 下新建文件。该类必须继承 `MCPBaseCommandProcessor` 并重写 `process_command()`。

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
    return false  # 未被本处理器处理


func _my_new_tool(
    client_id: int,
    params: Dictionary,
    command_id: String
) -> void:
    var param1: String = params.get("param1", "")
    var param2: int = params.get("param2", 0)

    # 在此处编写你的逻辑——与 Godot API 交互
    # ...

    _send_success(client_id, {"result_key": "some_value"}, command_id)
```

### 从 `MCPBaseCommandProcessor` 继承的辅助方法

| 方法 | 用途 |
|--------|---------|
| `_send_success(client_id, result_dict, command_id)` | 发送成功响应。`result_dict` 可包含任意 JSON 可序列化的数据。 |
| `_send_error(client_id, message, command_id)` | 发送错误响应。`message` 是供人阅读的错误描述。 |
| `_get_editor_node(path)` | 将节点路径（如 `"/root/Player"`）解析为 `Node` 引用。找不到则返回 `null`。 |
| `_mark_scene_modified()` | 将编辑中的场景标记为已修改，提示用户保存。 |
| `_get_undo_redo()` | 获取 `EditorUndoRedoManager`，用于支持正确的撤销/重做。 |
| `_parse_property_value(value)` | 将 Godot 类型的字符串表示（Vector3、Color 等）解析为原生对象。 |

### 服务端期望的响应格式

服务端期望收到的 JSON 响应包含：
- `status`：`"success"` 或 `"error"`
- `result`：包含任意数据的对象（仅成功时）
- `message`：错误描述（仅错误时）
- `commandId`：必须回传收到的 `commandId`，以便服务端关联响应

`_send_success` 和 `_send_error` 方法会自动处理这些格式。

## 第四步：注册命令处理器（GDScript）

编辑 `addons/godot_mcp/command_handler.gd`。在 `_initialize_command_processors()` 中添加三行：

```gdscript
# 在 "Create and add all command processors" 下方：
var my_new_commands = MCPMyNewCommands.new()

# 设置服务器引用：
my_new_commands._websocket_server = _websocket_server

# 添加到处理器列表：
_command_processors.append(my_new_commands)

# 添加为子节点：
add_child(my_new_commands)
```

## 请求/响应流程

```
1. Claude 调用 my_new_tool，参数为 {"param1": "hello", "param2": 42}
2. FastMCP 根据 Zod schema 验证参数
3. myNewTools[0].execute() 调用 godotConnection.sendCommand('my_new_tool', {...})
4. WebSocket 发送：{"type":"my_new_tool","params":{...},"commandId":"cmd_0"}
5. MCPCommandHandler._handle_command() 遍历命令处理器
6. MCPMyNewCommands.process_command() 匹配到 "my_new_tool"，执行 _my_new_tool()
7. Godot 发送响应：{"status":"success","result":{...},"commandId":"cmd_0"}
8. godotConnection 解析 pending 状态的 Promise
9. execute() 将格式化后的字符串返回给 Claude
```

## 错误处理

- **校验错误**：如果 Zod 校验失败，MCP 客户端会在任何 WebSocket 通信之前收到参数错误
- **连接错误**：如果 WebSocket 未连接，`sendCommand()` 会先尝试连接，失败则拒绝 Promise 并返回连接错误
- **命令超时**：如果 Godot 在 20 秒内无响应，Promise 会以超时错误拒绝
- **Godot 端错误**：在 GDScript 中使用 `_send_error()` 返回结构化的错误响应

## 示例：添加 `rotate_node` 工具

### TypeScript（`server/src/tools/rotate_tools.ts`）

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
    description: '将节点绕指定轴旋转指定度数',
    parameters: z.object({
      node_path: z.string()
        .describe('要旋转的节点路径'),
      axis: z.enum(['x', 'y', 'z'])
        .describe('旋转轴'),
      degrees: z.number()
        .describe('旋转度数'),
    }),
    execute: async ({ node_path, axis, degrees }: RotateNodeParams): Promise<string> => {
      const godot = getGodotConnection();
      try {
        const result = await godot.sendCommand<CommandResult>('rotate_node', {
          node_path,
          axis,
          degrees,
        });
        return `已将 ${node_path} 绕 ${axis} 轴旋转 ${degrees} 度`;
      } catch (error) {
        throw new Error(`旋转节点失败：${(error as Error).message}`);
      }
    },
  },
];
```

### GDScript（`addons/godot_mcp/commands/rotate_commands.gd`）

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
        _send_error(client_id, "节点未找到：%s" % node_path, command_id)
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

## WebSocket 协议

TypeScript 服务端与 Godot 编辑器之间的协议是基于 JSON 的请求/响应模型：

### 命令（服务端 → Godot）
```json
{
  "type": "command_name",
  "params": {
    "key": "value"
  },
  "commandId": "cmd_0"
}
```

### 成功响应（Godot → 服务端）
```json
{
  "status": "success",
  "result": {
    "key": "value"
  },
  "commandId": "cmd_0"
}
```

### 错误响应（Godot → 服务端）
```json
{
  "status": "error",
  "message": "出错的详细描述",
  "commandId": "cmd_0"
}
```

## 故障排查

| 症状 | 可能原因 | 检查方法 |
|---------|-------------|-------|
| Claude 中找不到工具 | MCP 服务端未重新构建 | 在 `server/` 中运行 `npm run build` |
| "Unknown command" 错误 | 命令名不匹配 | 检查 TypeScript `name`、`sendCommand` 和 GDScript `match` 中的字符串是否一致 |
| "Parent node not found" | 路径格式无效 | 根节点用 `/root`，子节点用 `/root/ChildName` |
| "Node not found" | 场景未打开或路径错误 | 确认场景已在编辑器中打开，路径格式正确 |
| 超时 | Godot 无响应 | 检查 Godot 中 MCP 面板是否显示服务器正在运行 |
| "Cannot access EditorInterface" | 插件未启用 | 在项目设置 → 插件中启用 godot_mcp 插件 |

## 文件结构总览

```
godot-mcp/
├── server/
│   └── src/
│       ├── index.ts                       # ← 编辑：导入 + 注册
│       └── tools/
│           ├── node_tools.ts
│           ├── script_tools.ts
│           ├── scene_tools.ts
│           ├── editor_tools.ts
│           └── XXXX_tools.ts              # ← 新建
├── addons/
│   └── godot_mcp/
│       ├── command_handler.gd             # ← 编辑：实例化 + 注册
│       └── commands/
│           ├── base_command_processor.gd
│           ├── node_commands.gd
│           ├── script_commands.gd
│           ├── scene_commands.gd
│           ├── project_commands.gd
│           ├── editor_commands.gd
│           └── XXXX_commands.gd           # ← 新建
└── docs/
    └── adding-new-tools-zh.md             # 本文件
```