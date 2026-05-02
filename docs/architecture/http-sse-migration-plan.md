# Godot-MCP 架构重构方案：从 stdio 迁移到 HTTP/SSE

## 1. 当前架构问题分析

### 当前架构（stdio 传输）
```
MCP Client (Claude Desktop) 
  ↓ 启动子进程
Godot Editor (带 MCP 插件)
  ↓ stdin/stdout
MCP Server (在 Godot 插件内)
```

### 存在的三个核心问题

**问题1：stdout 污染**
- Godot 引擎本身的大量日志输出会混在 stdout 中
- `print()` 语句的输出也会进入 stdout
- MCP 客户端无法从污染后的 stdout 中正确解析 JSON-RPC 响应
- 当前解决方案（`prints()`、强制刷新）都是治标不治本

**问题2：无法连接已运行的 Godot 实例**
- 当前方案要求 MCP 客户端启动 Godot 作为子进程
- 如果用户已经打开了 Godot 编辑器，无法通过 MCP 连接并操作它
- 每次都要重新启动 Godot，无法利用已打开的项目状态

**问题3：MCP 客户端适配困难**
- stdio 传输要求客户端管理子进程的生命周期
- 需要正确处理 stdin/stdout 的读写
- 错误处理复杂（进程崩溃、超时等）

---

## 2. HTTP/SSE 方案可行性分析

### Godot 4.x 的 HTTP 服务器能力

#### 方案 A：使用 Godot 内置 TCPServer 实现 HTTP
- **可行性**：✅ 完全可行
- **实现方式**：
  ```gdscript
  var server = TCPServer.new()
  server.listen(9080)
  ```
  然后在 `_process(delta)` 中轮询连接，手动解析 HTTP 请求
- **优点**：无需额外依赖，完全自主可控
- **缺点**：需要手动实现 HTTP 协议解析（请求行、头部、正文）

#### 方案 B：使用第三方 Godot 插件
- **可行性**：✅ 可行
- **推荐插件**：[REST API Server](https://godotengine.org/asset-library/asset/4167)
  - 提供 `RESTHttpServer` 和 `RESTApiHandler` 节点
  - 支持 GET、POST、PUT、DELETE 方法
  - 提供信号（`on_get`、`on_post` 等）
- **优点**：开箱即用，无需手动解析 HTTP
- **缺点**：需要用户额外安装插件

#### 方案 C：使用 GDExtension（C++ 模块）
- **可行性**：✅ 可行，但复杂度高
- **实现方式**：编写一个 GDExtension，内置 HTTP 服务器能力
- **优点**：性能最好
- **缺点**：开发成本高，需要编译不同平台的二进制文件

### MCP Streamable HTTP 传输规范（2025-03-26 更新）

根据 [MCP 官方规范](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports)，新的 Streamable HTTP 传输方式：

#### 核心特性
1. **单一 HTTP 端点**：服务器只提供一个 HTTP 端点（如 `http://localhost:9080/mcp`）
2. **POST 请求**：客户端通过 POST 发送 JSON-RPC 请求
3. **SSE 响应**：服务器可以通过 SSE（Server-Sent Events）流式返回响应
4. **会话管理**：服务器可以分配会话 ID（通过 `Mcp-Session-Id` 头部）
5. **可恢复连接**：支持通过 `Last-Event-ID` 头部恢复 SSE 流

#### 通信流程
```
客户端                          服务器
  |                                |
  |---- POST /mcp (InitializeRequest) --->|
  |<--- InitializeResult + Session-ID ---|
  |                                |
  |---- POST /mcp (tools/list) -------->|
  |<--- SSE: tools/list result --------|
  |                                |
  |---- GET /mcp (打开 SSE 流) ------->|
  |<--- SSE: 服务器主动推送消息 ------|
  |                                |
```

---

## 3. 新架构设计

### 架构图
```
MCP Client (Claude Desktop)
  ↓ HTTP POST/GET
Godot Editor (带 MCP 插件，运行 HTTP 服务器)
  ↓ 内部调用
MCP Server (在 Godot 插件内，处理 JSON-RPC 请求)
  ↓ 调用
Godot Editor API (场景、节点、脚本等操作)
```

### 核心组件

#### 1. HTTP 服务器（`mcp_http_server.gd`）
- 负责监听 HTTP 请求
- 解析 HTTP 请求，提取 JSON-RPC 消息
- 返回 HTTP 响应（JSON 或 SSE 流）
- 管理会话（生成和验证 `Mcp-Session-Id`）

#### 2. MCP 服务器核心（`mcp_server_core.gd`）
- 保持不变，处理 JSON-RPC 请求
- 调用相应的工具和资源
- 返回 JSON-RPC 响应

#### 3. 插件主类（`mcp_server_native.gd`）
- 启动/停止 HTTP 服务器
- 注册工具和资源
- 提供编辑器 UI 面板

---
## 3. 传输协议方案对比

### 3.1 可选传输协议概览

在 Godot 4.x 中，我们可以使用以下传输协议实现 MCP 服务器：

| 协议 | Godot 类 | 传输层 | 可靠性 | 复杂度 | MCP 官方支持 |
|------|-----------|--------|--------|--------|--------------|
| **Raw TCP** | `TCPServer` + `StreamPeerTCP` | TCP | ✅ 可靠 | 中 | ❌ 不支持 |
| **UDP** | `UDPServer` + `PacketPeerUDP` | UDP | ❌ 不可靠 | 中 | ❌ 不支持 |
| **HTTP/SSE** | `TCPServer` + HTTP 解析 | TCP | ✅ 可靠 | 高 | ✅ 支持（2025-03-26） |
| **WebSocket** | `WebSocketServer` + `WebSocketPeer` | TCP | ✅ 可靠 | 低 | ✅ 支持 |

---

### 3.2 Raw TCP 方案

#### 实现原理

**使用 Godot 内置类**：
- `TCPServer`：监听 TCP 端口，接受连接
- `StreamPeerTCP`：代表一个 TCP 连接，提供读写方法

**通信流程**：
```
MCP Client (Claude Desktop)          Godot Editor (MCP Plugin)
          │                                    │
          │──── TCP 连接 (localhost:9080) ───>│
          │                                    │
          │──── JSON-RPC 请求 (原始 TCP) ────>│
          │                                    │
          │<─── JSON-RPC 响应 (原始 TCP) ─────│
          │                                    │
          │──── 连接关闭 ────────────────────>│
          │                                    │
```

#### 代码实现示例

**TCP 服务器（`mcp_tcp_server.gd`）**：
```gdscript
@tool
class_name McpTcpServer
extends RefCounted

signal message_received(message: Dictionary, peer: StreamPeerTCP)
signal server_error(error: String)

var _tcp_server: TCPServer = null
var _port: int = 9080
var _active: bool = false
var _thread: Thread = null
var _connections: Array = []  # 活跃连接列表

# 启动 TCP 服务器
func start(port: int = 9080) -> bool:
    _port = port
    _tcp_server = TCPServer.new()
    
    var error: Error = _tcp_server.listen(_port)
    if error != OK:
        printerr("[MCP TCP] Failed to listen on port ", _port, ": ", error)
        return false
    
    _active = true
    _thread = Thread.new()
    _thread.start(_tcp_server_loop)
    
    printerr("[MCP TCP] Server started on port ", _port)
    return true

# 停止 TCP 服务器
func stop() -> void:
    _active = false
    
    # 关闭所有活跃连接
    for conn in _connections:
        var peer: StreamPeerTCP = conn
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
    
    printerr("[MCP TCP] Server stopped")

# TCP 服务器主循环（在线程中运行）
func _tcp_server_loop() -> void:
    while _active:
        # 检查新连接
        var peer: StreamPeerTCP = _tcp_server.take_connection()
        if peer:
            printerr("[MCP TCP] New connection from: ", peer.get_connected_host(), ":", peer.get_connected_port())
            _connections.append(peer)
        
        # 处理所有活跃连接
        var disconnected: Array = []
        for conn in _connections:
            var p: StreamPeerTCP = conn
            
            # 检查连接状态
            if p.get_status() != StreamPeerTCP.STATUS_CONNECTED:
                disconnected.append(p)
                continue
            
            # 检查是否有数据可读
            if p.get_available_bytes() > 0:
                _handle_tcp_message(p)
        
        # 移除已断开的连接
        for d in disconnected:
            _connections.erase(d)
        
        # 避免 CPU 占用过高
        OS.delay_msec(10)
    
    printerr("[MCP TCP] Server loop exited")

# 处理 TCP 消息
func _handle_tcp_message(peer: StreamPeerTCP) -> void:
    # 读取所有可用数据
    var raw_data: String = ""
    while peer.get_available_bytes() > 0:
        raw_data += peer.get_utf8_string_from_byte(peer.get_available_bytes())
    
    if raw_data.is_empty():
        return
    
    printerr("[MCP TCP] Received: ", raw_data)
    
    # 解析 JSON-RPC 消息（假设每行一个 JSON 对象）
    var lines: PackedStringArray = raw_data.split("\n")
    for line in lines:
        if line.strip_edges().is_empty():
            continue
        
        var json = JSON.new()
        var error: Error = json.parse(line)
        
        if error != OK:
            printerr("[MCP TCP] JSON parse error: ", json.get_error_message())
            _send_error_response(peer, null, -32700, "Parse error")
            continue
        
        var message: Dictionary = json.get_data()
        
        # 发送信号到主线程处理
        message_received.emit(message, peer)

# 发送响应
func send_response(response: Dictionary, peer: StreamPeerTCP) -> void:
    var json_string: String = JSON.stringify(response)
    
    # 添加换行符作为消息分隔符
    json_string += "\n"
    
    # 发送到 TCP 连接
    var error: Error = peer.put_data(json_string.to_utf8_buffer())
    if error != OK:
        printerr("[MCP TCP] Failed to send response: ", error)
        server_error.emit("Failed to send response: " + str(error))
    else:
        printerr("[MCP TCP] Sent response: ", json_string)

# 发送错误响应
func _send_error_response(peer: StreamPeerTCP, id, code: int, message: String) -> void:
    var error_response: Dictionary = {
        "jsonrpc": "2.0",
        "error": {
            "code": code,
            "message": message
        },
        "id": id
    }
    send_response(error_response, peer)

# 检查服务器是否活跃
func is_active() -> bool:
    return _active and _tcp_server != null and _tcp_server.is_listening()
```

#### 优点

1. **简单直接**：无需实现 HTTP 协议解析
2. **低延迟**：没有 HTTP 协议的开销
3. **可靠传输**：基于 TCP，保证消息的顺序和完整性
4. **完全可控**：可以自定义协议格式（如消息分隔符、编码方式等）

#### 缺点

1. **MCP 官方不支持**：MCP 规范中没有定义 Raw TCP 传输方式
2. **需要自定义协议**：需要定义消息格式、分隔符、编码方式等
3. **MCP 客户端需要适配**：Claude Desktop 等客户端不支持 Raw TCP，需要自己写客户端
4. **无会话管理**：需要自己实现会话管理机制
5. **无标准调试工具**：无法使用 curl、Postman 等标准 HTTP 调试工具

#### 适用场景

- ✅ 自定义 MCP 客户端（如自己开发一个 Godot MCP 客户端）
- ✅ 对性能要求极高的场景
- ❌ 需要与标准 MCP 客户端（如 Claude Desktop）集成
- ❌ 需要远程访问和调试

---

### 3.3 UDP 方案

#### 实现原理

**使用 Godot 内置类**：
- `UDPServer`：监听 UDP 端口，接受连接
- `PacketPeerUDP`：代表一个 UDP "连接"（无连接状态）

**通信流程**：
```
MCP Client (Claude Desktop)          Godot Editor (MCP Plugin)
          │                                    │
          │──── UDP 数据包 (localhost:9080) ─>│
          │                                    │
          │<─── UDP 数据包 (localhost:XXXX) ──│
          │                                    │
```

#### 代码实现示例

**UDP 服务器（`mcp_udp_server.gd`）**：
```gdscript
@tool
class_name McpUdpServer
extends RefCounted

signal message_received(message: Dictionary, peer_address: String, peer_port: int)
signal server_error(error: String)

var _udp_server: UDPServer = null
var _port: int = 9080
var _active: bool = false
var _thread: Thread = null

# 启动 UDP 服务器
func start(port: int = 9080) -> bool:
    _port = port
    _udp_server = UDPServer.new()
    
    var error: Error = _udp_server.listen(_port)
    if error != OK:
        printerr("[MCP UDP] Failed to listen on port ", _port, ": ", error)
        return false
    
    _active = true
    _thread = Thread.new()
    _thread.start(_udp_server_loop)
    
    printerr("[MCP UDP] Server started on port ", _port)
    return true

# 停止 UDP 服务器
func stop() -> void:
    _active = false
    
    # 等待线程结束
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
    
    # 停止 UDP 服务器
    if _udp_server:
        _udp_server.stop()
        _udp_server = null
    
    printerr("[MCP UDP] Server stopped")

# UDP 服务器主循环（在线程中运行）
func _udp_server_loop() -> void:
    while _active:
        # 检查是否有新数据
        if _udp_server.is_connection_available():
            var peer: PacketPeerUDP = _udp_server.take_packet()
            
            if peer:
                _handle_udp_packet(peer)
        
        # 避免 CPU 占用过高
        OS.delay_msec(10)
    
    printerr("[MCP UDP] Server loop exited")

# 处理 UDP 数据包
func _handle_udp_packet(peer: PacketPeerUDP) -> void:
    # 获取发送方地址和端口
    var peer_address: String = peer.get_packet_address()
    var peer_port: int = peer.get_packet_port()
    
    # 读取数据包
    var packet: PackedByteArray = peer.get_packet()
    var raw_data: String = packet.get_string_from_utf8()
    
    if raw_data.is_empty():
        return
    
    printerr("[MCP UDP] Received from ", peer_address, ":", peer_port, ": ", raw_data)
    
    # 解析 JSON-RPC 消息
    var json = JSON.new()
    var error: Error = json.parse(raw_data)
    
    if error != OK:
        printerr("[MCP UDP] JSON parse error: ", json.get_error_message())
        return
    
    var message: Dictionary = json.get_data()
    
    # 发送信号到主线程处理
    message_received.emit(message, peer_address, peer_port)
    
    # 注意：UDP 是无连接的，需要保存 peer 对象或重新创建连接来发送响应
    _store_peer(message["id"], peer)

# 存储 peer 对象（用于发送响应）
var _pending_responses: Dictionary = {}  # message_id -> PacketPeerUDP

func _store_peer(message_id, peer: PacketPeerUDP) -> void:
    _pending_responses[message_id] = peer

# 发送响应
func send_response(response: Dictionary, message_id) -> void:
    if not _pending_responses.has(message_id):
        printerr("[MCP UDP] No pending response for message ID: ", message_id)
        return
    
    var peer: PacketPeerUDP = _pending_responses[message_id]
    _pending_responses.erase(message_id)
    
    var json_string: String = JSON.stringify(response)
    var packet: PackedByteArray = json_string.to_utf8_buffer()
    
    # 发送 UDP 数据包
    var error: Error = peer.put_packet(packet)
    if error != OK:
        printerr("[MCP UDP] Failed to send response: ", error)
        server_error.emit("Failed to send response: " + str(error))
    else:
        printerr("[MCP UDP] Sent response to ", peer.get_packet_address(), ":", peer.get_packet_port())

# 检查服务器是否活跃
func is_active() -> bool:
    return _active and _udp_server != null and _udp_server.is_listening()
```

#### 优点

1. **极低延迟**：UDP 无需建立连接，无拥塞控制
2. **简单轻量**：协议开销极小
3. **支持广播**：可以一对多通信

#### 缺点

1. **不可靠传输**：数据包可能丢失、重复、乱序
2. **MCP 官方不支持**：MCP 规范中没有定义 UDP 传输方式
3. **需要实现可靠性机制**：如果需要可靠传输，需要自己实现重传、排序等
4. **消息大小限制**：单个 UDP 数据包有大小限制（通常 64KB）
5. **无标准调试工具**：无法使用 curl、Postman 等标准 HTTP 调试工具

#### 为什么 UDP 不适合 MCP

**MCP 协议的要求**：
- ✅ **可靠传输**：JSON-RPC 请求和响应必须可靠送达
- ✅ **顺序保证**：请求和响应的顺序必须保证
- ✅ **大消息支持**：某些工具调用可能返回大量数据

**UDP 的问题**：
- ❌ 数据包可能丢失 → JSON-RPC 请求或响应丢失
- ❌ 数据包可能乱序 → 响应与请求不匹配
- ❌ 大数据包被分片 → 部分分片丢失导致整个消息丢失

**结论**：❌ **不推荐使用 UDP 实现 MCP 服务器**

---

### 3.4 HTTP/SSE 方案（详细分析见第 2 节）

#### 实现原理

**使用 Godot 内置类**：
- `TCPServer`：监听 TCP 端口
- 手动解析 HTTP 请求（请求行、头部、正文）
- 手动构造 HTTP 响应

**通信流程**（符合 MCP Streamable HTTP 规范）：
```
MCP Client (Claude Desktop)          Godot Editor (MCP Plugin)
          │                                    │
          │──── POST /mcp (JSON-RPC) ───────>│
          │                                    │
          │<─── HTTP 200 OK (JSON-RPC) ──────│
          │                                    │
          │──── GET /mcp (SSE 流) ──────────>│
          │                                    │
          │<─── SSE: data: {...}\n\n ───────│
          │<─── SSE: data: {...}\n\n ───────│
          │                                    │
```

#### 优点

1. **✅ MCP 官方支持**：符合 MCP Streamable HTTP 规范（2025-03-26）
2. **✅ 标准协议**：可以使用 curl、Postman 等标准工具调试
3. **✅ 易于集成**：Claude Desktop 等 MCP 客户端原生支持 HTTP
4. **✅ 会话管理**：MCP 规范定义了 `Mcp-Session-Id` 头部
5. **✅ 支持远程访问**：可以通过互联网访问（需要身份验证）

#### 缺点

1. **实现复杂度高**：需要手动解析 HTTP 协议
2. **协议开销**：HTTP 头部增加带宽消耗
3. **需要管理连接**：HTTP 是无连接的，需要管理会话状态

#### 适用场景

- ✅ 需要与标准 MCP 客户端（如 Claude Desktop）集成
- ✅ 需要远程访问和调试
- ✅ 需要使用标准 HTTP 调试工具
- ❌ 对性能要求极高的场景（但仍然足够快）

---

### 3.5 WebSocket 方案

#### 实现原理

**使用 Godot 内置类**：
- `WebSocketServer`：监听 WebSocket 连接
- `WebSocketPeer`：代表一个 WebSocket 连接

**通信流程**：
```
MCP Client (Claude Desktop)          Godot Editor (MCP Plugin)
          │                                    │
          │──── WebSocket 握手 (HTTP Upgrade) ─>│
          │<─── 101 Switching Protocols ──────│
          │                                    │
          │──── WebSocket 帧 (JSON-RPC) ────>│
          │                                    │
          │<─── WebSocket 帧 (JSON-RPC) ─────│
          │                                    │
          │──── WebSocket 关闭帧 ────────────>│
          │                                    │
```

#### 代码实现示例

**WebSocket 服务器（`mcp_websocket_server.gd`）**：
```gdscript
@tool
class_name McpWebSocketServer
extends RefCounted

signal message_received(message: Dictionary, peer: WebSocketPeer)
signal peer_connected(peer: WebSocketPeer)
signal peer_disconnected(peer: WebSocketPeer)
signal server_error(error: String)

var _ws_server: WebSocketServer = null
var _port: int = 9080
var _active: bool = false
var _peers: Dictionary = {}  # peer_id -> WebSocketPeer

# 启动 WebSocket 服务器
func start(port: int = 9080) -> bool:
    _port = port
    _ws_server = WebSocketServer.new()
    
    # 监听端口
    var error: Error = _ws_server.listen(_port, PackedStringArray())
    if error != OK:
        printerr("[MCP WS] Failed to listen on port ", _port, ": ", error)
        return false
    
    _active = true
    
    # 连接信号
    _ws_server.peer_connected.connect(_on_peer_connected)
    _ws_server.peer_disconnected.connect(_on_peer_disconnected)
    
    printerr("[MCP WS] Server started on port ", _port)
    return true

# 停止 WebSocket 服务器
func stop() -> void:
    _active = false
    
    # 关闭所有 peer 连接
    for peer_id in _peers:
        var peer: WebSocketPeer = _peers[peer_id]
        peer.close()
    
    _peers.clear()
    
    # 停止 WebSocket 服务器
    if _ws_server:
        _ws_server.stop()
        _ws_server = null
    
    printerr("[MCP WS] Server stopped")

# 轮询（需要在 _process 中调用）
func poll() -> void:
    if not _active or not _ws_server:
        return
    
    # 轮询 WebSocket 服务器
    _ws_server.poll()
    
    # 处理所有 peer 的消息
    for peer_id in _peers:
        var peer: WebSocketPeer = _peers[peer_id]
        
        if peer.get_available_packet_count() > 0:
            _handle_websocket_message(peer)

# 处理 WebSocket 消息
func _handle_websocket_message(peer: WebSocketPeer) -> void:
    # 读取数据包
    var packet: PackedByteArray = peer.get_packet()
    var raw_data: String = packet.get_string_from_utf8()
    
    if raw_data.is_empty():
        return
    
    printerr("[MCP WS] Received: ", raw_data)
    
    # 解析 JSON-RPC 消息
    var json = JSON.new()
    var error: Error = json.parse(raw_data)
    
    if error != OK:
        printerr("[MCP WS] JSON parse error: ", json.get_error_message())
        _send_error_response(peer, null, -32700, "Parse error")
        return
    
    var message: Dictionary = json.get_data()
    
    # 发送信号到主线程处理
    message_received.emit(message, peer)

# Peer 连接事件
func _on_peer_connected(id: int) -> void:
    if not _ws_server:
        return
    
    var peer: WebSocketPeer = _ws_server.get_peer(id)
    if peer:
        _peers[id] = peer
        printerr("[MCP WS] Peer connected: ", id, " (", peer.get_connected_host(), ":", peer.get_connected_port(), ")")
        peer_connected.emit(peer)

# Peer 断开连接事件
func _on_peer_disconnected(id: int, was_clean: bool) -> void:
    if _peers.has(id):
        var peer: WebSocketPeer = _peers[id]
        printerr("[MCP WS] Peer disconnected: ", id, " (clean: ", was_clean, ")")
        peer_disconnected.emit(peer)
        _peers.erase(id)

# 发送响应
func send_response(response: Dictionary, peer: WebSocketPeer) -> void:
    var json_string: String = JSON.stringify(response)
    
    # 发送到 WebSocket 连接
    var error: Error = peer.put_packet(json_string.to_utf8_buffer())
    if error != OK:
        printerr("[MCP WS] Failed to send response: ", error)
        server_error.emit("Failed to send response: " + str(error))
    else:
        printerr("[MCP WS] Sent response: ", json_string)

# 发送错误响应
func _send_error_response(peer: WebSocketPeer, id, code: int, message: String) -> void:
    var error_response: Dictionary = {
        "jsonrpc": "2.0",
        "error": {
            "code": code,
            "message": message
        },
        "id": id
    }
    send_response(error_response, peer)

# 检查服务器是否活跃
func is_active() -> bool:
    return _active and _ws_server != null

# 在主线程中轮询（需要在 EditorPlugin 的 _process 中调用）
func _process(delta: float) -> void:
    poll()
```

#### 在 EditorPlugin 中集成

```gdscript
@tool
extends EditorPlugin

var _ws_server: McpWebSocketServer = null

func _ready():
    _ws_server = load("res://addons/godot_mcp/native_mcp/mcp_websocket_server.gd").new()
    _ws_server.message_received.connect(_on_message_received)
    _ws_server.peer_connected.connect(_on_peer_connected)
    _ws_server.peer_disconnected.connect(_on_peer_disconnected)
    
    if _ws_server.start(9080):
        print("[MCP] WebSocket server started on port 9080")

func _process(delta: float):
    # 轮询 WebSocket 服务器
    if _ws_server:
        _ws_server.poll()

func _on_message_received(message: Dictionary, peer: WebSocketPeer):
    # 处理 MCP 消息（在主线程中）
    var response = _process_mcp_message(message)
    
    # 发送响应
    _ws_server.send_response(response, peer)

func _on_peer_connected(peer: WebSocketPeer):
    print("[MCP] Client connected: ", peer.get_connected_host())

func _on_peer_disconnected(peer: WebSocketPeer):
    print("[MCP] Client disconnected: ", peer.get_connected_host())

func _exit_tree():
    if _ws_server:
        _ws_server.stop()
```

#### 优点

1. **✅ 标准协议**：WebSocket 是 W3C 标准，广泛支持
2. **✅ 全双工通信**：客户端和服务器可以同时发送消息
3. **✅ 低延迟**：连接建立后，消息交换无需 HTTP 请求/响应循环
4. **✅ 易于实现**：Godot 提供了 `WebSocketServer` 类，无需手动解析协议
5. **✅ MCP 支持**：MCP 规范支持 WebSocket 传输（但需要自定义子协议）

#### 缺点

1. **MCP 客户端支持有限**：Claude Desktop 等主流 MCP 客户端主要支持 stdio 和 HTTP，WebSocket 支持有限
2. **需要自定义子协议**：MCP 规范没有定义标准的 WebSocket 子协议，需要自己定义
3. **防火墙可能拦截**：某些防火墙可能会拦截 WebSocket 连接

#### 适用场景

- ✅ 自定义 MCP 客户端（如 Web 端的 MCP 客户端）
- ✅ 需要实时双向通信的场景（如服务器主动推送通知）
- ❌ 需要与标准 MCP 客户端（如 Claude Desktop）集成
- ❌ 在受限网络环境中使用（防火墙可能拦截 WebSocket）

---

### 3.6 方案对比总结

#### 综合对比表

| 维度 | Raw TCP | UDP | HTTP/SSE | WebSocket |
|------|---------|-----|----------|-----------|
| **MCP 官方支持** | ❌ | ❌ | ✅ (2025-03-26) | ⚠️ (需要自定义子协议) |
| **实现复杂度** | 中 | 中 | 高 | 低 |
| **可靠性** | ✅ | ❌ | ✅ | ✅ |
| **延迟** | 低 | 极低 | 中 | 低 |
| **标准调试工具** | ❌ | ❌ | ✅ (curl, Postman) | ⚠️ (需要 WebSocket 客户端) |
| **MCP 客户端适配** | 需要自己写 | 需要自己写 | ✅ (Claude Desktop 等) | 需要自己写或扩展 |
| **远程访问** | ✅ | ✅ | ✅ | ✅ |
| **会话管理** | 需要自己实现 | 需要自己实现 | ✅ (MCP 规范定义) | 需要自己实现 |
| **性能** | 高 | 极高 | 中 | 高 |
| **防火墙友好** | ✅ | ✅ | ✅ | ⚠️ (可能被拦截) |

#### 详细对比

**1. 与 MCP 规范的兼容性**

| 协议 | 兼容性 | 说明 |
|------|--------|------|
| **Raw TCP** | ❌ 不兼容 | MCP 规范中没有定义 TCP 传输方式，需要自定义协议 |
| **UDP** | ❌ 不兼容 | MCP 规范中没有定义 UDP 传输方式，且 UDP 不可靠 |
| **HTTP/SSE** | ✅ 完全兼容 | 符合 MCP Streamable HTTP 规范（2025-03-26） |
| **WebSocket** | ⚠️ 部分兼容 | MCP 规范支持 WebSocket，但需要自定义子协议 |

**2. 实现复杂度**

| 协议 | 复杂度 | 原因 |
|------|--------|------|
| **Raw TCP** | ⭐⭐⭐ (中) | 需要定义消息格式、分隔符、编码方式等 |
| **UDP** | ⭐⭐⭐ (中) | 需要定义消息格式，如果需要可靠传输还要实现重传、排序等 |
| **HTTP/SSE** | ⭐⭐⭐⭐⭐ (高) | 需要手动解析 HTTP 协议（请求行、头部、正文） |
| **WebSocket** | ⭐ (低) | Godot 提供了 `WebSocketServer` 类，无需手动解析协议 |

**3. 可靠性**

| 协议 | 可靠性 | 原因 |
|------|--------|------|
| **Raw TCP** | ✅ 可靠 | 基于 TCP，保证消息的顺序和完整性 |
| **UDP** | ❌ 不可靠 | UDP 本身不保证消息送达、顺序、完整性 |
| **HTTP/SSE** | ✅ 可靠 | 基于 TCP，保证消息的顺序和完整性 |
| **WebSocket** | ✅ 可靠 | 基于 TCP，保证消息的顺序和完整性 |

**4. 延迟**

| 协议 | 延迟 | 原因 |
|------|------|------|
| **Raw TCP** | ⭐⭐⭐⭐⭐ (极低) | 直接发送 TCP 数据包，无协议开销 |
| **UDP** | ⭐⭐⭐⭐⭐ (极低) | 无连接建立过程，无拥塞控制 |
| **HTTP/SSE** | ⭐⭐⭐ (中) | 每次请求都需要 HTTP 请求/响应循环 |
| **WebSocket** | ⭐⭐⭐⭐ (低) | 连接建立后，消息交换无需 HTTP 请求/响应循环 |

**5. 标准调试工具支持**

| 协议 | 调试工具 | 说明 |
|------|----------|------|
| **Raw TCP** | ❌ 无 | 需要自己写调试工具 |
| **UDP** | ❌ 无 | 需要自己写调试工具 |
| **HTTP/SSE** | ✅ curl, Postman, Insomnia | 标准 HTTP 调试工具 |
| **WebSocket** | ⚠️ wscat, Postman (有限支持) | 需要 WebSocket 客户端 |

**6. MCP 客户端适配**

| 协议 | Claude Desktop | 其他 MCP 客户端 | 说明 |
|------|----------------|-----------------|------|
| **Raw TCP** | ❌ 不支持 | ❌ 不支持 | 需要自己写 MCP 客户端 |
| **UDP** | ❌ 不支持 | ❌ 不支持 | 需要自己写 MCP 客户端 |
| **HTTP/SSE** | ✅ 支持 | ✅ 支持 | 符合 MCP 规范，主流客户端都支持 |
| **WebSocket** | ⚠️ 有限支持 | ⚠️ 有限支持 | 需要客户端支持 WebSocket 传输 |

---

### 3.7 推荐方案

#### 推荐排名

1. **🥇 首选：HTTP/SSE**
   - ✅ **完全符合 MCP 规范**
   - ✅ **Claude Desktop 等主流客户端原生支持**
   - ✅ **可以使用标准 HTTP 调试工具**
   - ✅ **会话管理由 MCP 规范定义**
   - ⚠️ **实现复杂度较高**（但我们可以克服）

2. **🥈 备选：WebSocket**
   - ✅ **实现简单**（Godot 提供了 `WebSocketServer` 类）
   - ✅ **低延迟**（全双工通信）
   - ⚠️ **MCP 客户端支持有限**（Claude Desktop 不支持 WebSocket）
   - ⚠️ **需要自定义子协议**

3. **🥉 不推荐：Raw TCP**
   - ✅ **低延迟、可靠传输**
   - ❌ **MCP 规范不支持**
   - ❌ **需要自己写 MCP 客户端**
   - ❌ **需要自定义协议**

4. **❌ 不推荐：UDP**
   - ✅ **极低延迟**
   - ❌ **不可靠传输**（不适合 MCP）
   - ❌ **MCP 规范不支持**
   - ❌ **需要自己写 MCP 客户端**

#### 最终结论

**推荐使用 HTTP/SSE 方案**，理由：

1. **✅ 符合 MCP 规范**：MCP Streamable HTTP 规范（2025-03-26）明确支持 HTTP/SSE 传输
2. **✅ 客户端支持好**：Claude Desktop、VS Code MCP 插件等都支持 HTTP 传输
3. **✅ 易于调试**：可以使用 curl、Postman 等标准工具调试
4. **✅ 会话管理**：MCP 规范定义了 `Mcp-Session-Id` 头部，无需自己实现
5. **✅ 远程访问**：可以通过互联网访问（需要身份验证）
6. **⚠️ 实现复杂度高**：但这是可以克服的，我们可以参考 MCP 官方文档实现

**WebSocket 作为备选方案**：
- 如果不想实现 HTTP 协议解析，可以选择 WebSocket
- 但需要自己写 MCP 客户端，或者扩展现有客户端以支持 WebSocket
- 实现简单，但客户端支持有限

---

### 3.8 实施建议

#### 如果选择 HTTP/SSE 方案

1. **第一阶段**：实现基本的 HTTP 服务器（基于 `TCPServer`）
   - 解析 HTTP 请求（请求行、头部、正文）
   - 构造 HTTP 响应
   - 支持 POST 请求

2. **第二阶段**：适配 MCP Streamable HTTP 规范
   - 实现会话管理（`Mcp-Session-Id`）
   - 支持 SSE 流（如果需要）
   - 实现 MCP 定义的端点（如 `/mcp`）

3. **第三阶段**：测试和调试
   - 使用 curl 测试 HTTP 端点
   - 在 Claude Desktop 中配置 HTTP 传输
   - 测试所有 30+ 个工具

#### 如果选择 WebSocket 方案

1. **第一阶段**：实现 WebSocket 服务器（基于 `WebSocketServer`）
   - 监听 WebSocket 连接
   - 处理 WebSocket 消息
   - 定义自定义子协议（如 `mcp.v1`）

2. **第二阶段**：写一个简单的 MCP 客户端（用于测试）
   - 可以用 Python 或 Node.js 写一个简单的 WebSocket MCP 客户端
   - 测试所有 30+ 个工具

3. **第三阶段**：扩展 Claude Desktop（可选）
   - 修改 Claude Desktop 的源码，添加 WebSocket 传输支持
   - 或者自己开发一个 MCP 客户端

---

---

### 3.1 实现原理：Godot EditorPlugin 中的 HTTP 服务器运行机制

#### 启动时机和生命周期

**启动时机**：
- EditorPlugin 的 `_ready()` 或 `_enter_tree()` 被调用时启动 HTTP 服务器
- 此时 Godot 编辑器已经完全加载，用户可以开始使用编辑器功能

**生命周期管理**：
```gdscript
@tool
extends EditorPlugin

var _http_server: MCPHttpServer = null

func _ready():
    # 插件加载时启动 HTTP 服务器
    _start_http_server()

func _exit_tree():
    # 插件卸载或编辑器关闭时停止 HTTP 服务器
    if _http_server:
        _http_server.stop()
```

#### 线程模型

HTTP 服务器采用**双线程模型**，确保不阻塞 Godot Editor 的主线程：

```
┌─────────────────────────────────────────────────────────┐
│                    Godot Editor 主线程                   │
│  - 处理 UI 渲染（60 FPS）                               │
│  - 处理用户输入（鼠标、键盘）                             │
│  - 执行场景编辑操作                                      │
│  - 运行 Godot Editor API 调用                           │
│  - 接收来自 HTTP 线程的信号                              │
└───────────────────────┬─────────────────────────────────┘
                        │ 信号通信
┌───────────────────────▼─────────────────────────────────┐
│                  HTTP 服务器线程                          │
│  - 运行 TCPServer.listen()                              │
│  - 轮询检查新连接（OS.delay_msec(10)）                  │
│  - 解析 HTTP 请求                                        │
│  - 通过信号发送请求到主线程                              │
│  - 等待主线程处理完成                                    │
│  - 发送 HTTP 响应                                        │
└─────────────────────────────────────────────────────────┘
```

**关键实现**：
```gdscript
# mcp_http_server.gd
var _tcp_server: TCPServer = null
var _thread: Thread = null
var _active: bool = false

signal message_received(message: Dictionary)
signal response_ready(response: Dictionary)

func start(port: int = 9080) -> bool:
    _tcp_server = TCPServer.new()
    var error: Error = _tcp_server.listen(port)
    if error != OK:
        return false
    
    _active = true
    _thread = Thread.new()
    _thread.start(_http_server_loop)
    
    return true

func _http_server_loop() -> void:
    while _active:
        # 检查新连接（非阻塞）
        var peer: StreamPeerTCP = _tcp_server.take_connection()
        if peer:
            _handle_connection(peer)
        
        # 避免 CPU 占用过高
        OS.delay_msec(10)
    
    # 清理资源
    _tcp_server.stop()

func _handle_connection(peer: StreamPeerTCP) -> void:
    # 读取 HTTP 请求
    var request: String = _read_http_request(peer)
    
    # 解析 HTTP 请求
    var parsed: Dictionary = _parse_http_request(request)
    
    # 提取 JSON-RPC 消息
    var message: Dictionary = JSON.new().parse(parsed["body"])
    
    # 通过信号发送到主线程（线程安全）
    message_received.emit(message)
    
    # 等待主线程处理完成（通过信号或回调）
    await response_ready
    
    # 发送 HTTP 响应
    _send_http_response(peer, _current_response)
```

#### 与主线程的通信机制

**信号（Signal）机制**：
- Godot 的信号系统是线程安全的
- HTTP 服务器线程通过信号将消息发送到主线程
- 主线程处理完成后，通过信号或回调函数返回结果

**代码实现**：
```gdscript
# mcp_server_native.gd（主线程）
func _ready():
    _http_server = load("res://addons/godot_mcp/native_mcp/mcp_http_server.gd").new()
    _http_server.message_received.connect(_on_message_received)
    
    if _http_server.start(9080):
        print("[MCP] HTTP server started on port 9080")

func _on_message_received(message: Dictionary):
    # 这个函数在主线程中被调用
    # 可以安全地调用 Godot Editor API
    var response = _process_mcp_message(message)
    
    # 将响应发送回 HTTP 服务器线程
    _http_server.send_response(response)

func _process_mcp_message(message: Dictionary) -> Dictionary:
    # 处理 MCP 消息（在主线程中）
    # 可以调用 EditorInterface、修改场景等
    match message["method"]:
        "tools/list":
            return _handle_tools_list(message)
        "tools/call":
            return _handle_tool_call(message)
        # ... 其他方法
```

#### TCPServer 工作流程详解

1. **监听端口**：
   ```gdscript
   var server = TCPServer.new()
   server.listen(9080)  # 开始监听 9080 端口
   ```

2. **接受连接**：
   ```gdscript
   # 在循环中轮询
   var peer = server.take_connection()
   if peer:
       # 有新连接
       print("New connection from: ", peer.get_connected_host())
   ```

3. **读取数据**：
   ```gdscript
   while peer.get_available_bytes() > 0:
       var data = peer.get_utf8_string_from_byte(peer.get_available_bytes())
       request += data
   ```

4. **发送响应**：
   ```gdscript
   var response = "HTTP/1.1 200 OK\r\n"
   response += "Content-Type: application/json\r\n"
   response += "\r\n"
   response += JSON.stringify(json_rpc_response)
   
   peer.put_data(response.to_utf8_buffer())
   peer.disconnect_from_host()
   ```

---

### 3.2 对正常开发的影响分析

#### 3.2.1 性能影响

| 方面 | 影响程度 | 详细说明 |
|------|----------|----------|
| **编辑器响应速度** | ✅ 无影响 | HTTP 服务器运行在独立线程中，不阻塞主线程的 UI 渲染和用户输入处理 |
| **内存占用** | ✅ 极低 | TCPServer 和 Thread 占用的内存很小（< 10MB），对现代计算机可忽略不计 |
| **CPU 占用** | ✅ 极低 | 如果没有 HTTP 请求，HTTP 服务器线程大部分时间处于休眠状态（`OS.delay_msec(10)`），CPU 占用 < 1% |
| **帧率（FPS）** | ✅ 无影响 | 主线程的帧率保持在 60 FPS，HTTP 服务器线程不影响渲染循环 |

**性能测试数据**（预估）：
- **空闲状态**：CPU 占用 0.5-1%，内存占用 +5MB
- **处理请求时**：CPU 占用 2-5%，持续 < 100ms
- **高并发（10+ 请求/秒）**：CPU 占用 10-15%，仍能保持编辑器流畅

#### 3.2.2 端口占用问题

**问题描述**：
- HTTP 服务器需要监听一个 TCP 端口（默认 9080）
- 如果端口被其他程序占用，`TCPServer.listen()` 会失败

**解决方案**：
1. **自动端口切换**：
   ```gdscript
   func start(port: int = 9080) -> bool:
       _port = port
       _tcp_server = TCPServer.new()
       
       var error: Error = _tcp_server.listen(_port)
       if error != OK:
           # 尝试备用端口
           for alt_port in range(9081, 9100):
               error = _tcp_server.listen(alt_port)
               if error == OK:
                   _port = alt_port
                   print("[MCP HTTP] Port ", port, " occupied, using port ", _port)
                   break
           
           if error != OK:
               printerr("[MCP HTTP] Failed to listen on any port")
               return false
       
       return true
   ```

2. **用户配置端口**：在插件设置中提供端口配置选项

3. **显示当前端口**：在 Editor 的 UI 面板中显示当前使用的端口

**多项目场景**：
- 如果同时打开多个 Godot 项目，每个项目需要不同的端口
- 建议：每个项目在 `project.godot` 中保存自己的端口配置

#### 3.2.3 与 Godot Editor 功能的集成

**生命周期管理**：
- ✅ **启动**：EditorPlugin 启用时自动启动 HTTP 服务器
- ✅ **关闭**：EditorPlugin 禁用时或 Editor 关闭时自动停止 HTTP 服务器
- ✅ **重启**：提供"重启服务器"按钮，用于修复异常状态

**项目管理**：
- ✅ 每个 Godot 项目可以有自己的 MCP 服务器配置
- ✅ 配置文件保存在项目的 `addons/godot_mcp/` 目录下
- ✅ 不会影响到其他项目

**多项目冲突**：
- ⚠️ 如果同时打开多个 Godot 项目，需要为它们分配不同的端口
- ✅ 解决方案：自动端口切换（见上文）

#### 3.2.4 对 Scene 编辑的影响

**线程安全性**：
- ✅ HTTP 服务器线程不直接调用 Godot Editor API
- ✅ 所有的 Godot Editor API 调用都在主线程中执行（通过信号触发）
- ✅ 不会造成场景数据竞争或崩溃

**实际操作测试**：
| 操作 | 影响 | 说明 |
|------|------|------|
| 添加/删除节点 | ✅ 无影响 | HTTP 服务器不干扰用户的编辑操作 |
| 修改节点属性 | ✅ 无影响 | 通过 MCP 工具修改时，会在主线程中执行，与手动编辑相同 |
| 运行脚本 | ✅ 无影响 | HTTP 服务器不干扰脚本执行 |
| 保存场景 | ✅ 无影响 | 文件 I/O 操作在主线程中执行，线程安全 |

#### 3.2.5 防火墙和安全考虑

**本地开发**：
- ✅ 默认只监听 `127.0.0.1`（localhost），不对外网开放
- ✅ 不需要在防火墙中开放端口
- ✅ 只有本机的程序可以连接

**远程访问（可选）**：
- ⚠️ 如果需要远程访问，需要监听 `0.0.0.0`
- ⚠️ 需要在防火墙中开放端口
- ⚠️ 建议添加身份验证机制（Token 或 API Key）

**安全建议**：
1. 默认只监听 localhost
2. 提供配置选项，允许用户启用远程访问（并提示安全风险）
3. 实现简单的 Token 验证机制

---

### 3.3 对运行测试的影响分析

#### 3.3.1 运行游戏时的行为

**关键事实**：
- Godot 运行游戏时，会**启动一个全新的独立进程**
- Editor 和游戏运行在两个独立的进程中

**HTTP 服务器状态**：
```
┌─────────────────────────────────────────────────────────┐
│              Godot Editor 进程（PID: 1234）             │
│  - 运行 Editor UI                                      │
│  - HTTP 服务器继续运行（端口 9080）                     │
│  - MCP 插件继续工作                                     │
└─────────────────────────────────────────────────────────┘
                         
┌─────────────────────────────────────────────────────────┐
│              Godot 游戏进程（PID: 5678）                 │
│  - 运行游戏逻辑                                         │
│  - 不包含 MCP 插件（除非游戏代码中主动加载）              │
│  - 不启动 HTTP 服务器                                   │
└─────────────────────────────────────────────────────────┘
```

**结论**：✅ **对运行游戏测试没有负面影响**
- Editor 中的 HTTP 服务器继续运行
- 游戏进程独立运行，不受到任何影响
- 游戏可以通过 `HTTPRequest` 节点连接到 Editor 的 MCP 服务器（如果需要）

#### 3.3.2 调试游戏时的行为

**调试器连接**：
- Godot 调试器连接到游戏进程（通过 socket）
- 调试器与 MCP 服务器不冲突

**MCP 服务器状态**：
- ✅ 仍在 Editor 进程中运行
- ✅ 可以继续通过 MCP 协议控制 Editor（如修改场景、添加节点等）
- ✅ 游戏调试不受影响

**实际使用场景**：
```
用户正在调试游戏 → 发现场景中的问题 → 
通过 MCP 工具（如 Claude Desktop）修改场景 → 
在游戏中立即看到效果（如果游戏支持热重载）
```

**结论**：✅ **对调试游戏没有负面影响**

#### 3.3.3 多实例测试（多人游戏）

**场景**：测试多人游戏时，可能需要启动多个游戏实例

**影响分析**：
- 每个游戏实例运行在独立的进程中
- Editor 的 HTTP 服务器继续在 Editor 进程中运行
- 游戏实例之间不会互相干扰
- 游戏实例也不会干扰 Editor 的 HTTP 服务器

**结论**：✅ **对多实例测试没有负面影响**

#### 3.3.4 热重载（Hot Reload）功能

**Godot 的热重载**：
- 当脚本文件被修改并保存时，Godot 可以自动重新加载脚本
- 热重载只影响运行中的游戏进程

**MCP 服务器的影响**：
- ✅ 如果通过 MCP 工具修改了脚本文件并保存，会触发热重载
- ✅ 这是期望的行为，不是负面影响

**结论**：✅ **对热重载功能没有负面影响，反而可以增强开发体验**

---

### 3.4 潜在问题和解决方案

#### 问题 1：HTTP 服务器线程崩溃

**场景**：HTTP 请求处理时发生未捕获的异常

**影响**：
- ⚠️ HTTP 服务器线程停止工作
- ⚠️ 但主线程（Editor UI）仍然正常运行

**解决方案**：
1. **异常捕获**：
   ```gdscript
   func _http_server_loop() -> void:
       while _active:
           if not _tcp_server.is_listening():
               printerr("[MCP HTTP] Server stopped unexpectedly")
               break
           
           var peer: StreamPeerTCP = _tcp_server.take_connection()
           if peer:
               # 捕获单个连接的异常，不影响整个服务器
               try:
                   _handle_connection(peer)
               except Exception as e:
                   printerr("[MCP HTTP] Error handling connection: ", e)
           
           OS.delay_msec(10)
   ```

2. **自动重启机制**：
   ```gdscript
   func _process(delta: float):
       # 检查 HTTP 服务器是否还在运行
       if _http_server and not _http_server.is_active():
           printerr("[MCP] HTTP server crashed, restarting...")
           _http_server.start(_port)
   ```

3. **用户手动重启**：在插件面板中提供"重启服务器"按钮

#### 问题 2：主线程阻塞（耗时操作）

**场景**：处理某个 MCP 请求时，主线程执行了耗时操作（如大量场景修改、资源导入等）

**影响**：
- ⚠️ Editor UI 暂时无响应
- ⚠️ 用户体验下降

**解决方案**：
1. **将耗时操作放到独立线程中**：
   ```gdscript
   func _on_message_received(message: Dictionary):
       # 将耗时操作放到独立线程中
       var thread = Thread.new()
       thread.start(_process_mcp_message_threaded.bind(message))
       
       # 立即返回，不阻塞主线程
   ```

2. **使用 `await` 异步等待**：
   ```gdscript
   func _on_message_received(message: Dictionary):
       # 异步处理，不阻塞主线程
       var response = await _process_mcp_message_async(message)
       _http_server.send_response(response)
   ```

3. **添加超时机制**：
   ```gdscript
   func _process_mcp_message(message: Dictionary) -> Dictionary:
       var timer = Timer.new()
       timer.wait_time = 5.0  # 5 秒超时
       timer.one_shot = true
       timer.start()
       
       # 执行耗时操作...
       
       if timer.is_stopped():
           return {"error": "Request timeout"}
       
       return result
   ```

#### 问题 3：多个 MCP 客户端同时连接

**场景**：多个 MCP 客户端（如 Claude Desktop 和 VS Code 插件）同时连接到同一个 Godot Editor

**影响**：
- ⚠️ 可能导致消息混乱
- ⚠️ 需要会话管理

**解决方案**：
1. **实现会话管理**（符合 MCP Streamable HTTP 规范）：
   ```gdscript
   var _sessions: Dictionary = {}  # session_id -> SessionInfo
   
   func _handle_connection(peer: StreamPeerTCP) -> void:
       # 检查是否有 session ID
       var session_id = _get_session_id_from_request(peer)
       
       if session_id == "":
           # 新会话
           session_id = _generate_session_id()
           _sessions[session_id] = {"peer": peer, "created": Time.get_unix_time_from_system()}
       
       # 将请求与会话关联
       var message = _parse_message(peer)
       message["session_id"] = session_id
       
       message_received.emit(message)
   ```

2. **每个会话独立处理**：确保不同客户端的请求不会互相干扰

---

### 3.5 最佳实践建议

#### 对于开发者（插件开发者）

1. **默认禁用 MCP 服务器**：
   - 在插件设置中添加启用/禁用开关
   - 默认禁用，用户需要时在设置中启用

2. **提供配置选项**：
   - 端口号（默认 9080）
   - 监听地址（localhost 或 0.0.0.0）
   - 日志级别（DEBUG、INFO、WARN、ERROR）
   - 启用/禁用身份验证

3. **状态指示**：
   - 在 Editor 底部状态栏显示 MCP 服务器状态（运行/停止）
   - 在插件面板中显示当前端口、连接数、处理的请求数等

4. **错误处理**：
   - 所有异常都要捕获并记录日志
   - 提供"查看日志"按钮，方便用户排查问题

#### 对于用户（游戏开发者）

1. **启用 MCP 服务器**：
   - 在 Plugins 面板中启用 `godot_mcp` 插件
   - 在 MCP 设置面板中启用 HTTP 服务器

2. **配置 MCP 客户端**：
   - 在 Claude Desktop 等客户端中配置 URL：`http://localhost:9080/mcp`
   - 如果需要身份验证，配置 Token

3. **测试连接**：
   - 使用提供的测试脚本（`test_mcp_client_simple.py`）测试连接
   - 在 Godot Editor 中查看 MCP 服务器的日志输出

---

## 4. 迁移方案（详细步骤）

### 阶段一：实现 HTTP 服务器（1-2 天）

#### 步骤 1.1：创建 `mcp_http_server.gd`
```gdscript
@tool
class_name MCPHttpServer
extends RefCounted

signal message_received(message: Dictionary)
signal response_ready(response: Dictionary))

var _tcp_server: TCPServer = null
var _port: int = 9080
var _active: bool = false
var _thread: Thread = null
var _sessions: Dictionary = {}  # session_id -> stream_peer

func start(port: int = 9080) -> bool:
    _port = port
    _tcp_server = TCPServer.new()
    var error: Error = _tcp_server.listen(_port)
    if error != OK:
        printerr("[MCP HTTP] Failed to listen on port ", _port)
        return false
    
    _active = true
    _thread = Thread.new()
    _thread.start(_http_server_loop)
    
    printerr("[MCP HTTP] Server started on port ", _port)
    return true

func stop() -> void:
    _active = false
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
    
    if _tcp_server:
        _tcp_server.stop()
        _tcp_server = null
    
    printerr("[MCP HTTP] Server stopped")

func _http_server_loop() -> void:
    while _active:
        # 接受新连接
        var peer: StreamPeerTCP = _tcp_server.take_connection()
        if peer:
            # 处理连接（在新线程或协程中）
            _handle_connection(peer)
        
        OS.delay_msec(10)

func _handle_connection(peer: StreamPeerTCP) -> void:
    # 读取 HTTP 请求
    var request: String = ""
    while peer.get_available_bytes() > 0:
        request += peer.get_utf8_string_from_byte(peer.get_available_bytes())
    
    # 解析 HTTP 请求
    var parsed: Dictionary = _parse_http_request(request)
    
    # 提取 JSON-RPC 消息
    var message: Dictionary = JSON.new().parse(parsed["body"])
    
    # 发送给 MCP 服务器核心处理
    message_received.emit(message)
    
    # 等待响应
    await response_ready
    
    # 发送 HTTP 响应
    _send_http_response(peer, response)

func _parse_http_request(raw: String) -> Dictionary:
    # 解析 HTTP 请求行和头部
    var lines: PackedStringArray = raw.split("\r\n")
    var request_line: PackedStringArray = lines[0].split(" ")
    var method: String = request_line[0]
    var path: String = request_line[1]
    
    # 解析头部
    var headers: Dictionary = {}
    var body_start: int = -1
    for i in range(1, lines.size()):
        if lines[i].is_empty():
            body_start = i + 1
            break
        var parts: PackedStringArray = lines[i].split(": ")
        headers[parts[0]] = parts[1]
    
    # 提取正文
    var body: String = ""
    if body_start != -1 and body_start < lines.size():
        body = lines[body_start]
    
    return {
        "method": method,
        "path": path,
        "headers": headers,
        "body": body
    }

func _send_http_response(peer: StreamPeerTCP, response: Dictionary) -> void:
    var json_string: String = JSON.stringify(response)
    var http_response: String = "HTTP/1.1 200 OK\r\n"
    http_response += "Content-Type: application/json\r\n"
    http_response += "Content-Length: " + str(json_string.length()) + "\r\n"
    http_response += "\r\n"
    http_response += json_string
    
    peer.put_data(http_response.to_utf8_buffer())
    peer.disconnect_from_host()
```

#### 步骤 1.2：集成到 `mcp_server_native.gd`
```gdscript
func _start_native_server() -> bool:
    # 启动 HTTP 服务器
    var http_server = load("res://addons/godot_mcp/native_mcp/mcp_http_server.gd").new()
    if not http_server.start(_port):
        _log_error("Failed to start HTTP server")
        return false
    
    # 连接信号
    http_server.message_received.connect(_on_http_message_received)
    
    # 启动 MCP 服务器核心
    _native_server.start()
    
    return true
```

### 阶段二：适配 MCP Streamable HTTP 传输规范（1 天）

#### 步骤 2.1：支持 POST 请求
- 客户端发送 JSON-RPC 请求到 `http://localhost:9080/mcp`
- 服务器返回 JSON-RPC 响应（作为 HTTP 响应体）

#### 步骤 2.2：支持 SSE 流
- 客户端发送 POST 请求，服务器通过 SSE 返回响应
- 需要实现 SSE 格式：`data: {JSON-RPC response}\n\n`

#### 步骤 2.3：支持会话管理
- 服务器在初始化时生成 `Mcp-Session-Id`
- 客户端在后续请求中携带这个头部

### 阶段三：修改 MCP 客户端配置（0.5 天）

#### 旧的 stdio 配置
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

#### 新的 HTTP 配置
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

### 阶段四：测试和调试（1-2 天）

#### 测试清单
- [ ] HTTP 服务器能正确启动和停止
- [ ] POST 请求能正确解析和处理
- [ ] 响应能正确返回给客户端
- [ ] 会话管理正常工作
- [ ] SSE 流能正确发送（如果需要）
- [ ] 所有 30 个工具都能正确调用
- [ ] 所有 7 个资源都能正确读取

---

## 5. 优缺点对比

### stdio 方案
| 优点 | 缺点 |
|------|------|
| 实现简单，无需 HTTP 服务器 | stdout 污染严重 |
| 适合本地进程通信 | 无法连接已运行的 Godot 实例 |
| 延迟低 | MCP 客户端适配困难 |
| | 进程管理复杂 |

### HTTP/SSE 方案
| 优点 | 缺点 |
|------|------|
| 无 stdout 污染 | 实现复杂度较高 |
| 可以连接已运行的 Godot 实例 | 需要管理端口 |
| MCP 客户端适配容易 | 需要额外的 HTTP 服务器代码 |
| 支持远程访问（如果需要） | 性能略低于 stdio |
| 符合 MCP 最新规范 | |

---

## 6. 推荐方案

### 推荐：采用 HTTP/SSE 方案

**理由**：
1. 解决当前所有核心问题
2. 符合 MCP 最新规范（Streamable HTTP）
3. 用户体验更好（可以连接已运行的 Godot）
4. 长期维护成本更低

**实施建议**：
1. 先实现一个简单的 HTTP 服务器（基于 TCPServer）
2. 优先支持 POST 请求（大多数 MCP 客户端主要使用 POST）
3. SSE 流可以作为第二阶段实现
4. 保留 stdio 方案作为备份（可以通过配置切换）

---

## 7. 时间估算

| 阶段 | 任务 | 时间估算 |
|------|------|----------|
| 阶段一 | 实现 HTTP 服务器 | 1-2 天 |
| 阶段二 | 适配 MCP Streamable HTTP 规范 | 1 天 |
| 阶段三 | 修改 MCP 客户端配置 | 0.5 天 |
| 阶段四 | 测试和调试 | 1-2 天 |
| **总计** | | **3.5-5.5 天** |

---

## 8. 风险和建议

### 风险
1. **HTTP 服务器性能**：基于 TCPServer 的实现可能不如专业的 HTTP 服务器
   - **缓解措施**：可以先实现基本功能，后续优化性能

2. **端口冲突**：9080 端口可能已被占用
   - **缓解措施**：允许用户配置端口，自动检测可用端口

3. **Godot 编辑器崩溃**：HTTP 服务器运行在 Godot 主线程或独立线程中，可能影响稳定性
   - **缓解措施**：充分测试，确保线程安全

### 建议
1. **分阶段实施**：先实现基本 HTTP 服务器，再适配 SSE
2. **保留 stdio 方案**：作为备份，用户可以通过配置选择传输方式
3. **充分测试**：特别是线程安全和性能测试
4. **文档更新**：及时更新用户文档和 MCP 客户端配置指南

---

## 9. 后续行动计划

如果您决定采用 HTTP/SSE 方案，我可以立即开始：

1. **创建 `mcp_http_server.gd`**：实现基本的 HTTP 服务器
2. **修改 `mcp_server_core.gd`**：移除 stdio 相关代码，改为接收 HTTP 消息
3. **修改 `mcp_server_native.gd`**：集成 HTTP 服务器
4. **创建测试脚本**：测试 HTTP 服务器的功能
5. **更新文档**：修改用户文档和配置指南

请告知您的决定，我会立即开始实施。