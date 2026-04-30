# 将 MCP Panel 改造为编辑器浮动对话框 - 重构计划

## 目标
将 `addons/godot_mcp/ui/mcp_panel.tscn` 从游戏内场景改造为编辑器中的独立浮动对话框，使其无需运行游戏即可操作，同时保持所有功能不变。

## 现状分析
- 当前面板是一个普通的 `Control` 场景，需要在游戏运行时才能显示和操作。
- 面板依赖 `MCPWebSocketServer` 实例（实际为 `mcp_server.gd` 中的 `EditorPlugin` 自身）提供服务器功能。
- 面板通过 `_ready()` 异步等待并连接服务器信号，但注入时机不确定，容易出错。

## 改造方案

### 修改 `mcp_panel.gd`
1. 移除 `_ready()` 中对 `websocket_server` 的异步依赖。
2. 添加 `set_server(server)` 方法，由外部注入服务器实例，并在该方法中连接所有信号。
3. 添加空引用保护，当 `websocket_server` 为 `null` 时显示未初始化状态。

### 修改 `mcp_server.gd`
1. 在 `_enter_tree()` 中创建浮动窗口（`Window`）并加载面板。
2. 将 `self` 作为服务器实例注入面板。
3. 添加菜单项 "Show MCP Panel" 用于重新打开关闭的窗口。
4. 在 `_exit_tree()` 中清理窗口和菜单项。

## 实施文件
- `addons/godot_mcp/ui/mcp_panel.gd`
- `addons/godot_mcp/mcp_server.gd`

## 预期结果
- 插件启用后自动显示浮动对话框。
- 可通过菜单栏 `View -> Show MCP Panel` 重新打开已关闭的窗口。
- 所有功能（启动/停止服务器、修改端口、日志显示、客户端计数）正常工作。

## 验证步骤
1. 在 Godot 编辑器中启用插件。
2. 检查是否出现 "Godot MCP Server Control" 浮动窗口。
3. 关闭窗口，通过菜单重新打开。
4. 启动服务器，检查端口监听和日志输出。
5. 通过 WebSocket 客户端连接，确认连接计数更新和命令处理。