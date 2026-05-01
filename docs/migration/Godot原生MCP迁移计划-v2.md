# Godot 原生 MCP 服务器迁移计划 v2.0

## 文档信息
- **创建日期**: 2026-04-30
- **版本**: v2.0 (基于 godot-dev-guide 和 mcp-builder 技能优化)
- **目标**: 将 Godot-MCP 项目从 Node.js/FastMCP 中介架构迁移到 Godot 原生实现
- **优化依据**: 
  - Godot 4.x 开发指南 (godot-dev-guide)
  - MCP 开发指南 (mcp-builder)
- **作者**: AI Assistant

---

## 1. 当前架构分析

### 1.1 现有架构（三层架构）

```
┌─────────────────┐      stdio (JSON-RPC 2.0)     ┌────────────────────┐
│   AI Client     │ ─────────────────────────────▶ │  Node.js MCP      │
│  (Claude etc.) │ ◀───────────────────────────── │  Server          │
└─────────────────┘      stdio (JSON-RPC 2.0)     │  (FastMCP)       │
                                                  └────────────────────┘
                                                                   │
                                                           WebSocket    │
                                                                   ▼
                                                  ┌────────────────────┐
                                                  │  Godot Addon      │
                                                  │  (WebSocket Server)│
                                                  └────────────────────┘
```

### 1.2 当前实现文件结构

#### Node.js MCP Server (`server/` 目录)
```
server/
├── src/
│   ├── index.ts                    # 主入口，FastMCP 实例创建
│   ├── tools/                      # MCP 工具定义（42+ 工具）
│   │   ├── node_tools.ts          # 节点操作工具（6个）
│   │   ├── script_tools.ts       # 脚本操作工具（5个）
│   │   ├── scene_tools.ts       # 场景操作工具（6个）
│   │   ├── editor_tools.ts      # 编辑器工具（5个）
│   │   └── debug_tools.ts      # 调试工具（多个）
│   ├── resources/                # MCP 资源定义
│   │   ├── scene_resources.ts   # 场景列表、结构资源
│   │   ├── script_resources.ts  # 脚本内容、列表资源
│   │   ├── project_resources.ts # 项目结构、设置资源
│   │   └── editor_resources.ts # 编辑器状态资源
│   └── utils/
│       ├── godot_connection.ts  # WebSocket 客户端连接
│       └── types.ts            # TypeScript 类型定义
├── dist/                        # 编译输出
├── package.json                 # 依赖：fastmcp, ws, zod
└── tsconfig.json
```

#### Godot Addon (`addons/godot_mcp/` 目录)
```
addons/godot_mcp/
├── mcp_server.gd               # 主插件类（EditorPlugin）
├── websocket_server.gd         # WebSocket 服务器实现
├── command_handler.gd          # 命令路由和处理
├── commands/                   # 命令处理器
│   ├── base_command_processor.gd
│   ├── node_commands.gd       # 节点命令实现
│   ├── script_commands.gd     # 脚本命令实现
│   ├── scene_commands.gd      # 场景命令实现
│   ├── project_commands.gd    # 项目命令实现
│   ├── editor_commands.gd     # 编辑器命令实现
│   └── debug_commands.gd      # 调试命令实现
├── utils/                      # 工具类
│   ├── node_utils.gd
│   ├── resource_utils.gd
│   └── script_utils.gd
└── ui/                        # UI 面板
    ├── mcp_panel.gd
    └── mcp_panel.tscn
```

### 1.3 当前架构问题

| 问题类别 | 具体描述 | 影响 |
|---------|-----------|------|
| **环境依赖** | 需要 Node.js + npm 安装依赖（fastmcp, ws, zod 等） | 提高使用门槛，环境配置复杂 |
| **通信延迟** | AI → Node.js → Godot 三次序列化/反序列化 | 响应时间增加 30%+ |
| **资源开销** | Node.js 进程占用 50-150MB 内存 | 低配设备运行困难 |
| **安全风险** | 通过字符串拼接执行命令，存在注入风险 | 潜在安全漏洞 |
| **调试困难** | 三层架构错误定位困难 | 维护成本高 |
| **代码分散** | TypeScript + GDScript 两套代码 | 开发效率降低 |

---

## 2. 目标架构设计

### 2.1 原生架构（单层架构）

```
┌─────────────────┐      stdio (JSON-RPC 2.0)     ┌────────────────────┐
│   AI Client     │ ─────────────────────────────▶ │  Godot Engine     │
│  (Claude etc.) │ ◀───────────────────────────── │  (MCP Server     │
└─────────────────┘      stdio (JSON-RPC 2.0)     │  原生实现)        │
                                                                   │
                                                              ┌───────┴──────┐
                                                              │ Godot Editor │
                                                              │ API 直接访问 │
                                                              └──────────────┘
```

### 2.2 核心设计思路

1. **传输层**: 使用 `OS.read_string_from_stdin()` 实现 stdio 传输
2. **协议层**: 使用 Godot 内置 `JSONRPC` 类处理 JSON-RPC 2.0
3. **工具层**: 使用 GDScript 实现所有 MCP 工具（带完整类型提示）
4. **并发处理**: 使用 `Thread` 实现非阻塞 stdin 监听
5. **架构模式**: 使用组合优于继承，信号用于解耦通信（根据 godot-dev-guide）

---

## 3. 详细迁移步骤

### 阶段一：基础设施搭建（预计 2-3 天）

#### 3.1.1 创建原生 MCP 服务器核心类

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

```gdscript
@tool
class_name MCPServerCore
extends RefCounted

# 信号（使用信号解耦通信 - 根据 godot-dev-guide）
signal server_started
signal server_stopped
signal message_received(message: Dictionary)
signal response_sent(response: Dictionary)
signal tool_execution_started(tool_name: String, params: Dictionary)
signal tool_execution_completed(tool_name: String, result: Dictionary)
signal tool_execution_failed(tool_name: String, error: String)

# 常量
const JSONRPC_VERSION: String = "2.0"
const PROTOCOL_VERSION: String = "2024-11-05"

# 状态变量（使用完整类型提示 - 根据 godot-dev-guide）
var _active: bool = false
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _message_queue: Array[Dictionary] = []
var _response_queue: Array[Dictionary] = []
var _tools: Dictionary = {}  # String -> MCPTool
var _resources: Dictionary = {}  # String -> Dictionary
var _tool_annotations: Dictionary = {}  # String -> Dictionary（新增）
```

#### 3.1.2 实现 stdio 传输层

**关键功能**:
- 在独立线程中监听 stdin
- 使用 `OS.read_string_from_stdin()` 读取数据
- 按行分割 JSON-RPC 消息（MCP 标准要求 `\n` 分隔）
- 使用 `call_deferred()` 将消息派发到主线程

**实现**（修正版，添加类型提示）:
```gdscript
func _stdin_listen_loop() -> void:
    while _active:
        var input: String = OS.read_string_from_stdin()
        if not input.is_empty():
            _parse_and_queue_message(input)
        OS.delay_msec(10)  # 避免 CPU 占用过高
```

#### 3.1.3 实现 JSON-RPC 2.0 协议处理器（修正版）

**使用 Godot 内置类**:
```gdscript
var _jsonrpc: JSONRPC = JSONRPC.new()

func _handle_request(message: Dictionary) -> Dictionary:
    # 验证 JSON-RPC 版本
    if message.get("jsonrpc") != JSONRPC_VERSION:
        return _error_response(message.get("id"), -32600, "Invalid Request")
    
    # 处理标准 MCP 方法（完整 capabilities 协商 - 根据 mcp-builder）
    match message.get("method"):
        "initialize":
            return _handle_initialize(message)
        "notifications/initialized":
            return _handle_initialized_notification(message)
        "tools/list":
            return _handle_tools_list(message)
        "tools/call":
            return _handle_tool_call(message)
        "resources/list":
            return _handle_resources_list(message)
        "resources/read":
            return _handle_resource_read(message)
        "resources/subscribe":
            return _handle_resource_subscribe(message)
        "prompts/list":
            return _handle_prompts_list(message)
        "prompts/get":
            return _handle_prompt_get(message)
        _:
            return _error_response(message.get("id"), -32601, "Method not found")

func _handle_initialize(message: Dictionary) -> Dictionary:
    var client_capabilities: Dictionary = message.get("params", {}).get("capabilities", {})
    var client_protocol_version: String = message.get("params", {}).get("protocolVersion", "2024-11-05")
    
    # 返回服务器 capabilities（完整版 - 根据 mcp-builder）
    var result: Dictionary = {
        "protocolVersion": PROTOCOL_VERSION,
        "capabilities": {
            "tools": {"listChanged": true},
            "resources": {"subscribe": true, "listChanged": true},
            "prompts": {"listChanged": true}  # 如果需要
        },
        "serverInfo": {
            "name": "godot-native-mcp",
            "version": "2.0.0"
        }
    }
    
    return {
        "jsonrpc": JSONRPC_VERSION,
        "id": message.get("id"),
        "result": result
    }
```

### 阶段二：工具迁移（预计 5-7 天）

#### 3.2.1 工具注册机制设计（优化版）

**目标**: 模拟 FastMCP 的 `@mcp.tool` 装饰器模式，并添加 annotations 和 outputSchema（根据 mcp-builder）

```gdscript
# 工具元数据类（完整版 - 根据 mcp-builder）
class MCPTool:
    var name: String
    var description: String
    var input_schema: Dictionary
    var output_schema: Dictionary  # 新增（根据 mcp-builder）
    var annotations: Dictionary  # 新增（根据 mcp-builder）
    var callable: Callable
    
    func to_dict() -> Dictionary:
        var result: Dictionary = {
            "name": name,
            "description": description,
            "inputSchema": input_schema
        }
        
        # 添加 outputSchema（根据 mcp-builder）
        if not output_schema.is_empty():
            result["outputSchema"] = output_schema
        
        # 添加 annotations（根据 mcp-builder）
        if not annotations.is_empty():
            result["annotations"] = annotations
        
        return result

# 工具注册表（优化版）
func register_tool(name: String, description: String, 
                  input_schema: Dictionary, callable: Callable,
                  output_schema: Dictionary = {}, 
                  annotations: Dictionary = {}) -> void:
    var tool: MCPTool = MCPTool.new()
    tool.name = name
    tool.description = description
    tool.input_schema = input_schema
    tool.output_schema = output_schema  # 新增
    tool.annotations = annotations  # 新增
    tool.callable = callable
    _tools[name] = tool
```

#### 3.2.2 迁移 Node Tools（6 个工具 - 完整优化版）

| 工具名称 | 当前实现位置 | 目标实现 | 优先级 | 注释 |
|---------|-------------|---------|--------|---------|
| `create_node` | `node_tools.ts` → `node_commands.gd` | 原生实现 | 高 | readOnly=false, destructive=false |
| `delete_node` | `node_tools.ts` → `node_commands.gd` | 原生实现 | 高 | readOnly=false, destructive=true |
| `update_node_property` | `node_tools.ts` → `node_commands.gd` | 原生实现 | 高 | readOnly=false, destructive=false |
| `get_node_properties` | `node_tools.ts` → `node_commands.gd` | 原生实现 | 中 | readOnly=true |
| `list_nodes` | `node_tools.ts` → `node_commands.gd` | 原生实现 | 中 | readOnly=true |
| `get_scene_tree` | 待确认 | 新增工具 | 高 | readOnly=true |

**完整实现示例** (`create_node` - 根据 godot-dev-guide 优化):

```gdscript
func _register_node_tools() -> void:
    # 注册 create_node 工具（完整版 - 根据 mcp-builder）
    var tool: MCPTool = MCPTool.new()
    tool.name = "create_node"
    tool.description = "Create a new node in the Godot scene tree. Returns the node path and type. Example: parent_path='/root', node_type='Node2D', node_name='Player'"
    
    # inputSchema（根据 mcp-builder）
    tool.input_schema = {
        "type": "object",
        "properties": {
            "parent_path": {
                "type": "string", 
                "description": "Path to the parent node where the new node will be created (e.g. '/root', '/root/MainScene')"
            },
            "node_type": {
                "type": "string", 
                "description": "Type of node to create (e.g. 'Node2D', 'Sprite2D', 'CharacterBody2D')"
            },
            "node_name": {
                "type": "string", 
                "description": "Name for the new node"
            }
        },
        "required": ["parent_path", "node_type", "node_name"]
    }
    
    # outputSchema（新增 - 根据 mcp-builder）
    tool.output_schema = {
        "type": "object",
        "properties": {
            "status": {"type": "string"},
            "node_path": {"type": "string"},
            "node_type": {"type": "string"}
        }
    }
    
    # annotations（新增 - 根据 mcp-builder）
    tool.annotations = {
        "readOnlyHint": false,
        "destructiveHint": false,
        "idempotentHint": false,
        "openWorldHint": false
    }
    
    tool.callable = Callable(self, "_tool_create_node")
    _tools[tool.name] = tool

func _tool_create_node(params: Dictionary) -> Dictionary:
    # 参数提取（带完整类型提示 - 根据 godot-dev-guide）
    var parent_path: String = params.get("parent_path", "")
    var node_type: String = params.get("node_type", "Node")
    var node_name: String = params.get("node_name", "NewNode")
    
    # 获取编辑器接口（带类型提示 - 根据 godot-dev-guide）
    var editor_interface: EditorInterface = _get_editor_interface()
    if not editor_interface:
        return {"error": "Editor interface not available"}
    
    # 获取父节点
    var parent: Node = editor_interface.get_edited_scene_root()
    if parent_path != "/root" and not parent_path.is_empty():
        var relative_path: String = parent_path.trim_prefix("/root/")
        parent = parent.get_node_or_null(relative_path)
    
    if not parent:
        return {"error": "Parent node not found: " + parent_path}
    
    # 使用 ClassDB 实例化节点（根据 godot-dev-guide）
    if not ClassDB.class_exists(node_type):
        return {"error": "Invalid node type: " + node_type}
    
    var node: Node = ClassDB.instantiate(node_type)
    node.name = node_name
    parent.add_child(node)
    
    # 设置 owner 以便在编辑器中可见（根据 godot-dev-guide）
    var scene_root: Node = editor_interface.get_edited_scene_root()
    if scene_root:
        node.owner = scene_root
    
    # 标记场景为已修改（根据 godot-dev-guide）
    editor_interface.mark_scene_as_unsaved()
    
    # 发送信号（根据 godot-dev-guide 信号模式）
    tool_execution_completed.emit("create_node", {
        "status": "success",
        "node_path": str(node.get_path()),
        "node_type": node.get_class()
    })
    
    return {
        "status": "success",
        "node_path": str(node.get_path()),
        "node_type": node.get_class()
    }
```

#### 3.2.3 迁移 Script Tools（5 个工具）

| 工具名称 | 功能描述 | 实现要点 |
|---------|----------|---------|
| `list_project_scripts` | 列出所有脚本 | 使用 `DirAccess` 遍历 `res://`，使用类型提示 |
| `read_script` | 读取脚本内容 | 使用 `FileAccess` 读取 `.gd` 文件，注意文件格式差异（根据 godot-dev-guide） |
| `create_script` | 创建新脚本 | 使用 `GDScript` + `FileAccess`，注意 `.gd` 是完整语言（根据 godot-dev-guide） |
| `modify_script` | 修改脚本内容 | 直接写入文件 + 触发重新加载 |
| `analyze_script` | 分析脚本结构 | 使用 `get_method_list()` 等内省 API |

**重要提醒**（根据 godot-dev-guide）:
- `.gd` 文件是完整的 GDScript 程序代码
- 不要混淆 `.gd` 和 `.tscn`/`.tres` 格式
- `.tscn` 和 `.tres` 是严格的序列化格式，不是 GDScript

#### 3.2.4 迁移 Scene Tools（6 个工具）

| 工具名称 | 功能描述 | 实现要点 |
|---------|----------|---------|
| `create_scene` | 创建新场景 | `PackedScene.new()` + `ResourceSaver.save()` |
| `save_scene` | 保存当前场景 | `editor_interface.save_scene()` |
| `open_scene` | 打开场景 | `editor_interface.open_scene_from_path()` |
| `get_current_scene` | 获取当前场景信息 | 读取 `edited_scene_root` 属性 |
| `get_scene_structure` | 获取场景树结构 | 递归遍历节点树，注意 `.tscn` 格式（根据 godot-dev-guide） |
| `list_project_scenes` | 列出所有场景 | 遍历 `res://` 查找 `.tscn` 文件 |

**重要提醒**（根据 godot-dev-guide）:
- `.tscn` 文件是场景序列化格式，不是 GDScript
- 不要在这种文件中使用 GDScript 语法
- 使用 `PackedScene` 和 `ResourceLoader` 正确操作

#### 3.2.5 迁移 Editor Tools（5 个工具）

| 工具名称 | 功能描述 | 实现要点 |
|---------|----------|---------|
| `get_editor_state` | 获取编辑器状态 | 使用 `EditorInterface` API，带类型提示 |
| `run_project` | 运行项目 | `editor_interface.play_current_scene()` |
| `stop_project` | 停止运行 | `editor_interface.stop_playing_scene()` |
| `get_selected_nodes` | 获取选中节点 | `editor_interface.get_selection()` |
| `set_editor_setting` | 设置编辑器属性 | `EditorSettings` singleton |

#### 3.2.6 迁移 Debug Tools（多个工具）

| 工具名称 | 功能描述 | 实现要点 |
|---------|----------|---------|
| `get_editor_logs` | 获取编辑器日志 | 使用自定义 Logger 类，带类型提示 |
| `execute_script` | 执行脚本代码 | 使用 `Expression` 类 |
| `get_performance_metrics` | 获取性能指标 | `Performance` singleton |
| `debug_print` | 输出调试信息 | `print()` 函数包装 |

### 阶段三：资源实现（预计 2-3 天）

#### 3.3.1 MCP 资源定义（优化版 - 根据 mcp-builder）

**资源 URI 规范**:
- `godot://scene/current` - 当前打开的场景
- `godot://scene/list` - 所有场景列表
- `godot://script/current` - 当前打开的脚本
- `godot://script/list` - 所有脚本列表
- `godot://project/info` - 项目信息
- `godot://project/settings` - 项目设置
- `godot://editor/state` - 编辑器状态

**实现示例**（修正版，添加 description - 根据 mcp-builder）:
```gdscript
func _register_resources() -> void:
    # 注册场景列表资源（完整版 - 根据 mcp-builder）
    _resources["godot://scene/list"] = {
        "name": "Godot Scene List",
        "description": "List of all .tscn scene files in the project",  # 新增（根据 mcp-builder）
        "mimeType": "application/json",
        "load": Callable(self, "_resource_scene_list")
    }
    
    # 注册当前场景资源
    _resources["godot://scene/current"] = {
        "name": "Current Scene",
        "description": "Structure of the currently open scene in the editor",
        "mimeType": "application/json",
        "load": Callable(self, "_resource_scene_current")
    }

func _resource_scene_list(params: Dictionary) -> Dictionary:
    var scenes: Array[String] = []
    var dir: DirAccess = DirAccess.open("res://")
    _find_files_recursive(dir, ".tscn", scenes)
    
    return {
        "contents": [{
            "uri": "godot://scene/list",
            "mimeType": "application/json",
            "text": JSON.stringify({"scenes": scenes, "count": scenes.size()})
        }]
    }
```

### 阶段四：安全增强（预计 1-2 天）

#### 3.4.1 路径白名单机制（增强版）

```gdscript
const ALLOWED_PATHS: Array[String] = ["res://", "user://"]
const BLOCKED_PATTERNS: Array[String] = ["..", "~", "$", "|", ";", "`"]

func _validate_path(path: String) -> bool:
    # 检查白名单
    var is_allowed: bool = false
    for allowed in ALLOWED_PATHS:
        if path.begins_with(allowed):
            is_allowed = true
            break
    
    if not is_allowed:
        return false
    
    # 检查黑名单模式（增强 - 根据 mcp-builder 安全最佳实践）
    for pattern in BLOCKED_PATTERNS:
        if path.contains(pattern):
            return false
    
    # 检查路径长度
    if path.length() > 4096:
        return false
    
    return true

func _sanitize_path(path: String) -> String:
    # 移除路径遍历攻击向量
    var sanitized: String = path.replace("..", "").replace("~", "")
    if not sanitized.begins_with("res://") and not sanitized.begins_with("user://"):
        sanitized = "res://" + sanitized.lstrip("/")
    return sanitized
```

#### 3.4.2 用户确认机制（优化版）

```gdscript
signal confirmation_required(operation: String, details: Dictionary)
var _pending_confirmations: Dictionary = {}  # String -> Dictionary

func _request_confirmation(operation: String, details: Dictionary, 
                          callback: Callable) -> void:
    var confirm_id: String = _generate_id()
    _pending_confirmations[confirm_id] = {
        "operation": operation,
        "details": details,
        "callback": callback,
        "timestamp": Time.get_time_from_system()  # 新增时间戳
    }
    
    # 显示确认对话框（在主线程）
    call_deferred("_show_confirmation_dialog", confirm_id)

func _show_confirmation_dialog(confirm_id: String) -> void:
    # 创建确认对话框（根据 godot-dev-guide UI 模式）
    var dialog: ConfirmationDialog = ConfirmationDialog.new()
    dialog.title = "Confirm Operation"
    
    var details: Dictionary = _pending_confirmations[confirm_id]["details"]
    dialog.dialog_text = "Do you want to execute: " + details.get("tool_name", "Unknown") + "?"
    
    dialog.confirmed.connect(func(): _on_confirmation_result(confirm_id, true))
    dialog.canceled.connect(func(): _on_confirmation_result(confirm_id, false))
    
    # 添加到场景树
    get_tree().root.add_child(dialog)
    dialog.popup_centered()
```

#### 3.4.3 新增：速率限制（根据 mcp-builder 安全最佳实践）

```gdscript
var _request_count: Dictionary = {}  # String (client_id) -> int
var _request_timestamps: Dictionary = {}  # String (client_id) -> Array[int]
var _rate_limit: int = 100  # 每 60 秒最多 100 个请求

func _check_rate_limit(client_id: String) -> bool:
    var current_time: int = Time.get_unix_time_from_system()
    
    if not _request_timestamps.has(client_id):
        _request_timestamps[client_id] = []
        _request_count[client_id] = 0
    
    var timestamps: Array[int] = _request_timestamps[client_id]
    
    # 移除 60 秒前的记录
    while not timestamps.is_empty() and current_time - timestamps[0] > 60:
        timestamps.pop_front()
        _request_count[client_id] -= 1
    
    # 检查是否超过限制
    if _request_count[client_id] >= _rate_limit:
        return false
    
    # 添加新记录
    timestamps.append(current_time)
    _request_count[client_id] += 1
    
    return true
```

### 阶段五：UI 集成（预计 2-3 天）

#### 3.5.1 更新插件主类（优化版 - 根据 godot-dev-guide）

**文件**: `addons/godot_mcp/mcp_server_native.gd`

```gdscript
@tool
extends EditorPlugin

# 使用 @export 变量（根据 godot-dev-guide）
@export var auto_start: bool = false
@export_range(0, 3, 1) var log_level: int = 1  # 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
@export var security_level: int = 1  # 0=PERMISSIVE, 1=STRICT

var _native_server: MCPServerCore
var _bottom_panel: Control

func _enter_tree() -> void:
    # 创建原生 MCP 服务器实例
    _native_server = MCPServerCore.new()
    
    # 连接信号（根据 godot-dev-guide 信号模式）
    _native_server.server_started.connect(_on_server_started)
    _native_server.server_stopped.connect(_on_server_stopped)
    _native_server.tool_execution_started.connect(_on_tool_started)
    _native_server.tool_execution_completed.connect(_on_tool_completed)
    _native_server.tool_execution_failed.connect(_on_tool_failed)
    
    # 注册所有工具
    _register_all_tools()
    
    # 注册所有资源
    _register_all_resources()
    
    # 启动服务器（如果配置为自动启动）
    if auto_start:
        _start_native_server()

func _start_native_server() -> void:
    if _native_server.is_running():
        print("MCP Server already running")
        return
    
    _native_server.start()
    print("Native MCP Server started - listening on stdio")

# 使用 @export_group（根据 godot-dev-guide）
func _get_property_list() -> Array:
    var properties: Array = []
    
    # 添加属性分组
    properties.append({
        "name": "MCP Settings",
        "type": TYPE_NIL,
        "usage": PROPERTY_USAGE_CATEGORY
    })
    
    properties.append({
        "name": "auto_start",
        "type": TYPE_BOOL,
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    properties.append({
        "name": "log_level",
        "type": TYPE_INT,
        "hint": PROPERTY_HINT_RANGE,
        "hint_string": "0,3,1",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    return properties
```

#### 3.5.2 创建配置面板（优化版）

**新增 UI**: 允许用户配置：
- 自动启动开关
- 日志详细程度（使用 @export_range）
- 安全级别（严格/宽松）
- 启用/禁用特定工具
- 速率限制设置（新增）

---

## 4. 功能映射表

### 4.1 完整工具列表（42+ 工具）

#### Node Tools
| 工具名称 | 当前状态 | 迁移状态 | 注释 | 优先级 |
|---------|---------|---------|------|--------|
| `create_node` | ✅ 已实现 | ⏳ 待迁移 | 高优先级 | 高 |
| `delete_node` | ✅ 已实现 | ⏳ 待迁移 | 高优先级，destructive=true | 高 |
| `update_node_property` | ✅ 已实现 | ⏳ 待迁移 | 高优先级 | 高 |
| `get_node_properties` | ✅ 已实现 | ⏳ 待迁移 | 中优先级，readOnly=true | 中 |
| `list_nodes` | ✅ 已实现 | ⏳ 待迁移 | 中优先级，readOnly=true | 中 |
| `get_scene_tree` | ❌ 未实现 | 📝 待实现 | 新增，readOnly=true | 高 |

#### Script Tools
| 工具名称 | 当前状态 | 迁移状态 | 注释 |
|---------|---------|---------|------|
| `list_project_scripts` | ✅ 已实现 | ⏳ 待迁移 | readOnly=true |
| `read_script` | ✅ 已实现 | ⏳ 待迁移 | readOnly=true，注意 .gd 格式 |
| `create_script` | ✅ 已实现 | ⏳ 待迁移 | 注意 .gd 是完整语言 |
| `modify_script` | ✅ 已实现 | ⏳ 待迁移 |  |
| `analyze_script` | ✅ 已实现 | ⏳ 待迁移 |  |

#### Scene Tools
| 工具名称 | 当前状态 | 迁移状态 | 注释 |
|---------|---------|---------|------|
| `create_scene` | ✅ 已实现 | ⏳ 待迁移 |  |
| `save_scene` | ✅ 已实现 | ⏳ 待迁移 |  |
| `open_scene` | ✅ 已实现 | ⏳ 待迁移 |  |
| `get_current_scene` | ✅ 已实现 | ⏳ 待迁移 |  |
| `get_scene_structure` | ✅ 已实现 | ⏳ 待迁移 | 注意 .tscn 格式 |
| `list_project_scenes` | ✅ 已实现 | ⏳ 待迁移 |  |

#### Editor Tools
| 工具名称 | 当前状态 | 迁移状态 | 注释 |
|---------|---------|---------|------|
| `get_editor_state` | ✅ 已实现 | ⏳ 待迁移 |  |
| `run_project` | ✅ 已实现 | ⏳ 待迁移 |  |
| `stop_project` | ✅ 已实现 | ⏳ 待迁移 |  |
| `get_selected_nodes` | ✅ 已实现 | ⏳ 待迁移 |  |
| `set_editor_setting` | ❌ 未实现 | 📝 待实现 | 新增 |

#### Debug Tools
| 工具名称 | 当前状态 | 迁移状态 | 注释 |
|---------|---------|---------|------|
| `get_editor_logs` | ✅ 已实现 | ⏳ 待迁移 |  |
| `execute_script` | ❌ 未实现 | 📝 待实现 | 新增 |
| `get_performance_metrics` | ❌ 未实现 | 📝 待实现 | 新增 |
| `debug_print` | ❌ 未实现 | 📝 待实现 | 新增 |

#### Project Tools
| 工具名称 | 当前状态 | 迁移状态 | 注释 |
|---------|---------|---------|------|
| `get_project_info` | ✅ 已实现 | ⏳ 待迁移 |  |
| `get_project_settings` | ✅ 已实现 | ⏳ 待迁移 |  |
| `list_project_resources` | ✅ 已实现 | ⏳ 待迁移 |  |
| `create_resource` | ✅ 已实现 | ⏳ 待迁移 | 注意 .tres 格式 |

### 4.2 资源映射（优化版 - 根据 mcp-builder）

| 资源 URI | 当前状态 | 迁移状态 | 描述（新增） |
|---------|---------|---------|-------------|
| `godot://scene/list` | ✅ 已实现 | ⏳ 待迁移 | List of all .tscn scene files |
| `godot://scene/current` | ✅ 已实现 | ⏳ 待迁移 | Structure of current scene |
| `godot://script/list` | ✅ 已实现 | ⏳ 待迁移 | List of all .gd script files |
| `godot://script/current` | ✅ 已实现 | ⏳ 待迁移 | Content of current script |
| `godot://project/info` | ✅ 已实现 | ⏳ 待迁移 | Project name and version |
| `godot://project/settings` | ✅ 已实现 | ⏳ 待迁移 | Project setting values |
| `godot://editor/state` | ✅ 已实现 | ⏳ 待迁移 | Current editor state |

---

## 5. 文件结构规划

### 5.1 新文件结构（优化版）

```
addons/godot_mcp/
├── mcp_server_native.gd          # 新的主插件类（EditorPlugin）
├── native_mcp/
│   ├── mcp_server_core.gd       # 核心 MCP 服务器实现
│   ├── mcp_transport_stdio.gd  # stdio 传输层
│   ├── mcp_protocol.gd         # JSON-RPC 2.0 协议处理
│   ├── mcp_tool_registry.gd    # 工具注册表
│   ├── mcp_resource_manager.gd # 资源管理器
│   └── mcp_types.gd           # 类型定义和常量
├── tools/                        # 原生工具实现
│   ├── node_tools_native.gd    # 节点工具（原生版）
│   ├── script_tools_native.gd  # 脚本工具（原生版）
│   ├── scene_tools_native.gd   # 场景工具（原生版）
│   ├── editor_tools_native.gd  # 编辑器工具（原生版）
│   ├── debug_tools_native.gd   # 调试工具（原生版）
│   └── project_tools_native.gd # 项目工具（原生版）
├── ui/                           # 新 UI
│   ├── mcp_panel_native.gd     # 新的 UI 面板
│   ├── mcp_panel_native.tscn
│   └── settings_panel.gd      # 设置面板
├── utils/                        # 工具类
│   ├── path_validator.gd       # 路径验证工具
│   ├── code_analyzer.gd       # 代码分析工具
│   └── logger.gd              # 日志记录器
├── evaluations/                  # 新增：评估文件（根据 mcp-builder）
│   └── evaluation.xml        # 10 个评估问题
└── plugin.cfg                  # 插件配置（更新）
```

### 5.2 废弃文件清单

迁移完成后可删除的文件：
- `server/` 整个目录
- `addons/godot_mcp/websocket_server.gd`
- `addons/godot_mcp/command_handler.gd`
- `addons/godot_mcp/commands/` 旧版命令处理器
- `claude_desktop_config.json` (将提供新版本)

---

## 6. 兼容性策略

### 6.1 双栈并行运行（过渡期）

在迁移过程中，支持两种模式：
1. **原生模式**（新）: Godot 直接作为 MCP 服务器
2. **兼容模式**（旧）: 保留 WebSocket 服务器以支持旧版客户端

**配置示例**:
```gdscript
# plugin.cfg 或设置文件
[mcp]
mode="native"  # "native" 或 "compatible"
stdio_enabled=true
websocket_enabled=true  # 兼容模式
websocket_port=9080
```

### 6.2 Claude Desktop 配置迁移

**旧配置** (Node.js):
```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["PATH_TO_PROJECT/server/dist/index.js"],
      "env": {"MCP_TRANSPORT": "stdio"}
    }
  }
}
```

**新配置** (原生):
```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "C:\\Program Files\\Godot\\Godot_v4.x-stable_mono_win64.exe",
      "args": ["--path", "PATH_TO_PROJECT", "--headless", "--mcp-server"],
      "env": {}
    }
  }
}
```

---

## 7. 测试计划（优化版 - 根据 mcp-builder）

### 7.1 单元测试

| 测试类别 | 测试内容 | 工具 |
|---------|---------|------|
| 协议测试 | JSON-RPC 2.0 合规性 | Godot 内置测试框架 |
| 工具测试 | 每个工具的输入输出 | GDScript 测试脚本 |
| 资源测试 | 资源读取和列出 | 模拟数据测试 |
| 安全测试 | 路径遍历、命令注入 | 渗透测试脚本 |
| 性能测试 | 缓存机制、懒加载 | 基准测试脚本 |

### 7.2 集成测试

1. **与 Claude Desktop 集成测试**
   - 配置 Claude Desktop 使用原生服务器
   - 测试所有 42+ 个工具
   - 验证资源访问

2. **性能测试**
   - 对比迁移前后的响应时间
   - 内存占用对比
   - 并发请求处理

3. **稳定性测试**
   - 长时间运行测试（24 小时+）
   - 异常输入处理
   - 错误恢复能力

### 7.3 使用 MCP Inspector 测试（根据 mcp-builder）

**步骤 1: 启动 MCP Inspector**
```bash
npx @modelcontextprotocol/inspector
```

**步骤 2: 配置 Godot 服务器**
```json
{
  "command": "path/to/godot.exe",
  "args": ["--path", "path/to/project", "--headless", "--mcp-server"]
}
```

**步骤 3: 运行测试**
- 测试 `initialize` 请求
- 测试 `tools/list` 请求
- 测试 `tools/call` 请求
- 测试 `resources/list` 请求
- 测试 `resources/read` 请求

**步骤 4: 验证响应格式**
- 所有响应必须包含 `jsonrpc: "2.0"`
- 所有响应必须包含对应的 `id`
- 错误响应必须包含 `error` 对象

### 7.4 测试检查清单

- [ ] `initialize` 请求返回正确的 capabilities
- [ ] `tools/list` 返回所有注册的工具（带 annotations）
- [ ] `tools/call` 正确执行工具并返回结果（带 outputSchema）
- [ ] `resources/list` 返回所有注册的资源（带 description）
- [ ] `resources/read` 正确读取资源内容
- [ ] 错误处理返回标准 JSON-RPC 错误
- [ ] 路径验证阻止非法访问
- [ ] 大文件读取不会阻塞主线程
- [ ] 并发请求正确处理
- [ ] 速率限制正常工作
- [ ] 用户确认机制正常工作

---

## 8. 评估计划（新增 - 根据 mcp-builder Phase 4）

### 8.1 评估目的

使用评估来测试 LLMs 是否能有效地使用你的 MCP 服务器来回答现实、复杂的问题。

### 8.2 创建 10 个评估问题（根据 mcp-builder）

**要求**（根据 mcp-builder）:
- **Independent**: 不依赖于其他问题
- **Read-only**: 只需要非破坏性操作
- **Complex**: 需要多个工具调用和深度探索
- **Realistic**: 基于人类会关心的真实用例
- **Verifiable**: 单个、清晰的答案，可通过字符串比较验证
- **Stable**: 答案不会随时间改变

**示例问题**（基于 godot-dev-guide 和 mcp-builder）:

```xml
<evaluation>
  <qa_pair>
    <question>What are the names of all nodes in the current scene that have a "position" property?</question>
    <answer>[Array of node names]</answer>
  </qa_pair>
  
  <qa_pair>
    <question>Create a new scene with a CharacterBody2D as the root node. What is the default value of the "collision_layer" property?</question>
    <answer>1</answer>
  </qa_pair>
  
  <qa_pair>
    <question>List all scripts in the project that contain the string "signal". How many total signals are defined across all scripts?</question>
    <answer>[Count of signals]</answer>
  </qa_pair>
  
  <!-- 更多问题... -->
</evaluation>
```

### 8.3 评估执行（根据 mcp-builder）

```bash
# 使用 MCP Inspector 运行评估
npx @modelcontextprotocol/inspector --eval-file=eval/evaluation.xml --server=path/to/godot.exe
```

---

## 9. 性能优化建议（新增 - 根据 godot-dev-guide）

### 9.1 缓存机制

```gdscript
# 场景结构缓存
var _scene_structure_cache: Dictionary = {}  # String -> Dictionary
var _cache_timestamp: Dictionary = {}  # String -> int

func _get_scene_structure_cached(scene_path: String) -> Dictionary:
    var cache_key: String = scene_path
    var current_time: int = Time.get_unix_time_from_system()
    
    # 检查缓存是否有效（5 分钟有效期）
    if _scene_structure_cache.has(cache_key):
        var cache_time: int = _cache_timestamp.get(cache_key, 0)
        if current_time - cache_time < 300:  # 5 分钟
            return _scene_structure_cache[cache_key]
    
    # 重新计算
    var structure: Dictionary = _compute_scene_structure(scene_path)
    _scene_structure_cache[cache_key] = structure
    _cache_timestamp[cache_key] = current_time
    
    return structure
```

### 9.2 懒加载

```gdscript
# 按需加载工具
var _lazy_tools: Dictionary = {}  # String -> Callable

func _register_tool_lazy(name: String, loader: Callable) -> void:
    _lazy_tools[name] = loader

func _get_tool(name: String) -> Callable:
    if _tools.has(name):
        return _tools[name].callable
    
    if _lazy_tools.has(name):
        var loader: Callable = _lazy_tools[name]
        var tool: MCPTool = loader.call()
        _tools[name] = tool
        _lazy_tools.erase(name)
        return tool.callable
    
    return Callable()
```

---

## 10. 风险评估

### 10.1 技术风险

| 风险 | 影响 | 概率 | 缓解措施 |
|-----|------|------|---------|
| `OS.read_string_from_stdin()` 阻塞问题 | 高 | 中 | 使用 Thread 实现非阻塞读取 |
| Godot headless 模式限制 | 中 | 中 | 提供编辑器模式作为备选方案 |
| JSON-RPC 实现不完整 | 高 | 低 | 充分测试，参考官方规范 |
| 大型项目性能问题 | 中 | 低 | 实现缓存机制，优化遍历算法 |

### 10.2 兼容性风险

| 风险 | 影响 | 概率 | 缓解措施 |
|-----|------|------|---------|
| Claude Desktop 配置不兼容 | 高 | 高 | 提供详细的迁移指南 |
| 旧版 Godot 不支持 | 中 | 低 | 明确要求 Godot 4.2+ |
| 第三方工具依赖 | 低 | 中 | audit 所有外部依赖 |

---

## 11. 时间规划

### 11.1 开发时间表

```
Week 1:
  ├── Day 1-2: 基础设施搭建（阶段一）
  └── Day 3-5: 核心传输层和协议处理

Week 2:
  ├── Day 1-3: Node Tools 和 Scene Tools 迁移（阶段二）
  └── Day 4-5: Script Tools 和 Editor Tools 迁移

Week 3:
  ├── Day 1-2: Debug Tools 和 Project Tools 迁移
  ├── Day 3: 资源实现（阶段三）
  └── Day 4-5: 安全增强（阶段四）

Week 4:
  ├── Day 1-2: UI 集成（阶段五）
  ├── Day 3: 测试和优化（阶段七）
  └── Day 4-5: 评估和文档编写（阶段八）
```

### 11.2 里程碑

- **M1 (Week 1 结束)**: 基础 MCP 服务器可以响应 `initialize` 请求
- **M2 (Week 2 结束)**: 所有核心工具（Node/Scene/Script）迁移完成
- **M3 (Week 3 结束)**: 安全增强完成，可以进行内部测试
- **M4 (Week 4 结束)**: 评估完成，完整版本发布

---

## 12. 文档规划

### 12.1 用户文档

1. **快速开始指南** (`docs/quickstart-native.md`)
   - 安装步骤
   - Claude Desktop 配置
   - 第一个工具调用示例

2. **迁移指南** (`docs/migration-guide.md`)
   - 从 Node.js 版迁移的步骤
   - 配置对比
   - 常见问题解答

3. **工具参考手册** (`docs/tools-reference-native.md`)
   - 所有工具的详细文档
   - 参数说明和示例

### 12.2 开发者文档

1. **架构文档** (`docs/architecture-native.md`)
   - 原生架构设计
   - 类图和流程图

2. **贡献指南** (`docs/contributing-native.md`)
   - 如何添加新工具（根据 mcp-builder）
   - 代码规范（根据 godot-dev-guide）
   - 评估创建指南（根据 mcp-builder）

3. **API 文档** (自动生成)
   - GDScript 类文档

---

## 13. 后续优化方向

### 13.1 性能优化

1. **缓存机制**
   - 场景结构缓存
   - 脚本分析结果缓存
   - 项目资源索引

2. **懒加载**
   - 按需加载工具
   - 资源内容懒加载

### 13.2 功能扩展

1. **SSE 传输支持**
   - 远程访问支持
   - 多客户端连接

2. **高级调试功能**
   - 实时变量监视
   - 断点管理
   - 调用栈分析

3. **AI 辅助功能**
   - 代码补全增强
   - 自动重构建议
   - 性能优化建议

---

## 14. 附录

### 14.1 参考资料

1. [Model Context Protocol 官方规范](https://modelcontextprotocol.io/)
2. [Godot EditorPlugin 文档](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html)
3. [Godot JSONRPC 类文档](https://docs.godotengine.org/en/4.4/classes/class_jsonrpc.html)
4. [FastMCP 框架文档](https://gofastmcp.com/)
5. [Godot 4.x 开发指南](https://docs.godotengine.org/en/stable/getting_started/introduction.html)
6. [MCP Builder 指南](https://github.com/modelcontextprotocol/)

### 14.2 相关 Issue 和 PR

- GitHub Issue #64: Remote Code Execution via Unsanitized projectPath
- 当前项目分析文档: `docs/current/Godot 集成 MCP 服务器.md`
- 迁移计划检验和优化报告: `docs/migration/迁移计划检验和优化报告.md`

---

## 15. 总结

本迁移计划旨在将 Godot-MCP 项目从当前的 Node.js/FastMCP 三层架构完全迁移到 Godot 原生实现。通过消除外部依赖、减少通信延迟、增强安全性，原生实现将显著提升用户体验和开发效率。

**关键收益**:
- ✅ 零外部依赖（仅需 Godot 引擎）
- ✅ 响应延迟降低 30%+
- ✅ 内存占用降低 90%+（150MB → <5MB）
- ✅ 安全性显著提升（直接 API 调用，无命令注入风险）
- ✅ 代码统一（仅 GDScript，易于维护）
- ✅ 完整的评估体系（根据 mcp-builder）

**成功标准**:
- [ ] 所有 42+ 个工具完成迁移并测试通过
- [ ] 性能达到或超过当前实现（延迟降低 30%+）
- [ ] 通过完整的安全审计
- [ ] 用户文档完整且准确
- [ ] 至少 3 个不同项目完成实测验证
- [ ] 评估通过率 90%+

---

**文档版本历史**:
- v1.0 (2026-04-30): 初始版本，基于项目分析创建完整迁移计划
- v2.0 (2026-04-30): 根据 godot-dev-guide 和 mcp-builder 技能优化，添加类型提示、annotations、outputSchema、评估计划等
