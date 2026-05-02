# Godot Native MCP 架构文档

## 简介

本文档详细描述了 Godot Native MCP 的架构设计、模块划分和数据流。

---

## 1. 架构概述

### 1.1 架构演进

#### 旧架构（Node.js 中介）

```
AI Client (Claude等)
    ↓ stdio (JSON-RPC 2.0)
Node.js MCP Server (FastMCP)
    ↓ WebSocket
Godot Addon (WebSocket Server)
    ↓ Godot Editor API
Godot Engine
```

**问题**：
- 三层架构，通信延迟高
- 需要 Node.js 环境
- 内存占用大（150MB+）
- 存在安全风险（命令注入）

#### 新架构（原生实现）

```
AI Client (Claude等)
    ↓ stdio (JSON-RPC 2.0)
Godot Engine (MCP Server 原生实现)
    ↓ Godot Editor API
Godot Editor
```

**优势**：
- 单层架构，零中介
- 无需 Node.js 环境
- 内存占用小（<5MB）
- 直接 API 调用，更安全

---

## 2. 系统架构图

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                AI Client (Claude etc.)                │
│                        ↓ stdio                        │
│   JSON-RPC 2.0 协议 (initialize, tools/list, etc.) │
└─────────────────────────────────────────────────────────┘
                        ↓ stdio
┌─────────────────────────────────────────────────────────┐
│              Godot Engine (Editor)                     │
│                                                       │
│  ┌─────────────────────────────────────────────┐    │
│  │  MCP Server Native (mcp_server_native.gd)  │    │
│  │  - 插件主类 (EditorPlugin)                  │    │
│  │  - 生命周期管理                              │    │
│  │  - UI 面板管理                              │    │
│  └─────────────────────────────────────────────┘    │
│                       ↓ 调用                           │
│  ┌─────────────────────────────────────────────┐    │
│  │  MCP Server Core (mcp_server_core.gd)      │    │
│  │  - stdio 传输层 (OS.read_string_from_stdin)│    │
│  │  - JSON-RPC 2.0 协议处理                  │    │
│  │  - 工具注册表                              │    │
│  │  - 资源管理器                              │    │
│  └─────────────────────────────────────────────┘    │
│                       ↓ 调用                           │
│  ┌─────────────────────────────────────────────┐    │
│  │  Tools (tools/*.gd)                       │    │
│  │  - NodeToolsNative                        │    │
│  │  - ScriptToolsNative                      │    │
│  │  - SceneToolsNative                       │    │
│  │  - EditorToolsNative                      │    │
│  │  - DebugToolsNative                       │    │
│  │  - ProjectToolsNative                     │    │
│  └─────────────────────────────────────────────┘    │
│                       ↓ 调用                           │
│  ┌─────────────────────────────────────────────┐    │
│  │  Godot Editor API                         │    │
│  │  - EditorInterface                        │    │
│  │  - EditorInterface.get_edited_scene_root()│    │
│  │  - EditorInterface.get_selection()        │    │
│  │  - get_editor_interface()                │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 2.2 模块依赖关系

```
mcp_server_native.gd (主插件类)
    ↓ 创建/管理
mcp_server_core.gd (服务器核心)
    ↓ 调用
tools/*.gd (工具实现)
    ↓ 调用
Godot Editor API

ui/mcp_panel_native.gd (UI面板)
    ↑ 反向控制
mcp_server_native.gd
```

---

## 3. 关键模块说明

### 3.1 主插件类 (`mcp_server_native.gd`)

**职责**：
- 插件生命周期管理（`_enter_tree()`, `_exit_tree()`）
- 创建和管理 MCP Server Core 实例
- 注册所有工具和资源
- 创建和管理 UI 面板
- 提供配置选项（auto_start、log_level、security_level）

**关键方法**：
| 方法名 | 说明 |
|--------|------|
| `_enter_tree()` | 插件启用时调用，初始化所有组件 |
| `_exit_tree()` | 插件禁用时调用，清理资源 |
| `_create_ui_panel()` | 创建 UI 面板并添加到编辑器 |
| `_register_all_tools()` | 注册所有 MCP 工具 |
| `_register_all_resources()` | 注册所有 MCP 资源 |
| `start_server()` | 启动 MCP 服务器 |
| `stop_server()` | 停止 MCP 服务器 |

**配置变量**：
| 变量名 | 类型 | 说明 |
|--------|------|------|
| `auto_start` | `bool` | 是否自动启动服务器 |
| `log_level` | `int` | 日志级别（0=ERROR, 1=WARN, 2=INFO, 3=DEBUG） |
| `security_level` | `int` | 安全级别（0=PERMISSIVE, 1=STRICT） |
| `rate_limit` | `int` | 速率限制（每秒请求数） |

---

### 3.2 服务器核心 (`native_mcp/mcp_server_core.gd`)

**职责**：
- 实现 stdio 传输层（`OS.read_string_from_stdin()`）
- 处理 JSON-RPC 2.0 协议
- 管理工具注册表
- 管理资源注册表
- 调用工具执行
- 读取资源内容

**关键方法**：
| 方法名 | 说明 |
|--------|------|
| `start()` | 启动服务器（启动 stdin 监听线程） |
| `stop()` | 停止服务器 |
| `is_running()` | 检查服务器是否运行中 |
| `register_tool()` | 注册 MCP 工具 |
| `register_resource()` | 注册 MCP 资源 |
| `get_registered_tools()` | 获取已注册的工具列表 |
| `set_tool_enabled()` | 启用/禁用工具 |
| `set_log_level()` | 设置日志级别 |
| `set_security_level()` | 设置安全级别 |

**信号**：
| 信号名 | 说明 |
|--------|------|
| `server_started` | 服务器启动成功 |
| `server_stopped` | 服务器停止 |
| `message_received` | 接收到消息 |
| `response_sent` | 响应已发送 |
| `tool_execution_started` | 工具开始执行 |
| `tool_execution_completed` | 工具执行完成 |
| `tool_execution_failed` | 工具执行失败 |
| `log_message` | 日志消息 |

---

### 3.3 工具实现 (`tools/*.gd`)

**职责**：
- 实现具体的 MCP 工具逻辑
- 调用 Godot Editor API 完成操作
- 返回结构化结果

**工具分类**：
| 分类 | 文件 | 工具数量 |
|------|------|---------|
| Node Tools | `tools/node_tools_native.gd` | 6 |
| Script Tools | `tools/script_tools_native.gd` | 5 |
| Scene Tools | `tools/scene_tools_native.gd` | 6 |
| Editor Tools | `tools/editor_tools_native.gd` | 5 |
| Debug Tools | `tools/debug_tools_native.gd` | 4 |
| Project Tools | `tools/project_tools_native.gd` | 4 |
| **总计** | | **30** |

**工具注册示例**（`tools/node_tools_native.gd`）：
```gdscript
static func register_tools(server_core: RefCounted) -> void:
	server_core.register_tool(
		"create_node",
		"Create a new node in the Godot scene tree",
		{
			"type": "object",
			"properties": {
				"parent_path": {"type": "string"},
				"node_type": {"type": "string"},
				"node_name": {"type": "string"}
			},
			"required": ["parent_path", "node_type", "node_name"]
		},
		Callable(self, "_tool_create_node")
	)
```

---

### 3.4 资源管理 (`native_mcp/mcp_resource_manager.gd`)

**职责**：
- 注册和管理 MCP 资源
- 读取资源内容
- 返回标准化资源响应

**资源列表**：
| 资源 URI | 说明 |
|-----------|------|
| `godot://scene/list` | 所有场景列表 |
| `godot://scene/current` | 当前场景信息 |
| `godot://script/list` | 所有脚本列表 |
| `godot://script/current` | 当前脚本内容 |
| `godot://project/info` | 项目信息 |
| `godot://project/settings` | 项目设置 |
| `godot://editor/state` | 编辑器状态 |

---

### 3.5 安全工具 (`utils/path_validator.gd`)

**职责**：
- 验证文件路径是否在白名单内
- 检测和阻止路径遍历攻击
- 验证文件类型

**白名单路径**：
- `res://`（项目目录）
- `user://`（用户目录）

**危险模式**（被阻止）：
- `..`（路径遍历）
- `//`（绝对路径）
- `\`（反斜杠，仅 Windows）

**关键方法**：
| 方法名 | 说明 |
|--------|------|
| `validate_path()` | 验证路径安全性 |
| `validate_file_path()` | 验证文件路径（含扩展名检查） |
| `validate_directory_path()` | 验证目录路径 |
| `sanitize_path()` | 清理路径中的危险字符 |

---

### 3.6 UI 面板 (`ui/mcp_panel_native.gd`)

**职责**：
- 显示 MCP 服务器状态
- 提供启动/停止按钮
- 配置服务器参数
- 显示服务器日志
- 管理工具启用/禁用

**UI 组件**：
| 组件名 | 类型 | 说明 |
|--------|------|------|
| `status_label` | `Label` | 显示服务器状态 |
| `start_button` | `Button` | 启动服务器 |
| `stop_button` | `Button` | 停止服务器 |
| `auto_start_check` | `CheckBox` | 自动启动开关 |
| `log_level_option` | `OptionButton` | 日志级别选择 |
| `security_level_option` | `OptionButton` | 安全级别选择 |
| `log_text_edit` | `TextEdit` | 日志查看器 |
| `tools_list_container` | `VBoxContainer` | 工具列表容器 |

---

## 4. 数据流

### 4.1 工具调用流程

```
1. AI Client 发送请求
   ↓ stdio (JSON-RPC 2.0)
   {
     "jsonrpc": "2.0",
     "method": "tools/call",
     "params": {
       "name": "create_node",
       "arguments": {
         "parent_path": "/root/Main",
         "node_type": "CharacterBody2D",
         "node_name": "Player"
       }
     },
     "id": 1
   }

2. MCP Server Core 接收请求
   ↓ 解析 JSON-RPC
   ↓ 查找工具注册表
   ↓ 验证参数

3. 调用工具函数
   ↓ tools/node_tools_native.gd::_tool_create_node()
   ↓ 调用 Godot Editor API

4. 返回结果
   ↓ stdio (JSON-RPC 2.0)
   {
     "jsonrpc": "2.0",
     "result": {
       "status": "success",
       "node_path": "/root/Main/Player",
       "node_type": "CharacterBody2D"
     },
     "id": 1
   }
```

### 4.2 资源读取流程

```
1. AI Client 发送请求
   ↓ stdio (JSON-RPC 2.0)
   {
     "jsonrpc": "2.0",
     "method": "resources/read",
     "params": {
       "uri": "godot://scene/list"
     },
     "id": 2
   }

2. MCP Server Core 接收请求
   ↓ 解析 JSON-RPC
   ↓ 查找资源注册表
   ↓ 调用资源读取函数

3. 读取资源内容
   ↓ mcp_server_native.gd::_resource_scene_list()
   ↓ 遍历项目目录，查找 .tscn 文件

4. 返回资源内容
   ↓ stdio (JSON-RPC 2.0)
   {
     "jsonrpc": "2.0",
     "result": {
       "contents": [{
         "uri": "godot://scene/list",
         "mimeType": "application/json",
         "text": "{\"scenes\":[\"res://scenes/main.tscn\"],\"count\":1}"
       }]
     },
     "id": 2
   }
```

---

## 5. 安全设计

### 5.1 路径白名单

**原理**：仅允许访问 `res://` 和 `user://` 路径。

**实现**（`utils/path_validator.gd`）：
```gdscript
static func validate_path(path: String) -> Dictionary:
	if not path.begins_with("res://") and not path.begins_with("user://"):
		return {"valid": false, "error": "Path not in whitelist"}
	
	if ".." in path:
		return {"valid": false, "error": "Path traversal detected"}
	
	return {"valid": true}
```

### 5.2 参数验证

**原理**：所有工具参数都进行严格验证。

**实现**（工具注册时定义 schema）：
```gdscript
{
  "type": "object",
  "properties": {
    "parent_path": {"type": "string"},
    "node_type": {"type": "string"}
  },
  "required": ["parent_path", "node_type"]
}
```

### 5.3 速率限制

**原理**：限制每秒请求数，防止过载。

**实现**（`mcp_server_core.gd`）：
```gdscript
var _request_count: int = 0
var _last_reset_time: int = 0

func _check_rate_limit() -> bool:
	var current_time: int = Time.get_unix_time_from_system()
	
	if current_time - _last_reset_time >= 1:
		_request_count = 0
		_last_reset_time = current_time
	
	_request_count += 1
	
	if _request_count > rate_limit:
		return false
	
	return true
```

---

## 6. 性能优化

### 6.1 异步处理

**原理**：使用 `Thread` 实现非阻塞 stdin 监听。

**实现**（`mcp_server_core.gd`）：
```gdscript
func _stdin_listen_loop() -> void:
	while _active:
		var input: String = OS.read_string_from_stdin()
		if input and not input.is_empty():
			call_deferred("_parse_and_handle_message", input)
		OS.delay_msec(10)  # 避免 CPU 占用过高
```

### 6.2 缓存机制

**原理**：缓存场景结构、脚本分析结果等。

**待实现**：
- 场景结构缓存
- 脚本分析结果缓存
- 项目资源索引

---

## 7. 扩展性设计

### 7.1 工具注册机制

**原理**：使用函数指针（`Callable`）实现动态工具注册。

**示例**：
```gdscript
# 注册工具
server_core.register_tool(
	"create_node",
	"Create a new node",
	{...},  # JSON Schema
	Callable(self, "_tool_create_node")
)

# 调用工具
var result: Dictionary = tool_callable.call(tool_params)
```

### 7.2 资源注册机制

**原理**：使用 URI 映射实现动态资源注册。

**示例**：
```gdscript
# 注册资源
server_core.register_resource(
	"godot://scene/list",
	"Godot Scene List",
	"application/json",
	Callable(self, "_resource_scene_list")
)

# 读取资源
var result: Dictionary = resource_callable.call(params)
```

---

## 8. 测试策略

### 8.1 单元测试

**目标**：测试每个工具的输入输出。

**工具**：Godot 内置测试框架。

**示例**：
```gdscript
func test_create_node() -> void:
	var result: Dictionary = NodeToolsNative._tool_create_node({
		"parent_path": "/root/Main",
		"node_type": "Node2D",
		"node_name": "TestNode"
	})
	
	assert(result["status"] == "success")
	assert(result["node_path"] == "/root/Main/TestNode")
```

### 8.2 集成测试

**目标**：测试与 Claude Desktop 的集成。

**步骤**：
1. 配置 Claude Desktop 使用原生服务器
2. 测试所有 30 个工具
3. 验证资源访问
4. 测试错误场景

### 8.3 性能测试

**目标**：对比迁移前后的性能。

**指标**：
- 响应时间
- 内存占用
- CPU 使用率

---

## 9. 部署方案

### 9.1 Godot 插件市场

**目标**：将插件发布到 Godot 插件市场。

**步骤**：
1. 完善文档
2. 创建预览图
3. 提交到插件市场

### 9.2 GitHub Release

**目标**：发布二进制版本。

**步骤**：
1. 创建 GitHub Release
2. 上传插件包
3. 更新 README.md

---

## 10. 后续优化方向

### 10.1 性能优化

- 缓存机制
- 懒加载
- 增量更新

### 10.2 功能扩展

- SSE 传输支持（远程访问）
- 高级调试功能（断点管理、变量监视）
- AI 辅助功能（代码补全增强、自动重构建议）

### 10.3 安全性增强

- 用户确认机制（危险操作）
- 访问令牌（防止未授权访问）
- 审计日志（记录所有操作）

---

**文档版本**：1.0  
**最后更新**：2026-05-01
