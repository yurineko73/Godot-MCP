# Godot Native MCP 测试指南

## 测试准备

### 1. 验证文件结构

确保以下文件已创建：
```
addons/godot_mcp/
├── mcp_server_native.gd          # 新的主插件类
├── plugin.cfg                    # 插件配置（已更新）
├── native_mcp/
│   ├── mcp_types.gd             # 类型定义
│   └── mcp_server_core.gd       # 核心MCP服务器
└── tools/
    ├── node_tools_native.gd      # 节点工具（3个已实现）
    ├── scene_tools_native.gd     # 场景工具（2个已实现）
    └── script_tools_native.gd   # 脚本工具（1个已实现）
```

### 2. 启动Godot编辑器

**方法1：使用启动脚本**
```bash
# 双击运行
F:\gitProjects\Godot-MCP\start_godot_mcp.bat
```

**方法2：手动启动**
```bash
"F:\Godot\Godot_v4.6.1-stable_win64.exe" --path "F:\gitProjects\Godot-MCP" --editor
```

---

## 测试步骤

### 测试1：验证插件加载

1. 启动Godot编辑器
2. 打开项目：`F:\gitProjects\Godot-MCP`
3. 打开`项目设置` → `插件`
4. 找到`Godot Native MCP Server`插件
5. 将状态设置为`启用`

**预期结果**：
- 插件成功加载，无错误信息
- 输出窗口显示：`[MCP][INFO] Godot Native MCP Plugin initializing`
- 输出窗口显示：`[MCP][INFO] All MCP tools registered successfully`

**如果失败**：
- 检查`plugin.cfg`中的`script`路径是否正确
- 检查所有`.gd`文件是否存在语法错误
- 查看`输出`窗口的错误信息

---

### 测试2：测试MCP协议 - initialize方法

创建一个测试脚本`test_mcp_initialize.gd`：

```gdscript
@tool
extends EditorScript

func _run() -> void:
    print("=== Testing MCP initialize ===")
    
    # 构建initialize请求
    var request: Dictionary = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "test-client",
                "version": "1.0.0"
            }
        }
    }
    
    var json_string: String = JSON.stringify(request) + "\n"
    print("Sending: " + json_string)
    
    # 注意：这里只是打印请求，实际测试需要管道通信
    # 在真实场景中，请求会通过stdin发送给Godot
    print("NOTE: In real scenario, this would be sent via stdin")
    
    # 模拟处理请求
    var server_core = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
    server_core.set_log_level(3)  # DEBUG
    
    # 手动调用处理方法（模拟）
    print("Server core created. In real scenario, it would process stdin messages.")
```

**运行测试**：
1. 在Godot编辑器中，打开`脚本编辑器`
2. 加载`test_mcp_initialize.gd`
3. 点击`文件` → `运行` 

---

### 测试3：使用MCP Inspector（推荐）

MCP Inspector是测试MCP服务器的官方工具。

**步骤1：安装MCP Inspector**
```bash
npx @modelcontextprotocol/inspector
```

**步骤2：配置Godot服务器**

在MCP Inspector界面中，配置：
```json
{
  "command": "F:\\Godot\\Godot_v4.6.1-stable_win64.exe",
  "args": [
    "--path",
    "F:\\gitProjects\\Godot-MCP",
    "--headless"
  ]
}
```

**步骤3：连接并测试**

1. 点击`Connect`按钮
2. 如果连接成功，会显示`initialize`握手
3. 测试`tools/list` - 应该看到6个已实现的工具：
   - `create_node`
   - `delete_node`
   - `list_nodes`
   - `get_node_properties`
   - `get_scene_structure`
   - `read_script`
   - `list_project_scenes`

4. 测试`tools/call` - 调用一个工具，比如：
   ```json
   {
     "name": "list_project_scenes",
     "arguments": {}
   }
   ```

---

### 测试4：手动测试stdio通信

**创建测试脚本** `test_stdio_communication.gd`：

```gdscript
@tool
extends EditorScript

func _run() -> void:
    print("=== Testing stdio communication ===")
    
    # 启动MCP服务器
    var plugin = Engine.get_meta("GodotMCPPlugin")
    if not plugin:
        print("ERROR: Plugin not found in Engine meta")
        return
    
    print("Starting MCP Server...")
    var success = plugin.start_server()
    
    if success:
        print("MCP Server started successfully")
        print("Now you can send JSON-RPC messages via stdin")
        print("Example: {\"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"tools/list\"}")
    else:
        print("Failed to start MCP Server")
```

**运行测试**：
1. 在Godot编辑器中运行此脚本
2. 服务器启动后，在终端中输入JSON-RPC消息
3. 查看Godot的输出窗口，应该能看到响应

---

## 当前已实现的工具

### ✅ 完整实现（可测试）

1. **create_node** - 创建新节点
2. **delete_node** - 删除节点
3. **list_nodes** - 列出节点
4. **get_node_properties** - 获取节点属性
5. **get_scene_structure** - 获取场景树结构
6. **read_script** - 读取脚本内容
7. **list_project_scenes** - 列出所有场景

### ⏳ 待实现（TODO状态）

- save_scene, open_scene, get_current_scene
- create_script, modify_script, analyze_script
- run_project, stop_project, get_editor_state, etc.

---

## 已知问题和修复

### 问题1：工具函数无法访问编辑器接口

**状态**：已修复
- 在`mcp_server_native.gd._enter_tree()`中添加：
  ```gdscript
  Engine.set_meta("GodotMCPPlugin", self)
  ```

### 问题2：静态工具函数绑定

**状态**：设计如此
- 工具函数定义为`static func`
- 它们通过`Engine.get_meta("GodotMCPPlugin")`获取插件实例
- 然后调用`plugin.get_editor_interface()`获取编辑器接口

**验证**：需要在实际运行中测试

---

## 下一步

### 如果测试成功

1. 继续实现剩余25个工具
2. 创建UI面板（`mcp_panel_native.gd`）
3. 实现资源加载函数

### 如果测试失败

1. 查看`输出`窗口的错误信息
2. 检查`plugin.cfg`配置
3. 验证所有`.gd`文件无语法错误
4. 尝试简化测试（比如只注册1个工具）

---

## 快速测试命令

### 测试插件加载
```bash
"F:\Godot\Godot_v4.6.1-stable_win64.exe" --path "F:\gitProjects\Godot-MCP" --editor --verbose
```

### 测试headless模式
```bash
"F:\Godot\Godot_v4.6.1-stable_win64.exe" --path "F:\gitProjects\Godot-MCP" --headless
```

### 使用MCP Inspector
```bash
npx @modelcontextprotocol/inspector
```

---

## 需要帮助？

如果遇到问题，请提供：
1. Godot输出窗口的完整错误信息
2. 插件是否已成功启用
3. 哪个测试步骤失败
4. 操作系统和Godot版本信息
