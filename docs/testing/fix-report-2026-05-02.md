# Godot-MCP 代码修复报告

修复日期: 2026-05-02

本文档记录了 Godot-MCP 原生插件代码的多轮修复，涵盖 API 解析错误、原生 API 过时、安全漏洞、代码重复、缩进语法错误、HTTP 传输兼容性和 MCP 协议版本协商等问题。

---

## 第一轮修复：代码解析错误与原生 API 过时

### 1. [严重] mcp_http_server.gd - `get_utf8_string_from_byte` API 不存在

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: `StreamPeerTCP` 上不存在 `get_utf8_string_from_byte()` 方法。Godot 4.x 的正确 API 是 `get_utf8_string(bytes: int)`。

**修复前**:
```gdscript
var chunk: String = peer.get_utf8_string_from_byte(peer.get_available_bytes())
```

**修复后**:
```gdscript
var chunk: String = peer.get_utf8_string(available)
```

---

### 2. [严重] mcp_http_server.gd - 子类信号重定义遮蔽父类信号

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: `McpHttpServer` 重新定义了 `message_received(message: Dictionary, peer: StreamPeerTCP)` 等信号，遮蔽了父类 `McpTransportBase` 的 `message_received(message: Dictionary, context: Variant)` 信号。导致核心层 `_transport.message_received.connect(...)` 连接的是子类信号而非父类信号，信号无法正确传递。

**修复**: 移除子类中所有信号重定义，继承父类信号。`_emit_message_received` 改为 `message_received.emit(message, peer as Variant)`。

---

### 3. [严重] mcp_http_server.gd - HTTP body 解析只读一行

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: `_parse_http_request` 中 body 解析只取 headers 后的第一行，多行 JSON body 丢失。

**修复前**:
```gdscript
body = lines[body_start]
```

**修复后**:
```gdscript
var body_parts: PackedStringArray = []
for i in range(body_start, lines.size()):
    body_parts.append(lines[i])
body = "\r\n".join(body_parts)
```

---

### 4. [严重] mcp_http_server.gd - `take_connection()` 前缺少 `is_connection_available()` 检查

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: 直接调用 `TCPServer.take_connection()` 而未先检查是否有可用连接，可能返回无效 peer。

**修复前**:
```gdscript
var peer: StreamPeerTCP = _tcp_server.take_connection()
```

**修复后**:
```gdscript
var peer: StreamPeerTCP = null
if _tcp_server.is_connection_available():
    peer = _tcp_server.take_connection()
```

---

### 5. [严重] mcp_http_server.gd - HTTP 请求读取不基于 Content-Length

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: `_handle_http_request` 使用简单的 while 循环读取数据，遇到 `\r\n\r\n` 就停止，无法保证 body 完整读取。

**修复**: 重构为基于 `Content-Length` 的可靠读取流程：
1. 先等待 headers 完成（检测 `\r\n\r\n`）
2. 从 headers 解析 `Content-Length`
3. 等待 body 按指定长度完整到达
4. 包含 `OS.delay_msec(1)` 避免忙等待

---

### 6. [严重] mcp_server_core.gd - 重复的 stdio 处理代码

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**问题**: 核心层包含 `_stdin_listen_loop()`、`_parse_and_queue_message()`、`_process_next_message()`、`_process_message()` 等方法，与 `McpStdioServer` 传输层功能完全重复。

**修复**: 移除核心层中所有重复的 stdio 方法和 `_process_message()` 方法，传输层已独立处理这些职责。

---

### 7. [严重] mcp_server_core.gd - `_send_response` 每次响应都写文件 I/O

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**问题**: `_send_response` 每次调用都打开并写入 `user://mcp_last_response.json` 和 `user://mcp_all_responses.log`，存在性能问题和线程安全隐患。

**修复**: 移除所有文件 I/O 代码，仅保留实际的响应发送逻辑（`print()` 用于 stdio，`send_response()` 用于 HTTP）。

---

### 8. [严重] mcp_stdio_server.gd - `_emit_error` 发射错误信号

**文件**: `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`

**问题**: `_emit_error` 方法将错误响应作为 `message_received` 信号发射，导致核心层将错误响应当作有效消息处理。

**修复前**:
```gdscript
func _emit_error(id: Variant, code: int, message: String, data: Variant = null) -> void:
    var error_response: Dictionary = MCPTypes.create_error_response(id, code, message, data)
    message_received.emit(error_response, null)
```

**修复后**:
```gdscript
func _emit_error(id: Variant, code: int, message: String, data: Variant = null) -> void:
    server_error.emit("JSON parse error: " + message)
```

---

### 9. [中等] mcp_server_native.gd - `_notification(PREDELETE)` 调用 `_exit_tree()`

**文件**: `addons/godot_mcp/mcp_server_native.gd`

**问题**: `NOTIFICATION_PREDELETE` 在对象即将销毁时发送，此时调用 `_exit_tree()` 可能导致双重清理和访问已释放对象。

**修复前**:
```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _exit_tree()
```

**修复后**:
```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        if _native_server and _native_server.is_running():
            _native_server.stop()
        _native_server = null
```

---

### 10. [中等] mcp_auth_manager.gd - 时序安全比较的长度泄露

**文件**: `addons/godot_mcp/native_mcp/mcp_auth_manager.gd`

**问题**: `validate_request` 在 token 长度不同时立即返回 `false`，攻击者可通过测量响应时间推断正确 token 的长度。

**修复前**:
```gdscript
if token.length() != _token.length():
    return false
for i in range(token.length()):
    if token[i] != _token[i]:
        return false
return true
```

**修复后**:
```gdscript
var result: bool = true
var max_len: int = maxi(token.length(), _token.length())
for i in range(max_len):
    var token_char: String = token[i] if i < token.length() else ""
    var stored_char: String = _token[i] if i < _token.length() else ""
    if token_char != stored_char:
        result = false
if token.length() != _token.length():
    result = false
return result
```

---

### 11. [低] mcp_types.gd / mcp_resource_manager.gd / mcp_server_core.gd - `@tool` 注解误用

**文件**: 
- `addons/godot_mcp/native_mcp/mcp_types.gd`
- `addons/godot_mcp/native_mcp/mcp_resource_manager.gd`
- `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**问题**: `@tool` 注解仅对 `Node` 派生类有意义，这些类均继承自 `RefCounted`，`@tool` 无效且误导。

**修复**: 移除所有 `@tool` 注解。

---

### 12. [低] mcp_server_core.gd - 空的 `_init()` 方法

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**问题**: `_init()` 方法仅包含 `pass`，无实际作用。

**修复**: 移除该方法。

---

## 第二轮修复：LSP 解析错误

### 13. [严重] mcp_http_server.gd - `set_auth_manager` 方法签名不匹配父类

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**LSP 报错**: `The function signature doesn't match the parent. Parent signature is "set_auth_manager(RefCounted) -> void".`

**问题**: `McpHttpServer` 重写 `set_auth_manager` 时参数类型为 `McpAuthManager`，与父类 `McpTransportBase` 的 `RefCounted` 不匹配。GDScript 不允许子类方法使用更具体的参数类型重写父类方法。

**修复前**:
```gdscript
func set_auth_manager(manager: McpAuthManager) -> void:
    _auth_manager = manager
```

**修复后**:
```gdscript
func set_auth_manager(manager: RefCounted) -> void:
    _auth_manager = manager as McpAuthManager
```

---

### 14. [严重] mcp_server_core.gd - `set_auth_manager` 无法解析外部类成员

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**LSP 报错**: `Could not resolve external class member "set_auth_manager".`

**问题**: 使用 `(_transport as McpHttpServer).set_auth_manager(_auth_manager)` 进行不安全的类型转换调用，LSP 无法解析。由于父类 `McpTransportBase` 已定义 `set_auth_manager(RefCounted)`，应直接通过基类引用调用。

**修复前**:
```gdscript
(_transport as McpHttpServer).set_auth_manager(_auth_manager)
```

**修复后**:
```gdscript
_transport.set_auth_manager(_auth_manager)
```

---

### 15. [严重] performance_test.gd - 缩进解析错误

**文件**: `test/benchmark/performance_test.gd`

**LSP 报错**: `Expected statement, found "Indent" instead.` (第 102 行)

**问题**: 两处 `var req_body` 声明比同级的 `var req_headers` 多了一级缩进，导致 GDScript 解析器报错。

**修复前** (第 97-108 行和第 165-176 行):
```gdscript
        var req_headers: PackedStringArray = [...]
        
            var req_body: String = JSON.stringify({...})
```

**修复后**:
```gdscript
        var req_headers: PackedStringArray = [...]
        
        var req_body: String = JSON.stringify({...})
```

---

### 16. [严重] mcp_server_core.gd - `set_http_port` 方法不存在

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**LSP 报错**: `Invalid call. Nonexistent function 'set_http_port' in base 'RefCounted (MCPServerCore)'.`

**问题**: `mcp_server_native.gd` 第 132 行调用 `_native_server.set_http_port(http_port)`，但 `MCPServerCore` 未定义该方法。HTTP 端口需要在传输层初始化时传递给 `McpHttpServer`。

**修复**: 在 `MCPServerCore` 中添加 `set_http_port` 方法和 `_http_port` 状态变量：
1. 添加 `var _http_port: int = 9080` 存储端口配置
2. 添加 `set_http_port(port)` 方法，若传输层已初始化则直接设置，否则存储到 `_http_port`
3. 在 `_init_transport()` 中 HTTP 传输层创建后调用 `_transport.set_port(_http_port)`

---

### 17. [严重] performance_test.gd - `String * int` 操作符不支持

**文件**: `test/benchmark/performance_test.gd`

**LSP 报错**: `Invalid operands to operator *, String and int.`

**问题**: GDScript 4.x 不支持 `String * int` 操作符进行字符串重复。这是 Godot 3.x 的语法，在 4.x 中已移除。

**修复前**:
```gdscript
printerr("="*60)
```

**修复后**:
```gdscript
printerr("=".repeat(60))
```

---

### 18. [严重] performance_test.gd - `EditorScript` 中调用 Node 方法

**文件**: `test/benchmark/performance_test.gd`

**LSP 报错**: `Function "add_child()" not found in base self.`, `Function "get_tree()" not found in base self.`, `Function "get_children()" not found in base self.`

**问题**: `EditorScript` 继承自 `RefCounted`，不是 `Node`，因此没有 `add_child()`、`get_tree()`、`get_children()` 等 Node 方法。脚本中多处直接调用这些方法导致解析错误。

**修复**: 通过 `get_editor_interface().get_base_control()` 获取编辑器基础控件节点，将所有 Node 方法调用委托给该节点：
1. 添加 `var _base: Control = null` 成员变量
2. 在 `_run()` 开头初始化 `_base = get_editor_interface().get_base_control()`
3. `add_child(req)` → `_base.add_child(req)`
4. `get_tree().process_frame` → `_base.get_tree().process_frame`
5. `get_children()` → `_base.get_children()`

---

## 第三轮修复：HTTP 传输兼容性与 MCP 协议版本

### 19. [严重] mcp_http_server.gd - Content-Type 检查过于严格

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: 任何不带 `Content-Type: application/json` 头的 POST 请求都被拒绝（HTTP 415），导致部分 MCP 客户端无法连接。某些客户端初始请求可能不带 Content-Type 头。

**修复**: 只在 body 非空且 Content-Type 明确不是 JSON 时才拒绝。如果客户端没发 Content-Type 但 body 是有效 JSON，允许通过。

**修复前**:
```gdscript
if not content_type.contains("application/json"):
    _send_http_error(peer, 415, "Unsupported media type...")
```

**修复后**:
```gdscript
if not body.is_empty() and not content_type.contains("application/json"):
    _send_http_error(peer, 415, "Unsupported media type...")
```

---

### 20. [严重] mcp_http_server.gd / mcp_auth_manager.gd - HTTP Header 大小写不敏感

**文件**: 
- `addons/godot_mcp/native_mcp/mcp_http_server.gd`
- `addons/godot_mcp/native_mcp/mcp_auth_manager.gd`

**问题**: HTTP 规范要求 header 名称大小写不敏感，但代码直接使用原始大小写（`Content-Type`、`Authorization`）存储和查找 header。不同客户端可能发送 `content-type`、`Content-type` 等变体，导致查找失败。

**修复**: 
1. `_parse_http_request` 中所有 header 名称统一转为小写存储
2. 所有 header 引用处同步更新为小写键名
3. `AUTH_HEADER` 常量从 `"Authorization"` 改为 `"authorization"`

---

### 21. [严重] mcp_http_server.gd - Header 值分割 bug

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: `lines[i].split(": ")` 会错误分割包含 `: ` 的 header 值（如 `Authorization: Bearer abc:123`），导致 token 丢失。

**修复前**:
```gdscript
var parts: PackedStringArray = lines[i].split(": ")
if parts.size() >= 2:
    headers[parts[0]] = parts[1]
```

**修复后**:
```gdscript
var colon_pos: int = lines[i].find(":")
if colon_pos > 0:
    var header_name: String = lines[i].left(colon_pos).to_lower()
    var header_value: String = lines[i].substr(colon_pos + 1).strip_edges()
    headers[header_name] = header_value
```

---

### 22. [严重] mcp_server_core.gd - `set_sse_enabled` / `set_remote_config` 方法不存在

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**问题**: `mcp_server_native.gd` 调用 `_native_server.set_sse_enabled(sse_enabled)` 和 `_native_server.set_remote_config(allow_remote, cors_origin)`，但 `MCPServerCore` 未定义这两个方法，导致 SSE 和远程访问配置不会生效。

**修复**: 在 `MCPServerCore` 中添加两个方法，转发到 HTTP 传输层：
```gdscript
func set_sse_enabled(enabled: bool) -> void:
    if _transport and _transport.has_method("set_sse_enabled"):
        _transport.set_sse_enabled(enabled)

func set_remote_config(allow_remote: bool, cors_origin: String) -> void:
    if _transport and _transport.has_method("set_remote_config"):
        _transport.set_remote_config(allow_remote, cors_origin)
```

---

### 23. [中等] mcp_server_native.gd - `_get_property_list` 未暴露 HTTP 属性

**文件**: `addons/godot_mcp/mcp_server_native.gd`

**问题**: 7 个 HTTP 相关属性（`transport_mode`、`http_port`、`auth_enabled`、`auth_token`、`sse_enabled`、`allow_remote`、`cors_origin`）虽然标记为 `@export`，但未在 `_get_property_list()` 中列出，导致 Inspector 中缺少合适的 hint（如 ENUM、RANGE、PASSWORD）。

**修复**: 在 `_get_property_list()` 中新增 "MCP Transport Settings" 分类，包含 7 个 HTTP 属性：
- `transport_mode`: TYPE_STRING + PROPERTY_HINT_ENUM "stdio,http"
- `http_port`: TYPE_INT + PROPERTY_HINT_RANGE "1024,65535,1"
- `auth_token`: TYPE_STRING + PROPERTY_HINT_PASSWORD

---

### 24. [严重] mcp_http_server.gd - 通知无 HTTP 响应

**文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**问题**: `notifications/initialized` 等通知（无 `id` 字段）处理后，HTTP 服务器不返回任何响应，导致客户端连接挂起。根据 MCP Streamable HTTP 规范，通知应返回 HTTP 202 Accepted。

**修复**: 
1. 检测通知消息（无 `id` 字段），返回 HTTP 202 Accepted
2. 新增 `_send_http_accepted()` 方法
3. 通知处理后关闭连接

---

### 25. [严重] mcp_server_core.gd / mcp_types.gd - MCP 协议版本不匹配

**文件**: 
- `addons/godot_mcp/native_mcp/mcp_types.gd`
- `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**问题**: 服务器硬编码返回 `protocolVersion: "2024-11-05"`，但客户端（如 Trae CN）请求 `"2025-11-25"`。根据 MCP 规范，如果服务器支持客户端请求的版本，必须响应相同版本；否则客户端可能断开连接。

**修复**: 
1. `PROTOCOL_VERSION` 从 `"2024-11-05"` 更新为 `"2025-11-25"`
2. 新增 `_negotiate_protocol_version()` 方法，支持版本协商（2025-11-25、2025-06-18、2025-03-26、2024-11-05）
3. 如果客户端请求的版本在支持列表中，返回相同版本；否则返回服务器最新版本

---

### 26. [严重] mcp_server_core.gd - HTTP 模式 `send_response` 类型转换

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**问题**: `_send_response` 中使用 `(_transport as McpHttpServer).send_response(response, context)` 进行不安全的类型转换，且 `McpHttpServer.send_response` 的参数类型 `StreamPeerTCP` 与父类 `McpTransportBase` 的 `Variant` 不一致。

**修复**: 
1. `McpHttpServer.send_response` 参数改为 `context: Variant`，内部转型
2. 核心层直接调用 `_transport.send_response(response, context)`

---

## 第四轮修复：UI 面板与工具并发安全

### 27. [严重] mcp_panel_native.gd - 对不支持 `disabled` 的控件设置属性

**文件**: `addons/godot_mcp/ui/mcp_panel_native.gd`

**问题**: 遍历 `_http_config_container` 子节点时，对所有 `Control` 子类设置 `disabled` 属性，但 `HBoxContainer` 没有 `disabled` 属性，导致运行时报错。

**修复**: 新增 `_set_controls_disabled()` 递归方法，只对支持 `disabled`/`editable` 的控件类型设置属性：
- `SpinBox` / `LineEdit` → 设置 `editable`
- `CheckBox` / `OptionButton` / `Button` → 设置 `disabled`

---

### 28. [严重] mcp_panel_native.gd - 缺少 HTTP 模式 UI 控件

**文件**: `addons/godot_mcp/ui/mcp_panel_native.gd`

**问题**: UI 面板完全缺失 HTTP 模式配置控件，用户只能通过 Inspector 编辑 `@export` 属性来配置 HTTP 模式。

**修复**: 新增完整的 HTTP 模式 UI 控件：
1. 传输模式 OptionButton（stdio/http）
2. HTTP 端口 SpinBox（1024-65535）
3. 认证 CheckBox + Token LineEdit（密码遮罩）
4. SSE CheckBox
5. 远程访问 CheckBox
6. CORS LineEdit
7. 速率限制 SpinBox
8. 连接信息 Label（显示 HTTP URL）
9. 8 个回调方法绑定插件属性
10. `_update_ui_state()` 完整读取所有 HTTP 属性，运行时禁用配置修改

---

### 29. [严重] debug_tools_native.gd - `_log_buffer` 竞态条件

**文件**: `addons/godot_mcp/tools/debug_tools_native.gd`

**问题**: `_log_buffer` 数组在信号回调 `_on_log_message` 中写入，在 `_tool_get_editor_logs` 中读取，无任何锁保护。HTTP 模式下并发请求可能导致数组损坏。

**修复**: 
1. 添加 `_log_mutex: Mutex` 保护 `_log_buffer` 的读写操作
2. 添加 `_execution_mutex: Mutex` 串行化 `execute_script` 执行
3. 使用 lock-read-unlock-then-return 模式确保 Mutex 总是释放

---

### 30. [中等] scene_tools_native.gd / editor_tools_native.gd - 并发操作保护

**文件**: 
- `addons/godot_mcp/tools/scene_tools_native.gd`
- `addons/godot_mcp/tools/editor_tools_native.gd`

**问题**: `open_scene` 会关闭当前场景，如果同时有其他工具在操作节点，会导致节点引用失效。`run_project`/`stop_project` 改变编辑器全局状态，与所有其他操作不兼容。

**修复**: 
1. `scene_tools_native.gd`: 添加 `_scene_operation_in_progress` 操作锁，`open_scene` 和 `save_scene` 执行前检查，所有 return 路径前释放锁
2. `editor_tools_native.gd`: 添加 `_editor_operation_in_progress` 操作锁，`run_project` 和 `stop_project` 执行前检查，所有 return 路径前释放锁

---

## 修复文件清单

| 文件 | 修复项编号 | 严重级别 |
|------|-----------|---------|
| `addons/godot_mcp/native_mcp/mcp_http_server.gd` | #1, #2, #3, #4, #5, #13, #19, #20, #21, #24 | 严重 |
| `addons/godot_mcp/native_mcp/mcp_server_core.gd` | #6, #7, #12, #14, #16, #22, #25, #26 | 严重 |
| `addons/godot_mcp/native_mcp/mcp_stdio_server.gd` | #8 | 严重 |
| `addons/godot_mcp/mcp_server_native.gd` | #9, #23 | 中等 |
| `addons/godot_mcp/native_mcp/mcp_auth_manager.gd` | #10, #20 | 中等 |
| `addons/godot_mcp/native_mcp/mcp_types.gd` | #11, #25 | 低 |
| `addons/godot_mcp/native_mcp/mcp_resource_manager.gd` | #11 | 低 |
| `addons/godot_mcp/ui/mcp_panel_native.gd` | #27, #28 | 严重 |
| `addons/godot_mcp/tools/debug_tools_native.gd` | #29 | 严重 |
| `addons/godot_mcp/tools/scene_tools_native.gd` | #30 | 中等 |
| `addons/godot_mcp/tools/editor_tools_native.gd` | #30 | 中等 |
| `test/benchmark/performance_test.gd` | #15, #17, #18 | 严重 |

---

## 验证方法

1. 在 Godot Editor 中重新加载项目，检查 Output 面板是否还有 LSP 解析错误
2. 启用 Godot-MCP 插件，确认插件正常加载
3. 使用 stdio 模式启动 MCP 服务器，发送 JSON-RPC 请求验证通信
4. 使用 HTTP 模式启动 MCP 服务器，发送 POST 请求验证通信
5. 运行性能测试脚本验证无语法错误
6. 使用 Trae CN 等 MCP 客户端连接 HTTP 模式，验证工具列表获取正常
7. 验证 UI 面板 HTTP 模式控件显示/隐藏正确
8. 验证运行时禁止修改传输模式和 HTTP 配置
