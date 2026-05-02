# Godot-MCP 双传输模式迁移计划

**日期**: 2026-05-02  
**作者**: AI Assistant  
**目标**: 将现有 stdio 传输方案扩展为支持 stdio 和 HTTP/SSE 双模式

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

### 1.3 传输方式对比

| 特性 | stdio | HTTP/SSE |
|------|-------|----------|
| 连接方式 | 子进程 + stdin/stdout | TCP/HTTP |
| 适用场景 | 本地开发、简单部署 | 生产环境、远程访问 |
| 客户端适配 | 需要支持 stdio | 标准 HTTP，适配性好 |
| 调试难度 | 较难（日志混在一起） | 容易（可用 curl/Postman） |
| 性能 | 高（无网络开销） | 中（有网络开销，但很小） |
| 并发支持 | 不支持 | 支持 |
| 推荐场景 | 开发测试 | 生产部署 |

**建议**：
- 开发阶段：使用 stdio 模式（简单、快速）
- 生产环境：使用 HTTP 模式（稳定、易维护）

---

## 2. 需要创建的文件

### 2.1 核心文件

| 文件路径 | 说明 | 优先级 |
|----------|------|----------|
| `addons/godot_mcp/native_mcp/mcp_transport_base.gd` | 传输层基类（定义统一接口） | 🔴 高 |
| `addons/godot_mcp/native_mcp/mcp_stdio_server.gd` | stdio 传输实现（从 core 中提取） | 🔴 高 |
| `addons/godot_mcp/native_mcp/mcp_http_server.gd` | HTTP 服务器实现（基于 TCPServer） | 🔴 高 |
| `addons/godot_mcp/native_mcp/mcp_sse_stream.gd` | SSE 流管理器（可选，第二阶段） | 🟡 中 |
| `addons/godot_mcp/native_mcp/mcp_session_manager.gd` | 会话管理器（Mcp-Session-Id） | 🟡 中 |

### 2.2 测试文件

| 文件路径 | 说明 | 优先级 |
|----------|------|----------|
| `test/http/test_mcp_http_server.py` | Python 测试脚本（HTTP 模式） | 🔴 高 |
| `test/stdio/test_mcp_stdio.py` | Python 测试脚本（stdio 模式） | 🔴 高 |
| `test/http/test_mcp_http_client.js` | Node.js 测试脚本 | 🟡 中 |
| `test/http/curl_examples.sh` | curl 测试示例（Bash） | 🟢 低 |

### 2.3 配置文件

| 文件路径 | 说明 | 优先级 |
|----------|------|----------|
| `docs/configuration/mcp-stdio-config-example.json` | stdio 模式配置示例 | 🔴 高 |
| `docs/configuration/mcp-http-config-example.json` | HTTP 模式配置示例 | 🔴 高 |
| `addons/godot_mcp/native_mcp/default_config.json` | 默认配置文件（传输方式、端口等） | 🟡 中 |

---

## 3. 需要修改的文件

### 3.1 核心文件修改

#### 3.1.1 `addons/godot_mcp/native_mcp/mcp_server_core.gd`

**修改内容**：

1. **提取 stdio 相关代码到 `mcp_stdio_server.gd`**：
   - 保留原有的 `_stdin_listen_loop()` 函数 - 将移动到 `mcp_stdio_server.gd`
   - 保留原有的 `_parse_and_queue_message()` 函数 - 将移动到 `mcp_stdio_server.gd`
   - 保留原有的 `_process_next_message()` 函数 - 将移动到 `mcp_stdio_server.gd`
   - 保留原有的 `start()` 函数中的 Thread 创建和 stdin 监听逻辑 - 将移动到 `mcp_stdio_server.gd`
   - 保留原有的 `stop()` 函数中的 Thread 清理逻辑 - 将移动到 `mcp_stdio_server.gd`

2. **添加新的变量**：
   ```gdscript
   # 传输方式枚举
   enum TransportType {
       TRANSPORT_STDIO,    # stdio 传输（默认）
       TRANSPORT_HTTP      # HTTP 传输
   }
   
   var _transport_type: TransportType = TransportType.TRANSPORT_STDIO
   var _transport: RefCounted = null  # 传输层实例（McpTransportBase）
   ```

3. **添加传输层接口方法**（详见完整文档中的代码实现）

4. **修改 `start()` 和 `stop()` 函数**（详见完整文档中的代码实现）

5. **保持不动的部分**：
   - 所有 MCP 协议处理方法（`_handle_initialize()`, `_handle_tools_list()`, 等）
   - 工具注册和资源注册相关方法
   - 速率限制和缓存机制
   - 日志方法

#### 3.1.2 `addons/godot_mcp/mcp_server_native.gd`

**修改内容**：

1. **添加新的配置选项**：
   ```gdscript
   @export var transport_mode: String = "stdio":
       set(value):
           if value == "stdio" or value == "http":
               transport_mode = value
               if _native_server:
                   var type = McpServerCore.TransportType.TRANSPORT_STDIO if value == "stdio" \
                       else McpServerCore.TransportType.TRANSPORT_HTTP
                   _native_server.set_transport_type(type)
               notify_property_list_changed()
           else:
               _log_error("Invalid transport mode: " + value + ". Use 'stdio' or 'http'")
   
   @export var http_port: int = 9080:
       set(value):
           http_port = value
           if _native_server and _native_server.has_method("set_http_port"):
               _native_server.set_http_port(value)
           notify_property_list_changed()
   ```

2. **修改 `_enter_tree()` 函数**：根据 `transport_mode` 设置传输方式

3. **修改 `_start_native_server()` 和 `_stop_native_server()` 函数**：支持多种传输方式

#### 3.1.3 `addons/godot_mcp/ui/mcp_panel_native.gd`

**修改内容**：

1. **更新 UI 显示**：
   - 添加传输方式选择下拉框（stdio / http）
   - 根据传输方式显示不同的状态信息
   - 添加端口设置输入框（仅 HTTP 模式）

2. **添加新的信号连接**：
   - 连接传输方式切换信号
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

**HTTP 模式配置**（`claude_desktop_config.json`）：
```json
{
  "mcpServers": {
    "godot-mcp-http": {
      "url": "http://localhost:9080/mcp"
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
```

---

## 4. 详细迁移步骤

### 阶段一：创建传输层基类（0.5 天）

#### 步骤 1.1：创建 `mcp_transport_base.gd`

**文件路径**：`addons/godot_mcp/native_mcp/mcp_transport_base.gd`

**功能**：定义传输层的统一接口，所有传输方式都继承此类

**核心接口**：
```gdscript
class_name McpTransportBase
extends RefCounted

# 信号定义
signal message_received(message: Dictionary, context: Variant)
signal server_error(error: String)
signal server_started()
signal server_stopped()

# 虚方法（子类必须实现）
func start() -> bool:
    push_error("McpTransportBase.start() must be overridden")
    return false

func stop() -> void:
    push_error("McpTransportBase.stop() must be overridden")

func is_running() -> bool:
    push_error("McpTransportBase.is_running() must be overridden")
    return false
```

---

### 阶段二：提取 stdio 传输实现（1 天）

#### 步骤 2.1：创建 `mcp_stdio_server.gd`

**文件路径**：`addons/godot_mcp/native_mcp/mcp_stdio_server.gd`

**功能**：从 `mcp_server_core.gd` 中提取 stdio 相关代码

**核心实现**：
```gdscript
class_name McpStdioServer
extends McpTransportBase

var _thread: Thread = null
var _active: bool = false
var _message_queue: Array = []
var _stdin_pipe = null  # Windows: Pipe, Unix: File

func start() -> bool:
    _active = true
    _thread = Thread.new()
    _thread.start(_stdin_listen_loop)
    server_started.emit()
    return true

func stop() -> void:
    _active = false
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
    server_stopped.emit()

func is_running() -> bool:
    return _active

func _stdin_listen_loop() -> void:
    # 从 stdin 读取数据（原有代码）
    while _active:
        # ... 读取 stdin ...
        # ... 解析消息 ...
        # ... 发送到消息队列 ...
        OS.delay_msec(10)

func _parse_and_queue_message(line: String) -> void:
    # 解析 JSON-RPC 消息（原有代码）
    var json = JSON.new()
    var error: Error = json.parse(line)
    
    if error != OK:
        printerr("Failed to parse stdin message: ", json.get_error_message())
        return
    
    var message: Dictionary = json.get_data()
    _message_queue.append(message)
    
    # 发送信号
    message_received.emit(message, null)  # context 为 null（stdio 不需要）
```

---

### 阶段三：创建 HTTP 传输实现（1-2 天）

#### 步骤 3.1：创建 `mcp_http_server.gd`

**文件路径**：`addons/godot_mcp/native_mcp/mcp_http_server.gd`

**功能**：实现 HTTP 服务器，支持 JSON-RPC over HTTP

**核心实现**（详见原文档中的完整代码）：
- HTTP 服务器主循环（基于 TCPServer）
- HTTP 请求解析
- JSON-RPC 消息提取
- HTTP 响应构建
- SSE 支持（可选）

---

### 阶段四：修改 `mcp_server_core.gd`（1 天）

#### 步骤 4.1：提取 stdio 代码

1. 将 stdio 相关函数复制到 `mcp_stdio_server.gd`
2. 在 `mcp_server_core.gd` 中添加传输层支持
3. 修改 `start()` 和 `stop()` 函数

#### 步骤 4.2：添加传输方式切换

```gdscript
# 在 mcp_server_core.gd 中添加

var _transport_type: TransportType = TransportType.TRANSPORT_STDIO
var _transport: McpTransportBase = null

func set_transport_type(type: TransportType) -> void:
    if _active:
        _log_error("Cannot change transport type while server is running")
        return
    _transport_type = type

func _init_transport() -> bool:
    match _transport_type:
        TransportType.TRANSPORT_STDIO:
            _transport = McpStdioServer.new()
        TransportType.TRANSPORT_HTTP:
            _transport = McpHttpServer.new()
        _:
            _log_error("Unknown transport type")
            return false
    
    # 连接信号
    _transport.message_received.connect(_on_transport_message_received)
    _transport.server_error.connect(_on_transport_error)
    
    return true

func _on_transport_message_received(message: Dictionary, context: Variant) -> void:
    # 处理来自传输层的消息
    # context: stdio 为 null，HTTP 为 StreamPeerTCP
    
    # 验证消息格式
    if not message.has("jsonrpc"):
        _send_error(null, MCPTypes.ERROR_INVALID_REQUEST, "Missing jsonrpc field", context)
        return
    
    # ... 处理请求 ...
    
    # 发送响应
    if response:
        _send_response(response, context)

func _send_response(response: Dictionary, context: Variant) -> void:
    if _transport_type == TransportType.TRANSPORT_STDIO:
        # stdio 模式：直接输出到 stdout
        print(JSON.stringify(response))
    elif _transport_type == TransportType.TRANSPORT_HTTP:
        # HTTP 模式：通过 HTTP 服务器发送响应
        if _transport and _transport.has_method("send_response"):
            _transport.send_response(response, context)
```

---

### 阶段五：修改 `mcp_server_native.gd`（0.5 天）

#### 步骤 5.1：添加传输方式配置

1. 添加 `transport_mode` 导出变量
2. 修改 `_enter_tree()` 设置传输方式
3. 修改 `_start_native_server()` 和 `_stop_native_server()`

---

### 阶段六：创建测试脚本（1 天）

#### 步骤 6.1：创建 stdio 模式测试脚本

**文件路径**：`test/stdio/test_mcp_stdio.py`

```python
#!/usr/bin/env python3
"""
测试 Godot-MCP stdio 传输模式
"""

import subprocess
import json
import sys
import time

GODOT_PATH = "path/to/godot.exe"
PROJECT_PATH = "path/to/project.godot"

def test_stdio():
    """测试 stdio 传输"""
    print("Starting Godot with MCP plugin (stdio mode)...")
    
    # 启动 Godot 进程
    process = subprocess.Popen(
        [GODOT_PATH, "--headless", "--script", "res://addons/godot_mcp/mcp_server_native.gd"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    # 发送 initialize 请求
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "test", "version": "1.0"}
        }
    }
    
    print("Sending request:", json.dumps(request))
    process.stdin.write(json.dumps(request) + "\n")
    process.stdin.flush()
    
    # 读取响应
    response_line = process.stdout.readline()
    print("Received response:", response_line)
    
    # 解析响应
    response = json.loads(response_line)
    
    if "result" in response:
        print("✅ stdio test passed")
    else:
        print("❌ stdio test failed")
    
    # 终止进程
    process.terminate()

if __name__ == "__main__":
    test_stdio()
```

#### 步骤 6.2：创建 HTTP 模式测试脚本

**文件路径**：`test/http/test_mcp_http_server.py`

（详见原文档中的完整代码）

---

### 阶段七：更新文档和配置（0.5 天）

#### 步骤 7.1：创建配置示例文档

1. `docs/configuration/mcp-stdio-config-example.json`
2. `docs/configuration/mcp-http-config-example.json`

#### 步骤 7.2：更新 README.md

添加双传输模式的说明：

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
5. 启动服务器

**客户端配置**：
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```
```

---

### 阶段八：完整测试流程（1-2 天）

#### 8.1 stdio 模式测试

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

#### 8.2 HTTP 模式测试

**测试 3：启动和停止**
1. 设置 `transport_mode = "http"`
2. 启动服务器
3. 检查 HTTP 服务器是否监听端口
4. 停止服务器

**测试 4：MCP 协议（HTTP）**
```bash
python test/http/test_mcp_http_server.py
```

**预期结果**：所有测试通过 ✅

**测试 5：使用 curl**
```bash
bash test/http/curl_examples.sh
```

**预期结果**：所有请求成功 ✅

#### 8.3 切换测试

**测试 6：动态切换传输方式**
1. 启动服务器（stdio 模式）
2. 停止服务器
3. 修改配置为 HTTP 模式
4. 重新启动服务器
5. 验证 HTTP 服务器正常运行

**预期结果**：切换成功 ✅

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
   ```
4. 重新启动 Godot Editor
5. 使用旧的 stdio 配置

---

## 6. 时间估算

| 阶段 | 任务 | 时间估算 | 负责人 |
|------|------|----------|--------|
| 阶段一 | 创建 `mcp_transport_base.gd` | 0.5 天 | AI Assistant |
| 阶段二 | 创建 `mcp_stdio_server.gd` | 1 天 | AI Assistant |
| 阶段三 | 创建 `mcp_http_server.gd` | 1-2 天 | AI Assistant |
| 阶段四 | 修改 `mcp_server_core.gd` | 1 天 | AI Assistant |
| 阶段五 | 修改 `mcp_server_native.gd` | 0.5 天 | AI Assistant |
| 阶段六 | 创建测试脚本 | 1 天 | AI Assistant |
| 阶段七 | 更新文档和配置 | 0.5 天 | AI Assistant |
| 阶段八 | 完整测试流程 | 1-2 天 | AI Assistant + 用户 |
| **总计** | | **6.5-9.5 天** | |

---

## 7. 后续优化（可选）

### 7.1 实现 SSE 流

**目标**：支持服务器主动推送消息到客户端

### 7.2 实现会话管理

**目标**：支持多个 MCP 客户端同时连接

### 7.3 支持远程访问

**目标**：允许从其他计算机访问 Godot-MCP 服务器

---

## 8. 附录：完整文件列表

### 8.1 创建的文件

1. `addons/godot_mcp/native_mcp/mcp_transport_base.gd`
2. `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`
3. `addons/godot_mcp/native_mcp/mcp_http_server.gd`
4. `addons/godot_mcp/native_mcp/mcp_sse_stream.gd`（可选）
5. `addons/godot_mcp/native_mcp/mcp_session_manager.gd`（可选）
6. `test/stdio/test_mcp_stdio.py`
7. `test/http/test_mcp_http_server.py`
8. `test/http/test_mcp_http_client.js`
9. `test/http/curl_examples.sh`
10. `docs/configuration/mcp-stdio-config-example.json`
11. `docs/configuration/mcp-http-config-example.json`
12. `addons/godot_mcp/native_mcp/default_config.json`

### 8.2 修改的文件

1. `addons/godot_mcp/native_mcp/mcp_server_core.gd`
2. `addons/godot_mcp/mcp_server_native.gd`
3. `addons/godot_mcp/ui/mcp_panel_native.gd`
4. `README.md`
5. `docs/README.md`（可选）

### 8.3 备份的文件

1. `addons/godot_mcp/native_mcp/mcp_server_core.gd.bak`
2. `addons/godot_mcp/mcp_server_native.gd.bak`

---

## 9. 总结

本迁移计划详细说明了如何将 Godot-MCP 从纯 stdio 传输方案扩展为支持 stdio 和 HTTP/SSE 双模式。

**主要工作**：
1. 创建传输层基类（`mcp_transport_base.gd`）
2. 提取 stdio 实现到 `mcp_stdio_server.gd`
3. 创建 HTTP 服务器实现（`mcp_http_server.gd`）
4. 修改现有核心文件以支持多种传输方式
5. 创建完整的测试脚本和文档
6. 更新 MCP 客户端配置

**预期成果**：
1. 保留 stdio 方案作为可选项（开发测试用）
2. 新增 HTTP/SSE 方案（生产环境用）
3. 用户可以通过配置灵活切换传输方式
4. 符合 MCP 最新规范（Streamable HTTP）

**风险**：
1. 传输层抽象增加代码复杂度
2. 需要充分测试两种传输方式的兼容性
3. 多线程安全（HTTP 服务器）

**建议**：
1. 分阶段实施，先实现基本功能，再优化性能
2. 充分测试，特别是两种传输方式的切换
3. 保留 stdio 方案作为备份

---

**文档结束**

如有问题，请参考：
- `docs/architecture/http-sse-migration-plan.md`（架构分析）
- `docs/testing/http-testing-guide.md`（测试指南）
- `README.md`（用户文档）
