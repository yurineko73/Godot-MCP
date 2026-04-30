---
name: add-read-logs-tool
overview: 创建 read_logs MCP 工具（已更新：新增 type 参数用于按日志类型过滤），支持从编辑器输出面板和运行时日志文件读取日志，提供分页、排序、偏移、类型过滤和总数统计，参数错误时优雅降级处理。
todos:
  - id: create-ts-tool
    content: Create server/src/tools/debug_tools.ts with read_logs tool definition, Zod validation (including type parameter), and execute handler
    status: completed
  - id: register-ts
    content: Edit server/src/index.ts to import debugTools and add to registration array
    status: completed
  - id: create-gd-commands
    content: Create addons/godot_mcp/commands/debug_commands.gd with MCPDebugCommands class (editor + runtime log reading with type filtering)
    status: completed
  - id: register-gd
    content: Edit addons/godot_mcp/command_handler.gd to instantiate and register MCPDebugCommands
    status: completed
  - id: verify-build
    content: Run npm run build in server/ and verify Godot editor compiles with new GDScript
    status: completed
isProject: false
---

## 架构

```
Claude --read_logs--> FastMCP (TypeScript) --WebSocket--> Godot (GDScript)
```

命令名 `read_logs` 必须在 TypeScript 和 GDScript 两侧完全一致。

## 需要修改的 4 个文件

- 新建 `server/src/tools/debug_tools.ts` -- TypeScript 端工具定义，Zod 验证，execute 处理函数
- 编辑 `server/src/index.ts` -- 顶部 import，注册数组中展开
- 新建 `addons/godot_mcp/commands/debug_commands.gd` -- GDScript 命令处理器，编辑器日志 / 运行时日志两种来源
- 编辑 `addons/godot_mcp/command_handler.gd` -- 实例化并注册新处理器

## 实现设计

### TypeScript 端 (server/src/tools/debug_tools.ts)

- 工具名: `read_logs`
- 参数 (Zod 验证):
  - `source`: `z.enum(['editor', 'runtime'])` -- 必填，选 editor 读取编辑器输出面板，选 runtime 读取 user://logs/godot.log
  - `type`: `z.array(z.enum(['General', 'Warning', 'Error', 'Script', 'info'])).optional()` -- 日志类型过滤，选填。可选值: General（常规）、Warning（警告）、Error（错误）、Script（脚本）、info（运行时信息）。不填返回全部类型。编辑器日志有前四种类型，运行时日志统一为 info
  - `count`: `z.number().int().min(1).max(1000).optional().default(10)` -- 返回条数，1-1000，默认 10
  - `offset`: `z.number().int().min(0).optional().default(0)` -- 起始索引，从 0 开始
  - `order`: `z.enum(['asc', 'desc']).optional().default('desc')` -- 排序，desc 最新优先，asc 最早优先
- execute: 调用 `godot.sendCommand('read_logs', {source, type, count, offset, order})`，返回格式化摘要。type 数组通过 JSON 传递

### GDScript 端 (addons/godot_mcp/commands/debug_commands.gd)

- 类名: `MCPDebugCommands`，继承 `MCPBaseCommandProcessor`
- `_read_logs()`: 主处理函数，根据 source 参数分发到两个子函数，传递 type 数组
- `_read_editor_logs()`:
  - 通过 `EditorInterface.get_editor_log()` 获取日志对象
  - 调用 `get_log_count()` 获取总数
  - 在遍历日志时使用 `get_message_type_name(idx)` 获取类型字符串，与 type 数组比对过滤
  - 根据 order 和 offset 遍历：倒序则从 `total - offset - 1` 开始往回取 count 条；正序则从 offset 开始往后取 count 条
  - 只收集 type 匹配的条目，直到达到 count 条或遍历完所有日志
  - 每条返回 `{"index": idx, "type": 日志类型, "message": 内容}`
- `_read_runtime_logs()`:
  - 用 `FileAccess.open("user://logs/godot.log", FileAccess.READ)` 读取文件
  - 按行读入 all_lines 数组
  - 同上逻辑应用 type 过滤、offset/count/order
  - 运行时日志的 type 统一为 "info"，如果 type 参数不含 "info" 则运行时日志返回空
  - 每条返回 `{"index": 行号, "type": "info", "message": 内容}`
  - 优雅降级：文件不存在时返回错误

### 注册

- `server/src/index.ts`: 顶部添加 `import { debugTools } from './tools/debug_tools.js'`，在 `[...nodeTools, ...scriptTools, ...sceneTools, ...editorTools, ...debugTools]` 中展开
- `addons/godot_mcp/command_handler.gd`: 在 `_initialize_command_processors()` 中添加 `var debug_commands = MCPDebugCommands.new()`，设置 `_websocket_server`，`append` 到列表，`add_child`

### 响应格式

成功:
```json
{
  "status": "success",
  "result": {
    "logs": [{"index": 0, "type": "Error", "message": "..."}, ...],
    "total_count": 156,
    "source": "editor"
  }
}
```

错误:
```json
{
  "status": "error",
  "message": "Runtime log file not found: user://logs/godot.log"
}
```

### 错误处理策略

- 参数不合法: Zod 在 TypeScript 端拦截，返回 MCP 参数错误
- 日志文件不存在: 返回错误消息
- count 超限: Zod 限制 max=1000，自动拒绝
- offset 超出范围: 返回空 logs 数组，total_count 正常返回
- type 不匹配: 返回空 logs 数组（不是错误，total_count 仍正常返回）
- 插件未加载: 返回错误消息