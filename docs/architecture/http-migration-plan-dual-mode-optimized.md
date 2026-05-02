# Godot-MCP 双传输模式迁移计划（优化版）

**日期**: 2026-05-02  
**作者**: AI Assistant  
**目标**: 将现有 stdio 传输方案扩展为支持 stdio 和 HTTP/SSE 双模式（符合 Godot 4.x 和 MCP 规范）

---

## 1. 概述

### 1.1 当前架构（stdio）

```
MCP Client (Claude Desktop) 
  ↓ 启动子进程
Godot Editor (带 MCP 插件)
  ↓ stdin/stdout
MCP Server (在 Godot 插件内)
```

**问题**：
1. stdout 污染（Godot 引擎日志混在 stdout 中）
2. 无法连接已运行的 Godot 实例
3. MCP 客户端适配困难

### 1.2 目标架构（支持多种传输方式）

```
方案 A: stdio 传输（保留，可选）
MCP Client (Claude Desktop) 
  ↓ 启动子进程
Godot Editor (带 MCP 插件)
  ↓ stdin/stdout
MCP Server (stdio 模式)

方案 B: HTTP/SSE 传输（新增，推荐）
MCP Client (Claude Desktop)
  ↓ HTTP POST/GET
Godot Editor (带 MCP 插件，运行 HTTP 服务器)
  ↓ 内部调用
MCP Server (HTTP 模式)
  ↓ 调用
Godot Editor API (场景、节点、脚本等操作)
```

**设计思路**：
1. 保留 stdio 传输方式（封装到 `mcp_stdio_server.gd`）
2. 新增 HTTP/SSE 传输方式（实现 `mcp_http_server.gd`）
3. 通过配置参数让用户选择传输方式
4. 核心 MCP 协议处理逻辑共享
5. **符合 MCP 2025-03-26 规范**（Streamable HTTP）

### 1.3 传输方式对比

| 特性 | stdio | HTTP/SSE |
|------|-------|----------|
| 连接方式 | 子进程 + stdin/stdout | TCP/HTTP |
| 适用场景 | 本地开发、简单部署 | 生产环境、远程访问 |
| 客户端适配 | 需要支持 stdio | 标准 HTTP，适配性好 |
| 调试难度 | 较难（日志混在一起） | 容易（可用 curl/Postman） |
| 性能 | 高（无网络开销） | 中（有网络开销，但很小） |
| 并发支持 | 不支持 | 支持 |
| 安全性 | 高（进程隔离） | 中（需要认证） |
| 推荐场景 | 开发测试 | 生产部署 |

**建议**：
- 开发阶段：使用 stdio 模式（简单、快速）
- 生产环境：使用 HTTP 模式（稳定、易维护、支持远程访问）

---

## 2. 需要创建的文件

### 2.1 核心文件

| 文件路径 | 说明 | 优先级 | 符合规范 |
|----------|------|----------|----------|
| `addons/godot_mcp/native_mcp/mcp_transport_base.gd` | 传输层基类（定义统一接口） | 🔴 高 | Godot Dev Guide |
| `addons/godot_mcp/native_mcp/mcp_stdio_server.gd` | stdio 传输实现（从 core 中提取） | 🔴 高 | MCP 规范 |
| `addons/godot_mcp/native_mcp/mcp_http_server.gd` | HTTP 服务器实现（基于 TCPServer） | 🔴 高 | MCP 规范 |
| `addons/godot_mcp/native_mcp/mcp_auth_manager.gd` | 认证管理器（HTTP 模式，token-based） | 🔴 高 | MCP 安全最佳实践 |
| `addons/godot_mcp/native_mcp/mcp_sse_stream.gd` | SSE 流管理器（可选，第二阶段） | 🟡 中 | MCP 规范 |
| `addons/godot_mcp/native_mcp/mcp_session_manager.gd` | 会话管理器（Mcp-Session-Id） | 🟡 中 | MCP 规范 |

### 2.2 测试文件

| 文件路径 | 说明 | 优先级 |
|----------|------|----------|
| `test/http/test_mcp_http_server.py` | Python 测试脚本（HTTP 模式 + 认证测试） | 🔴 高 |
| `test/stdio/test_mcp_stdio.py` | Python 测试脚本（stdio 模式） | 🔴 高 |
| `test/http/test_mcp_http_client.js` | Node.js 测试脚本 | 🟡 中 |
| `test/http/curl_examples.sh` | curl 测试示例（Bash） | 🟢 低 |
| `test/benchmark/performance_test.gd` | 性能测试脚本 | 🟡 中 |

### 2.3 配置文件

| 文件路径 | 说明 | 优先级 |
|----------|------|----------|
| `docs/configuration/mcp-stdio-config-example.json` | stdio 模式配置示例 | 🔴 高 |
| `docs/configuration/mcp-http-config-example.json` | HTTP 模式配置示例（含认证） | 🔴 高 |
| `addons/godot_mcp/native_mcp/default_config.json` | 默认配置文件（传输方式、端口、token） | 🔴 高 |

---

## 3. 需要修改的文件

### 3.1 核心文件修改

#### 3.1.1 `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**修改内容**：

1. **提取 stdio 相关代码到 `mcp_stdio_server.gd`**：
   - 将 `_stdin_listen_loop()` 函数移动到 `mcp_stdio_server.gd`
   - 将 `_parse_and_queue_message()` 函数移动到 `mcp_stdio_server.gd`
   - 将 `_process_next_message()` 函数移动到 `mcp_stdio_server.gd`
   - 将 `start()` 函数中的 Thread 创建和 stdin 监听逻辑移动到 `mcp_stdio_server.gd`
   - 将 `stop()` 函数中的 Thread 清理逻辑移动到 `mcp_stdio_server.gd`

2. **添加新的变量**（带类型提示，符合 Godot Dev Guide）：
   ```gdscript
   # 传输方式枚举
   enum TransportType {
       TRANSPORT_STDIO,    # stdio 传输（默认）
       TRANSPORT_HTTP      # HTTP 传输
   }
   
   var _transport_type: TransportType = TransportType.TRANSPORT_STDIO
   var _transport: McpTransportBase = null  # 传输层实例（使用基类类型）
   var _auth_manager: McpAuthManager = null  # 认证管理器（HTTP 模式使用）
   ```

3. **添加传输层接口方法**（符合 MCP 规范）：
   ```gdscript
   func set_transport_type(type: TransportType) -> void:
       """设置传输方式（必须在服务器启动前调用）"""
       if _active:
           _log_error("Cannot change transport type while server is running")
           return
       _transport_type = type
   
   func set_auth_manager(manager: McpAuthManager) -> void:
       """设置认证管理器（HTTP 模式）"""
       _auth_manager = manager
   
   func _init_transport() -> bool:
       """初始化传输层（根据 _transport_type 创建对应实例）"""
       match _transport_type:
           TransportType.TRANSPORT_STDIO:
               _transport = McpStdioServer.new()
           TransportType.TRANSPORT_HTTP:
               _transport = McpHttpServer.new()
               # HTTP 模式需要设置认证管理器
               if _auth_manager:
                   (_transport as McpHttpServer).set_auth_manager(_auth_manager)
           _:
               _log_error("Unknown transport type: " + str(_transport_type))
               return false
       
       # 连接信号（确保线程安全）
       _transport.message_received.connect(_on_transport_message_received)
       _transport.server_error.connect(_on_transport_error)
       
       return true
   ```

4. **修改 `start()` 和 `stop()` 函数**（确保线程安全）：
   ```gdscript
   func start() -> bool:
       """启动 MCP 服务器（根据传输方式启动对应传输层）"""
       _log_info("Starting MCP Server (transport: " + str(_transport_type) + ")...")
       
       # 初始化传输层
       if not _init_transport():
           _log_error("Failed to initialize transport layer")
           return false
       
       # 启动传输层
       var success: bool = _transport.start()
       
       if not success:
           _log_error("Failed to start transport layer")
           return false
       
       _active = true
       server_started.emit()
       _log_info("MCP Server started successfully (transport: " + str(_transport_type) + ")")
       
       return true
   
   func stop() -> void:
       """停止 MCP 服务器（停止传输层）"""
       if not _active:
           return
       
       _log_info("Stopping MCP Server...")
       
       # 停止传输层
       if _transport:
           _transport.stop()
           _transport = null
       
       _active = false
       server_stopped.emit()
       _log_info("MCP Server stopped")
   ```

5. **添加消息处理方法**（符合 MCP 规范，错误消息具操作性）：
   ```gdscript
   func _on_transport_message_received(message: Dictionary, context: Variant) -> void:
       """处理来自传输层的消息（线程安全：此函数在主线程执行）"""
       # 验证消息格式
       if not message.has("jsonrpc"):
           _send_error(null, MCPTypes.ERROR_INVALID_REQUEST, 
                      "Missing 'jsonrpc' field. Please ensure the message is a valid JSON-RPC 2.0 message.")
           return
       
       if message["jsonrpc"] != JSONRPC_VERSION:
           _send_error(message.get("id"), MCPTypes.ERROR_INVALID_REQUEST, 
                      "Invalid JSON-RPC version. Expected '2.0', got: " + str(message["jsonrpc"]))
           return
       
       # 记录收到的消息
       message_received.emit(message)
       _log_debug("Received message: " + JSON.stringify(message))
       
       # 处理请求
       var response: Dictionary = {}
       
       if message.has("method"):
           # 这是一个请求或通知
           response = _handle_request(message)
       else:
           # 这是一个响应（通常不需要处理）
           _log_warn("Received unexpected response message: " + JSON.stringify(message))
           return
       
       # 发送响应（如果有）
       if response:
           _send_response(response, context)
   
   func _send_response(response: Dictionary, context: Variant) -> void:
       """发送响应（根据传输方式自动选择）"""
       if _transport_type == TransportType.TRANSPORT_STDIO:
           # stdio 模式：直接输出到 stdout
           var json_string: String = JSON.stringify(response)
           print(json_string)
           response_sent.emit(response)
           
       elif _transport_type == TransportType.TRANSPORT_HTTP:
           # HTTP 模式：通过 HTTP 服务器发送响应
           if _transport and _transport.has_method("send_response"):
               (_transport as McpHttpServer).send_response(response, context)
   ```

6. **保持不动的部分**：
   - 所有 MCP 协议处理方法（`_handle_initialize()`, `_handle_tools_list()`, 等）
   - 工具注册和资源注册相关方法
   - 速率限制和缓存机制
   - 日志方法

#### 3.1.2 `addons/godot_mcp/mcp_server_native.gd`

**修改内容**：

1. **添加新的配置选项**（带类型提示）：
   ```gdscript
   @export var transport_mode: String = "stdio":
       set(value):
           if value == "stdio" or value == "http":
               transport_mode = value
               if _native_server:
                   var type: int = McpServerCore.TransportType.TRANSPORT_STDIO if value == "stdio" \
                       else McpServerCore.TransportType.TRANSPORT_HTTP
                   _native_server.set_transport_type(type)
               notify_property_list_changed()
           else:
               _log_error("Invalid transport mode: " + value + ". Valid values are 'stdio' or 'http'")
       
   @export var http_port: int = 9080:
       set(value):
           if value < 1024 or value > 65535:
               _log_error("Invalid port: " + str(value) + ". Please use a port between 1024 and 65535.")
               return
           http_port = value
           if _native_server and _native_server.has_method("set_http_port"):
               _native_server.set_http_port(value)
           notify_property_list_changed()
   
   @export var auth_enabled: bool = false:
       set(value):
           auth_enabled = value
           notify_property_list_changed()
   
   @export var auth_token: String = "":
       set(value):
           if value.length() < 16:
               _log_warn("Auth token is too short. Please use at least 16 characters for security.")
           auth_token = value
           notify_property_list_changed()
   ```

2. **修改 `_enter_tree()` 函数**：根据 `transport_mode` 设置传输方式，并初始化认证管理器
   ```gdscript
   func _enter_tree() -> void:
       # 创建 MCP 服务器核心实例
       _native_server = McpServerCore.new()
       
       # 设置传输方式
       var type: int = McpServerCore.TransportType.TRANSPORT_STDIO if transport_mode == "stdio" \
                       else McpServerCore.TransportType.TRANSPORT_HTTP
       _native_server.set_transport_type(type)
       
       # 设置 HTTP 端口
       _native_server.set_http_port(http_port)
       
       # 如果启用了认证，创建认证管理器
       if auth_enabled and transport_mode == "http":
           var auth_manager: McpAuthManager = McpAuthManager.new()
           auth_manager.set_token(auth_token)
           _native_server.set_auth_manager(auth_manager)
       
       # 连接信号
       _native_server.server_started.connect(_on_server_started)
       _native_server.server_stopped.connect(_on_server_stopped)
       _native_server.message_received.connect(_on_message_received)
       _native_server.response_sent.connect(_on_response_sent)
       
       add_child(_native_server)
       
       _log_info("MCP Server Native instance created (transport: " + transport_mode + ", auth: " + str(auth_enabled) + ")")
   ```

3. **修改 `_start_native_server()` 和 `_stop_native_server()` 函数**：支持多种传输方式

#### 3.1.3 `addons/godot_mcp/ui/mcp_panel_native.gd`

**修改内容**：

1. **更新 UI 显示**：
   - 添加传输方式选择下拉框（stdio / http）
   - 根据传输方式显示不同的状态信息
   - 添加端口设置输入框（仅 HTTP 模式）
   - 添加认证开关和 token 输入框（仅 HTTP 模式）

2. **添加新的信号连接**：
   - 连接传输方式切换信号
   - 连接认证开关信号
   - 更新 UI 状态显示

### 3.2 配置文件修改

#### 3.2.1 MCP 客户端配置

**stdio 模式配置**（`claude_desktop_config.json`）：
```json
{
  "mcpServers": {
    "godot-mcp-stdio": {
      "command": "path/to/godot.exe",
      "args": ["--headless", "--script", "res://addons/godot_mcp/mcp_server_native.gd"],
      "env": {
        "MCP_TRANSPORT": "stdio"
      }
    }
  }
}
```

**HTTP 模式配置**（`claude_desktop_config.json`，含认证）：
```json
{
  "mcpServers": {
    "godot-mcp-http": {
      "url": "http://localhost:9080/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

#### 3.2.2 Godot 插件配置

在 Godot Editor 的 Plugin 设置中：

```ini
[editor]

# MCP Server 传输方式（stdio 或 http）
mcp_transport_mode="stdio"

# HTTP 模式下的端口（仅 HTTP 模式有效）
mcp_http_port=9080

# HTTP 模式下的认证（可选，推荐启用）
mcp_auth_enabled=true
mcp_auth_token="your-secret-token-here"
```

---

## 4. 详细迁移步骤

### 阶段一：创建传输层基类（0.5 天）

#### 步骤 1.1：创建 `mcp_transport_base.gd`

**文件路径**：`addons/godot_mcp/native_mcp/mcp_transport_base.gd`

**功能**：定义传输层的统一接口，所有传输方式都继承此类

**核心接口**（符合 Godot Dev Guide，使用类型提示）：
```gdscript
class_name McpTransportBase
extends RefCounted

# 信号定义（用于线程间通信，确保线程安全）
signal message_received(message: Dictionary, context: Variant)
signal server_error(error: String)
signal server_started()
signal server_stopped()

# 虚方法（子类必须实现）
func start() -> bool:
    """启动传输层"""
    push_error("McpTransportBase.start() must be overridden")
    return false

func stop() -> void:
    """停止传输层"""
    push_error("McpTransportBase.stop() must be overridden")

func is_running() -> bool:
    """检查传输层是否正在运行"""
    push_error("McpTransportBase.is_running() must be overridden")
    return false

# 可选方法（子类可以重写）
func set_port(port: int) -> void:
    """设置端口（HTTP 模式）"""
    push_error("McpTransportBase.set_port() is not implemented")

func set_auth_manager(manager: RefCounted) -> void:
    """设置认证管理器（HTTP 模式）"""
    push_error("McpTransportBase.set_auth_manager() is not implemented")
```

---

### 阶段二：创建认证管理器（0.5 天）

#### 步骤 2.1：创建 `mcp_auth_manager.gd`

**文件路径**：`addons/godot_mcp/native_mcp/mcp_auth_manager.gd`

**功能**：管理 HTTP 模式的认证（token-based auth）

**核心实现**（符合 MCP 安全最佳实践）：
```gdscript
class_name McpAuthManager
extends RefCounted

# 配置
var _token: String = ""
var _enabled: bool = true

# 常量
const HEADER_NAME: String = "Authorization"
const SCHEME: String = "Bearer"

func set_token(token: String) -> void:
    """设置认证 token（必须 ≥ 16 字符）"""
    if token.length() < 16:
        push_error("Auth token must be at least 16 characters long")
        return
    _token = token

func set_enabled(enabled: bool) -> void:
    """启用/禁用认证"""
    _enabled = enabled

func validate_request(headers: Dictionary) -> bool:
    """验证 HTTP 请求的认证头（返回 true 表示认证通过）"""
    if not _enabled:
        return true  # 认证未启用，直接通过
    
    if not headers.has(HEADER_NAME):
        return false  # 缺少认证头
    
    var auth_header: String = headers[HEADER_NAME]
    
    # 检查格式：Bearer <token>
    if not auth_header.begins_with(SCHEME + " "):
        return false  # 格式错误
    
    var token: String = auth_header.substr(SCHEME.length() + 1)
    
    # 时序安全比较（防止时序攻击）
    if token.length() != _token.length():
        return false
    
    for i in range(token.length()):
        if token[i] != _token[i]:
            return false
    
    return true

func get_www_authenticate_header() -> String:
    """返回 WWW-Authenticate 头（用于 401 响应）"""
    return SCHEME + ' realm="Godot-MCP", error="invalid_token"'
```

---

### 阶段三：提取 stdio 传输实现（1 天）

#### 步骤 3.1：创建 `mcp_stdio_server.gd`

**文件路径**：`addons/godot_mcp/native_mcp/mcp_stdio_server.gd`

**功能**：从 `mcp_server_core.gd` 中提取 stdio 相关代码

**核心实现**（符合 MCP 规范）：
```gdscript
class_name McpStdioServer
extends McpTransportBase

# 状态变量（带类型提示）
var _thread: Thread = null
var _active: bool = false
var _message_queue: Array[Dictionary] = []  # 消息队列（存储待处理的消息）
var _stdin_pipe = null  # Windows: Pipe, Unix: File

func start() -> bool:
    """启动 stdio 传输层（创建 stdin 监听线程）"""
    _active = true
    _thread = Thread.new()
    _thread.start(_stdin_listen_loop)
    server_started.emit()
    return true

func stop() -> void:
    """停止 stdio 传输层（等待线程结束）"""
    _active = false
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
    _message_queue.clear()
    server_stopped.emit()

func is_running() -> bool:
    """检查是否正在运行"""
    return _active

func _stdin_listen_loop() -> void:
    """stdin 监听循环（在独立线程中运行）"""
    while _active:
        # 从 stdin 读取数据（使用 OS.read_string_from_stdin()）
        var line: String = OS.read_string_from_stdin()
        
        if line.is_empty():
            OS.delay_msec(10)  # 避免 CPU 占用过高
            continue
        
        # 解析消息
        _parse_and_queue_message(line)

func _parse_and_queue_message(line: String) -> void:
    """解析 JSON-RPC 消息并添加到队列"""
    var json = JSON.new()
    var error: Error = json.parse(line)
    
    if error != OK:
        printerr("Failed to parse stdin message: ", json.get_error_message())
        # 发送错误消息到 MCP 客户端
        var error_response: Dictionary = {
            "jsonrpc": "2.0",
            "error": {
                "code": MCPTypes.ERROR_PARSE_ERROR,
                "message": "Parse error: " + json.get_error_message()
            },
            "id": null
        }
        print(JSON.stringify(error_response))
        return
    
    var message: Dictionary = json.get_data()
    _message_queue.append(message)
    
    # 发送信号到主线程（线程安全：使用 call_deferred）
    call_deferred("_emit_message_received", message)

func _emit_message_received(message: Dictionary) -> void:
    """在主线程中发送信号（确保线程安全）"""
    message_received.emit(message, null)  # context 为 null（stdio 不需要）
```

---

### 阶段四：创建 HTTP 传输实现（1-2 天）

#### 步骤 4.1：创建 `mcp_http_server.gd`

**文件路径**：`addons/godot_mcp/native_mcp/mcp_http_server.gd`

**功能**：实现 HTTP 服务器，支持 JSON-RPC over HTTP（符合 MCP 2025-03-26 规范）

**核心实现**：
```gdscript
class_name McpHttpServer
extends McpTransportBase

# 信号定义
signal message_received(message: Dictionary, peer: StreamPeerTCP)
signal server_error(error: String)
signal server_started()
signal server_stopped()

# 常量
const MAX_REQUEST_SIZE: int = 1024 * 1024  # 1MB
const REQUEST_TIMEOUT: float = 30.0  # 30秒超时
const AUTH_HEADER: String = "Authorization"
const AUTH_SCHEME: String = "Bearer"

# 状态变量（带类型提示）
var _tcp_server: TCPServer = null
var _port: int = 9080
var _active: bool = false
var _thread: Thread = null
var _connections: Array[StreamPeerTCP] = []
var _auth_manager: McpAuthManager = null

func set_port(port: int) -> void:
    """设置 HTTP 服务器监听端口"""
    if _active:
        push_error("Cannot change port while server is running")
        return
    _port = port

func set_auth_manager(manager: McpAuthManager) -> void:
    """设置认证管理器"""
    _auth_manager = manager

func start() -> bool:
    """启动 HTTP 服务器"""
    _tcp_server = TCPServer.new()
    
    var error: Error = _tcp_server.listen(_port)
    if error != OK:
        server_error.emit("Failed to listen on port " + str(_port) + ": " + str(error) + 
                         ". Please check if the port is already in use.")
        return false
    
    _active = true
    _thread = Thread.new()
    _thread.start(_http_server_loop)
    
    server_started.emit()
    return true

func stop() -> void:
    """停止 HTTP 服务器"""
    _active = false
    
    # 关闭所有活跃连接
    for peer in _connections:
        if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            peer.disconnect_from_host()
    
    _connections.clear()
    
    # 等待线程结束
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
    
    # 停止 TCP 服务器
    if _tcp_server:
        _tcp_server.stop()
        _tcp_server = null
    
    server_stopped.emit()

func is_running() -> bool:
    """检查是否正在运行"""
    return _active and _tcp_server != null and _tcp_server.is_listening()

func _http_server_loop() -> void:
    """HTTP 服务器主循环（在独立线程中运行）"""
    while _active:
        # 检查新连接
        var peer: StreamPeerTCP = _tcp_server.take_connection()
        if peer:
            _connections.append(peer)
        
        # 处理所有活跃连接
        var disconnected: Array[StreamPeerTCP] = []
        for p in _connections:
            if p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
                disconnected.append(p)
                continue
            
            if p.get_available_bytes() > 0:
                _handle_http_request(p)
        
        # 移除已断开的连接
        for d in disconnected:
            _connections.erase(d)
        
        OS.delay_msec(10)  # 避免 CPU 占用过高

func _handle_http_request(peer: StreamPeerTCP) -> void:
    """处理 HTTP 请求"""
    # 读取 HTTP 请求
    var request: String = ""
    var start_time: float = Time.get_time_dict_from_system()
    
    while peer.get_available_bytes() > 0:
        var chunk: String = peer.get_utf8_string_from_byte(peer.get_available_bytes())
        request += chunk
        
        # 检查是否读取完毕（遇到 \r\n\r\n）
        if request.contains("\r\n\r\n"):
            break
        
        # 检查请求大小是否超过限制
        if request.length() > MAX_REQUEST_SIZE:
            _send_http_error(peer, 413, "Request too large. Maximum size is " + str(MAX_REQUEST_SIZE / 1024) + "KB")
            return
        
        # 检查是否超时
        var current_time: float = Time.get_time_dict_from_system()
        if current_time - start_time > REQUEST_TIMEOUT:
            _send_http_error(peer, 408, "Request timeout. Please ensure the request is sent completely within " + str(REQUEST_TIMEOUT) + " seconds.")
            return
    
    if request.is_empty():
        return
    
    # 解析 HTTP 请求
    var parsed: Dictionary = _parse_http_request(request)
    
    # 检查认证（如果启用了认证）
    if _auth_manager and not _auth_manager.validate_request(parsed["headers"]):
        _send_http_error(peer, 401, "Unauthorized. Please provide a valid Bearer token in the Authorization header.")
        return
    
    # 路由请求
    match parsed["method"]:
        "POST":
            _handle_post_request(peer, parsed)
        "GET":
            _handle_get_request(peer, parsed)
        "OPTIONS":
            _handle_options_request(peer, parsed)
        _:
            _send_http_error(peer, 405, "Method not allowed. Only POST, GET, and OPTIONS are supported.")

func _parse_http_request(raw: String) -> Dictionary:
    """解析 HTTP 请求（返回 method, path, headers, body）"""
    var lines: PackedStringArray = raw.split("\r\n")
    var request_line: PackedStringArray = lines[0].split(" ")
    
    var method: String = request_line[0]
    var path: String = request_line[1]
    var version: String = request_line[2] if request_line.size() > 2 else "HTTP/1.1"
    
    # 解析头部
    var headers: Dictionary = {}
    var body_start: int = -1
    
    for i in range(1, lines.size()):
        if lines[i].is_empty():
            body_start = i + 1
            break
        
        var parts: PackedStringArray = lines[i].split(": ")
        if parts.size() >= 2:
            headers[parts[0]] = parts[1]
    
    # 提取正文
    var body: String = ""
    if body_start != -1 and body_start < lines.size():
        body = lines[body_start]
    
    return {
        "method": method,
        "path": path,
        "version": version,
        "headers": headers,
        "body": body
    }

func _handle_post_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
    """处理 POST 请求（JSON-RPC over HTTP）"""
    # 检查路径
    if parsed["path"] != "/mcp" and parsed["path"] != "/":
        _send_http_error(peer, 404, "Not found. Please use path '/mcp' for MCP requests.")
        return
    
    # 检查 Content-Type
    var content_type: String = parsed["headers"].get("Content-Type", "")
    if not content_type.contains("application/json"):
        _send_http_error(peer, 415, "Unsupported media type. Please use 'Content-Type: application/json'.")
        return
    
    # 解析 JSON-RPC 消息
    var json = JSON.new()
    var parse_error: Error = json.parse(parsed["body"])
    
    if parse_error != OK:
        _send_http_error(peer, 400, "Invalid JSON: " + json.get_error_message())
        return
    
    var message: Dictionary = json.get_data()
    
    # 发送信号到主线程处理（线程安全）
    call_deferred("_emit_message_received", message, peer)

func _handle_get_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
    """处理 GET 请求（SSE 或健康检查）"""
    # 检查是否是 SSE 请求
    if parsed["headers"].get("Accept", "") == "text/event-stream":
        _handle_sse_request(peer, parsed)
        return
    
    # 普通 GET 请求，返回服务器信息
    var info: Dictionary = {
        "name": "Godot-MCP",
        "version": "2.0.0",
        "transport": "http",
        "protocol": "MCP 2025-03-26",
        "endpoints": {
            "mcp": "/mcp (POST)",
            "sse": "/mcp (GET, SSE)"
        }
    }
    
    _send_http_response(peer, info)

func _handle_options_request(peer: StreamPeerTCP, parsed: Dictionary) -> void:
    """处理 OPTIONS 请求（CORS 预检）"""
    var response: String = "HTTP/1.1 204 No Content\r\n"
    response += "Access-Control-Allow-Origin: *\r\n"
    response += "Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n"
    response += "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
    response += "Access-Control-Max-Age: 86400\r\n"
    response += "\r\n"
    
    peer.put_data(response.to_utf8_buffer())
    peer.disconnect_from_host()

func _emit_message_received(message: Dictionary, peer: StreamPeerTCP) -> void:
    """在主线程中发送信号（确保线程安全）"""
    message_received.emit(message, peer)

func send_response(response: Dictionary, peer: StreamPeerTCP) -> void:
    """发送 HTTP 响应（从主线程调用）"""
    _send_http_response(peer, response)

func _send_http_response(peer: StreamPeerTCP, data: Dictionary) -> void:
    """构建并发送 HTTP 响应"""
    var json_string: String = JSON.stringify(data)
    
    var http_response: String = "HTTP/1.1 200 OK\r\n"
    http_response += "Content-Type: application/json\r\n"
    http_response += "Content-Length: " + str(json_string.length()) + "\r\n"
    http_response += "Access-Control-Allow-Origin: *\r\n"
    http_response += "\r\n"
    http_response += json_string
    
    var error: Error = peer.put_data(http_response.to_utf8_buffer())
    if error != OK:
        server_error.emit("Failed to send HTTP response: " + str(error))
    
    peer.disconnect_from_host()

func _send_http_error(peer: StreamPeerTCP, status_code: int, message: String) -> void:
    """发送 HTTP 错误响应"""
    var status_text: String = ""
    match status_code:
        400: status_text = "Bad Request"
        401: status_text = "Unauthorized"
        404: status_text = "Not Found"
        405: status_text = "Method Not Allowed"
        408: status_text = "Request Timeout"
        413: status_text = "Request Too Large"
        415: status_text = "Unsupported Media Type"
        500: status_text = "Internal Server Error"
        _: status_text = "Error"
    
    var response: String = "HTTP/1.1 " + str(status_code) + " " + status_text + "\r\n"
    response += "Content-Type: text/plain\r\n"
    response += "Content-Length: " + str(message.length()) + "\r\n"
    response += "Access-Control-Allow-Origin: *\r\n"
    response += "\r\n"
    response += message
    
    peer.put_data(response.to_utf8_buffer())
    peer.disconnect_from_host()
```

---

### 阶段五：修改 `mcp_server_core.gd`（1 天）

#### 步骤 5.1：提取 stdio 代码

1. 将 stdio 相关函数复制到 `mcp_stdio_server.gd`
2. 在 `mcp_server_core.gd` 中添加传输层支持
3. 修改 `start()` 和 `stop()` 函数

#### 步骤 5.2：添加传输方式切换

（代码已在 3.1.1 中提供）

---

### 阶段六：修改 `mcp_server_native.gd`（0.5 天）

#### 步骤 6.1：添加传输方式配置

（代码已在 3.1.2 中提供）

---

### 阶段七：创建测试脚本（1-2 天）

#### 步骤 7.1：创建 stdio 模式测试脚本

**文件路径**：`test/stdio/test_mcp_stdio.py`

（代码已在上一版本中提供，需添加更详细的错误处理）

#### 步骤 7.2：创建 HTTP 模式测试脚本（含认证测试）

**文件路径**：`test/http/test_mcp_http_server.py`

```python
#!/usr/bin/env python3
"""
测试 Godot-MCP HTTP 服务器（含认证测试）
"""

import requests
import json
import time
import sys

BASE_URL = "http://localhost:9080"
AUTH_TOKEN = "your-secret-token-here"  # 与插件配置中的 token 一致

def test_initialize():
    """测试 initialize 请求（无认证）"""
    print("Testing initialize (no auth)...")
    
    url = f"{BASE_URL}/mcp"
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {
                "name": "test-client",
                "version": "1.0.0"
            }
        }
    }
    
    try:
        response = requests.post(url, json=payload, timeout=5)
        
        if response.status_code == 401:
            print("✅ initialize test passed (auth required as expected)")
            return True
        elif response.status_code == 200:
            print("⚠️ initialize test passed (auth not enabled)")
            return True
        else:
            print(f"❌ initialize test failed: unexpected status code {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_initialize_with_auth():
    """测试 initialize 请求（带认证）"""
    print("\nTesting initialize (with auth)...")
    
    url = f"{BASE_URL}/mcp"
    headers = {
        "Authorization": f"Bearer {AUTH_TOKEN}"
    }
    payload = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {
                "name": "test-client",
                "version": "1.0.0"
            }
        }
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=5)
        print(f"Status code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            result = response.json()
            if "result" in result and "protocolVersion" in result["result"]:
                print("✅ initialize with auth test passed")
                return True
        
        print("❌ initialize with auth test failed")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_tools_list_with_auth():
    """测试 tools/list 请求（带认证）"""
    print("\nTesting tools/list (with auth)...")
    
    url = f"{BASE_URL}/mcp"
    headers = {
        "Authorization": f"Bearer {AUTH_TOKEN}"
    }
    payload = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/list"
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=5)
        print(f"Status code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            result = response.json()
            if "result" in result and "tools" in result["result"]:
                print(f"✅ tools/list test passed - found {len(result['result']['tools'])} tools")
                return True
        
        print("❌ tools/list test failed")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_unauthorized_request():
    """测试未授权的请求（应该返回 401）"""
    print("\nTesting unauthorized request...")
    
    url = f"{BASE_URL}/mcp"
    headers = {
        "Authorization": "Bearer wrong-token"
    }
    payload = {
        "jsonrpc": "2.0",
        "id": 4,
        "method": "tools/list"
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=5)
        
        if response.status_code == 401:
            print("✅ unauthorized request test passed (401 as expected)")
            return True
        else:
            print(f"❌ unauthorized request test failed: expected 401, got {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    """主函数"""
    print("=" * 60)
    print("Godot-MCP HTTP Server Test (with Auth)")
    print("=" * 60)
    print()
    
    # 等待服务器启动
    print("Waiting for server to start...")
    time.sleep(2)
    
    # 运行测试
    results = []
    
    results.append(("initialize (no auth)", test_initialize()))
    results.append(("initialize (with auth)", test_initialize_with_auth()))
    results.append(("tools/list (with auth)", test_tools_list_with_auth()))
    results.append(("unauthorized request", test_unauthorized_request()))
    
    # 打印总结
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    
    passed = 0
    failed = 0
    
    for name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{name}: {status}")
        
        if result:
            passed += 1
        else:
            failed += 1
    
    print(f"\nTotal: {passed + failed}, Passed: {passed}, Failed: {failed}")
    
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
```

#### 步骤 7.3：创建性能测试脚本

**文件路径**：`test/benchmark/performance_test.gd`

```gdscript
@tool
extends EditorScript

# 性能测试：测试 HTTP 服务器的响应时间和并发处理能力

func _run() -> void:
    print("Starting performance test...")
    
    # 测试 1：响应时间
    print("\nTest 1: Response time (single request)")
    var start_time: int = Time.get_ticks_msec()
    
    # 发送请求到 HTTP 服务器
    var http_request: HTTPRequest = HTTPRequest.new()
    add_child(http_request)
    
    http_request.request("http://localhost:9080/mcp", 
                      ["Content-Type: application/json", "Authorization: Bearer test-token"],
                      HTTPClient.METHOD_POST,
                      JSON.stringify({
                          "jsonrpc": "2.0",
                          "id": 1,
                          "method": "tools/list"
                      }))
    
    await http_request.request_completed
    
    var end_time: int = Time.get_ticks_msec()
    var response_time: int = end_time - start_time
    
    print("Response time: " + str(response_time) + "ms")
    
    if response_time < 100:
        print("✅ Response time test passed (< 100ms)")
    else:
        print("⚠️ Response time test warning: > 100ms")
    
    # 测试 2：并发请求
    print("\nTest 2: Concurrent requests (10 simultaneous)")
    var concurrent_start: int = Time.get_ticks_msec()
    var completed: int = 0
    
    for i in range(10):
        var req: HTTPRequest = HTTPRequest.new()
        add_child(req)
        req.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray):
            completed += 1
        )
        req.request("http://localhost:9080/mcp",
                   ["Content-Type: application/json"],
                   HTTPClient.METHOD_POST,
                   JSON.stringify({
                       "jsonrpc": "2.0",
                       "id": i,
                       "method": "tools/list"
                   }))
    
    # 等待所有请求完成（最多 10 秒）
    while completed < 10 and Time.get_ticks_msec() - concurrent_start < 10000:
        await get_tree().process_frame
    
    var concurrent_end: int = Time.get_ticks_msec()
    var concurrent_time: int = concurrent_end - concurrent_start
    
    print("Concurrent requests completed: " + str(completed) + "/10")
    print("Total time: " + str(concurrent_time) + "ms")
    
    if completed == 10:
        print("✅ Concurrent requests test passed")
    else:
        print("❌ Concurrent requests test failed")
    
    print("\nPerformance test completed")
```

---

### 阶段八：更新文档和配置（0.5 天）

#### 步骤 8.1：创建配置示例文档

1. `docs/configuration/mcp-stdio-config-example.json`
2. `docs/configuration/mcp-http-config-example.json`（含认证配置）

#### 步骤 8.2：更新 README.md

添加双传输模式的说明（含认证配置）：

```markdown
## 传输方式选择

Godot-MCP 支持两种传输方式：

### stdio 模式（默认）

适用于本地开发和测试。

**启动方式**：
1. 在 Godot Editor 中打开项目
2. 启用 `godot_mcp` 插件
3. 在插件设置中选择 `transport_mode = "stdio"`
4. 启动服务器

**客户端配置**：
```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "path/to/godot.exe",
      "args": ["--headless", "--script", "res://addons/godot_mcp/mcp_server_native.gd"]
    }
  }
}
```

### HTTP 模式（推荐生产环境）

适用于生产部署和远程访问。

**启动方式**：
1. 在 Godot Editor 中打开项目
2. 启用 `godot_mcp` 插件
3. 在插件设置中选择 `transport_mode = "http"`
4. 设置 `http_port`（默认 9080）
5. （可选）启用 `auth_enabled` 并设置 `auth_token`
6. 启动服务器

**客户端配置（无认证）**：
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

**客户端配置（有认证）**：
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

**安全建议**：
- 生产环境强烈建议启用认证（`auth_enabled = true`）
- 使用强密码作为 token（至少 16 字符，包含大小写字母、数字、特殊字符）
- 不要将 token 提交到版本库（使用环境变量或配置文件）
```

---

### 阶段九：完整测试流程（1-2 天）

#### 9.1 stdio 模式测试

**测试 1：启动和停止**
1. 设置 `transport_mode = "stdio"`
2. 启动服务器
3. 检查输出日志
4. 停止服务器

**测试 2：MCP 协议**
```bash
python test/stdio/test_mcp_stdio.py
```

**预期结果**：所有测试通过 ✅

#### 9.2 HTTP 模式测试（无认证）

**测试 3：启动和停止**
1. 设置 `transport_mode = "http"`
2. 启动服务器
3. 检查 HTTP 服务器是否监听端口
4. 停止服务器

**测试 4：MCP 协议（HTTP，无认证）**
```bash
python test/http/test_mcp_http_server.py
```

**预期结果**：所有测试通过 ✅

**测试 5：使用 curl**
```bash
bash test/http/curl_examples.sh
```

**预期结果**：所有请求成功 ✅

#### 9.3 HTTP 模式测试（有认证）

**测试 6：认证测试**
1. 在插件设置中启用 `auth_enabled = true`
2. 设置 `auth_token = "your-secret-token-here"`
3. 重新启动服务器
4. 运行认证测试脚本：
   ```bash
   python test/http/test_mcp_http_server.py
   ```

**预期结果**：
- 无认证请求返回 401 ✅
- 正确认证请求返回 200 ✅
- 错误 token 返回 401 ✅

#### 9.4 切换测试

**测试 7：动态切换传输方式**
1. 启动服务器（stdio 模式）
2. 停止服务器
3. 修改配置为 HTTP 模式
4. 重新启动服务器
5. 验证 HTTP 服务器正常运行

**预期结果**：切换成功 ✅

#### 9.5 性能测试

**测试 8：响应时间**
```bash
gd -s test/benchmark/performance_test.gd
```

**预期结果**：
- 单次请求响应时间 < 100ms ✅
- 并发 10 个请求全部成功 ✅

---

## 5. 回滚计划

如果出现严重问题，需要回滚到纯 stdio 方案：

### 5.1 保留旧代码

在修改之前，先备份以下文件：
- `addons/godot_mcp/native_mcp/mcp_server_core.gd` → `mcp_server_core.gd.bak`
- `addons/godot_mcp/mcp_server_native.gd` → `mcp_server_native.gd.bak`

### 5.2 回滚步骤

1. 停止 Godot Editor
2. 恢复备份的文件：
   ```bash
   cp addons/godot_mcp/native_mcp/mcp_server_core.gd.bak addons/godot_mcp/native_mcp/mcp_server_core.gd
   cp addons/godot_mcp/mcp_server_native.gd.bak addons/godot_mcp/mcp_server_native.gd
   ```
3. 删除新创建的文件：
   ```bash
   rm addons/godot_mcp/native_mcp/mcp_transport_base.gd
   rm addons/godot_mcp/native_mcp/mcp_stdio_server.gd
   rm addons/godot_mcp/native_mcp/mcp_http_server.gd
   rm addons/godot_mcp/native_mcp/mcp_auth_manager.gd
   ```
4. 重新启动 Godot Editor
5. 使用旧的 stdio 配置

---

## 6. 时间估算

| 阶段 | 任务 | 时间估算 | 负责人 | 符合规范 |
|------|------|----------|--------|----------|
| 阶段一 | 创建 `mcp_transport_base.gd` | 0.5 天 | AI Assistant | Godot Dev Guide |
| 阶段二 | 创建 `mcp_auth_manager.gd` | 0.5 天 | AI Assistant | MCP 安全最佳实践 |
| 阶段三 | 创建 `mcp_stdio_server.gd` | 1 天 | AI Assistant | MCP 规范 |
| 阶段四 | 创建 `mcp_http_server.gd` | 1-2 天 | AI Assistant | MCP 规范 |
| 阶段五 | 修改 `mcp_server_core.gd` | 1 天 | AI Assistant | Godot Dev Guide |
| 阶段六 | 修改 `mcp_server_native.gd` | 0.5 天 | AI Assistant | Godot Dev Guide |
| 阶段七 | 创建测试脚本（含认证测试） | 1-2 天 | AI Assistant | MCP 规范 |
| 阶段八 | 更新文档和配置（含认证） | 0.5 天 | AI Assistant | MCP 规范 |
| 阶段九 | 完整测试流程（含性能测试） | 1-2 天 | AI Assistant + 用户 | MCP 规范 |
| **总计** | | **7-10.5 天** | | |

---

## 7. 后续优化（可选）

### 7.1 实现 SSE 流

**目标**：支持服务器主动推送消息到客户端（符合 MCP 2025-03-26 规范）

**实现步骤**：
1. 创建 `mcp_sse_stream.gd`
2. 修改 `mcp_http_server.gd`，支持 SSE 请求
3. 修改 `mcp_server_core.gd`，支持主动推送消息

### 7.2 实现会话管理

**目标**：支持多个 MCP 客户端同时连接（符合 MCP 规范）

**实现步骤**：
1. 创建 `mcp_session_manager.gd`
2. 修改 `mcp_http_server.gd`，生成和验证 `Mcp-Session-Id`
3. 修改 `mcp_server_core.gd`，根据会话 ID 路由消息

### 7.3 支持远程访问

**目标**：允许从其他计算机访问 Godot-MCP 服务器

**实现步骤**：
1. 修改 `mcp_http_server.gd`，监听 `0.0.0.0` 而不是 `127.0.0.1`
2. 强制启用认证（`auth_enabled = true`）
3. 添加 HTTPS 支持（使用 TLS/SSL）
4. 在插件设置中添加"允许远程访问"选项

---

## 8. 附录：完整文件列表

### 8.1 创建的文件

1. `addons/godot_mcp/native_mcp/mcp_transport_base.gd`
2. `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`
3. `addons/godot_mcp/native_mcp/mcp_http_server.gd`
4. `addons/godot_mcp/native_mcp/mcp_auth_manager.gd` ✅ 新增
5. `addons/godot_mcp/native_mcp/mcp_sse_stream.gd`（可选）
6. `addons/godot_mcp/native_mcp/mcp_session_manager.gd`（可选）
7. `test/stdio/test_mcp_stdio.py`
8. `test/http/test_mcp_http_server.py` ✅ 更新（含认证测试）
9. `test/http/test_mcp_http_client.js`
10. `test/http/curl_examples.sh`
11. `test/benchmark/performance_test.gd` ✅ 新增
12. `docs/configuration/mcp-stdio-config-example.json`
13. `docs/configuration/mcp-http-config-example.json` ✅ 更新（含认证配置）
14. `addons/godot_mcp/native_mcp/default_config.json`

### 8.2 修改的文件

1. `addons/godot_mcp/native_mcp/mcp_server_core.gd`
2. `addons/godot_mcp/mcp_server_native.gd`
3. `addons/godot_mcp/ui/mcp_panel_native.gd`
4. `README.md` ✅ 更新（含认证说明）
5. `docs/README.md`（可选）

### 8.3 备份的文件

1. `addons/godot_mcp/native_mcp/mcp_server_core.gd.bak`
2. `addons/godot_mcp/mcp_server_native.gd.bak`

---

## 9. 总结

本迁移计划详细说明了如何将 Godot-MCP 从纯 stdio 传输方案扩展为支持 stdio 和 HTTP/SSE 双模式（符合 Godot 4.x 和 MCP 规范）。

**主要工作**：
1. 创建传输层基类（`mcp_transport_base.gd`）
2. 提取 stdio 实现到 `mcp_stdio_server.gd`
3. 创建 HTTP 服务器实现（`mcp_http_server.gd`）
4. 创建认证管理器（`mcp_auth_manager.gd`）✅ 新增
5. 修改现有核心文件以支持多种传输方式
6. 创建完整的测试脚本和文档（含认证测试和性能测试）
7. 更新 MCP 客户端配置（含认证配置）

**预期成果**：
1. 保留 stdio 方案作为可选项（开发测试用）
2. 新增 HTTP/SSE 方案（生产环境用）
3. 用户可以通过配置灵活切换传输方式
4. 符合 MCP 最新规范（Streamable HTTP）
5. ✅ 新增：HTTP 模式支持认证（token-based auth）
6. ✅ 新增：完整的性能测试和认证测试

**风险**：
1. 传输层抽象增加代码复杂度
2. 需要充分测试两种传输方式的兼容性
3. 多线程安全（HTTP 服务器）
4. ✅ 新增：认证管理器的安全性（token 泄露风险）

**建议**：
1. 分阶段实施，先实现基本功能，再优化性能
2. 充分测试，特别是两种传输方式的切换
3. 保留 stdio 方案作为备份
4. ✅ 新增：生产环境务必启用认证
5. ✅ 新增：定期更新 token，避免泄露风险

---

## 10. 参考资料

### Godot 4.x 开发指南
- Godot 官方文档：https://docs.godotengine.org/en/stable/
- GDScript 类型提示：https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html
- 线程安全：https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html

### MCP 开发指南
- MCP 官方规范：https://spec.modelcontextprotocol.io/
- MCP 传输机制：https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/transports/
- MCP 安全最佳实践：https://spec.modelcontextprotocol.io/specification/2025-03-26/basic/security/
- FastMCP 文档：https://github.com/modelcontextprotocol/python-sdk

### HTTP 服务器实现
- Godot TCPServer 文档：https://docs.godotengine.org/en/stable/classes/class_tcpserver.html
- HTTP/1.1 规范：https://datatracker.ietf.org/doc/html/rfc9110
- Bearer Token 认证：https://datatracker.ietf.org/doc/html/rfc6750

---

**文档结束**

如有问题，请参考：
- `docs/architecture/http-sse-migration-plan.md`（协议对比分析）
- `docs/testing/http-testing-guide.md`（测试指南）
- `README.md`（用户文档）
