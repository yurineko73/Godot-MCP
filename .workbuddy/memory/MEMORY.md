# Godot-MCP 项目长期记忆

## 项目概述

**项目名称**: Godot-MCP (Model Context Protocol integration for Godot Engine)

**项目路径**: `F:\gitProjects\Godot-MCP`

**项目目标**: 将 AI 助手（如 Claude）与 Godot 游戏引擎集成，使 AI 能够读取和修改 Godot 项目。

## 当前架构（2026-04-30）

### 三层架构
```
AI Client (Claude等) ←stdio (JSON-RPC 2.0)→ Node.js MCP Server (FastMCP) ←WebSocket→ Godot Addon
```

### 关键文件位置

**Node.js MCP Server**:
- 主入口: `server/src/index.ts`
- 工具定义: `server/src/tools/*.ts` (42+ 个工具)
- 资源定义: `server/src/resources/*.ts`
- 连接管理: `server/src/utils/godot_connection.ts`
- 依赖: fastmcp, ws, zod

**Godot Addon**:
- 主插件类: `addons/godot_mcp/mcp_server.gd`
- WebSocket 服务器: `addons/godot_mcp/websocket_server.gd`
- 命令处理器: `addons/godot_mcp/command_handler.gd`
- 命令实现: `addons/godot_mcp/commands/*.gd`

## 迁移计划（原生实现）

**目标架构**: 单层架构（Godot 原生实现 MCP 服务器）

**关键设计**:
1. 使用 `OS.read_string_from_stdin()` 实现 stdio 传输
2. 使用 Godot 内置 `JSONRPC` 类处理协议
3. 使用 `Thread` 实现非阻塞监听
4. 直接调用 Godot Editor API

**工具清单**（需迁移的 42+ 个工具）:
- Node Tools (6): create_node, delete_node, update_node_property, get_node_properties, list_nodes, get_scene_tree
- Script Tools (5): list_project_scripts, read_script, create_script, modify_script, analyze_script
- Scene Tools (6): create_scene, save_scene, open_scene, get_current_scene, get_scene_structure, list_project_scenes
- Editor Tools (5): get_editor_state, run_project, stop_project, get_selected_nodes, set_editor_setting
- Debug Tools (4+): get_editor_logs, execute_script, get_performance_metrics, debug_print
- Project Tools (3): get_project_info, get_project_settings, list_project_resources

**文档位置**:
- 详细计划: `docs/migration/Godot原生MCP迁移计划.md`
- 执行摘要: `docs/migration/执行摘要.md`
- 架构分析: `docs/current/Godot 集成 MCP 服务器.md`

## 重要技术细节

### Godot EditorPlugin 开发要点
- 使用 `@tool` 注解使脚本在编辑器环境下运行
- 通过 `Engine.get_meta("GodotMCPPlugin")` 获取插件实例
- 使用 `EditorInterface` singleton 访问编辑器功能
- 使用 `PackedScene` 和 `ResourceSaver` 操作场景文件

### JSON-RPC 2.0 协议要点
- 所有消息必须包含 `jsonrpc: "2.0"`
- 请求需要 `id` 字段，响应必须包含对应的 `id`
- 错误响应格式: `{"jsonrpc": "2.0", "error": {...}, "id": ...}`
- MCP 特有方法: `initialize`, `tools/list`, `tools/call`, `resources/list`, `resources/read`

### 安全注意事项
- 所有文件路径必须使用白名单验证（仅允许 `res://` 和 `user://`）
- 需要使用 `ClassDB.class_exists()` 验证节点类型
- 高风险操作（删除节点等）应实现用户确认机制

## 项目约定

### GDScript 代码风格
- 使用 snake_case 命名变量、方法
- 使用 PascalCase 命名类
- 使用类型提示: `var player: Player`
- 优先使用信号进行节点间通信

### 文件命名约定
- 原生实现文件后缀: `*_native.gd`
- 工具文件: `tools/*_tools_native.gd`
- 核心实现: `native_mcp/*.gd`

## 常见问题和解决方案

### 问题: `OS.read_string_from_stdin()` 在非 headless 模式下可能不工作
**解决方案**: 使用 `Thread` 在独立线程中调用该函数

### 问题: Godot 插件无法访问 `EditorInterface`
**解决方案**: 确保插件类继承自 `EditorPlugin`，并通过 `get_editor_interface()` 方法访问

### 问题: 场景修改后编辑器不更新
**解决方案**: 调用 `editor_interface.mark_scene_as_unsaved()` 并正确设置节点的 `owner` 属性

---

**最后更新**: 2026-04-30  
**更新原因**: 创建完整的 Godot 原生 MCP 迁移计划
