# Godot MCP 原生实现 - 修复与测试文档

> 日期: 2026-05-01
> 版本: v2.0 修复版
> 状态: 已验证通过

---

## 一、修复总览

本次修复共涉及 **15个文件**，修复 **6大类问题**，涵盖编译错误、功能Bug、线程安全、API弃用、协议通信和实例生命周期。

| 类别 | 问题数 | 严重性 |
|------|--------|--------|
| 编译错误 | 6 | 🔴 严重 |
| 功能Bug | 5 | 🔴 严重 |
| 线程安全 | 3 | 🔴 严重 |
| API弃用迁移 | 1 | 🟡 中等 |
| MCP协议通信 | 3 | 🔴 严重 |
| 实例生命周期 | 1 | 🔴 严重 |

---

## 二、编译错误修复

### 2.1 Python风格docstring（GDScript不支持 `"""..."""`）

**影响文件：**
- `mcp_server_native.gd` — 6处
- `path_validator.gd` — 7处
- `resource_tools_native.gd` — 多处
- `mcp_resource_manager.gd` — 多处

**问题：** GDScript不支持Python风格的 `"""docstring"""` 作为函数文档，会导致解析错误。

**修复：** 替换为GDScript `##` 注释或直接删除。

```gdscript
# 修复前（错误）
func _resource_scene_list(params: Dictionary) -> Dictionary:
    """读取 godot://scene/list 资源"""

# 修复后（正确）
func _resource_scene_list(params: Dictionary) -> Dictionary:
```

### 2.2 缩进错误（4空格 vs Tab）

**影响文件：**
- `resource_tools_native.gd`
- `mcp_resource_manager.gd`
- `test_runner.gd`

**问题：** GDScript要求使用Tab缩进，4空格缩进会导致解析错误。

**修复：** 全文重写，将4空格缩进替换为Tab缩进。

### 2.3 Expression.execute() 误用

**影响文件：** `debug_tools_native.gd`

**问题：** 缺少 `parse()` 步骤，直接调用 `execute()`，且将代码字符串作为参数传入。

```gdscript
# 修复前（错误）
var arguments: PackedStringArray = PackedStringArray([code])
var result: Variant = expression.execute(arguments, null, true)

# 修复后（正确）
var parse_error: Error = expression.parse(code, [])
if parse_error != OK:
    return {"status": "error", "error": "Parse failed: " + expression.get_error_text()}
var result: Variant = expression.execute([], null, true)
```

### 2.4 String.get_line_count() 不存在

**影响文件：** `resource_tools_native.gd`

**问题：** `String` 类没有 `get_line_count()` 方法。

```gdscript
# 修复前（错误）
"line_count": script_content.get_line_count()

# 修复后（正确）
var line_count: int = 0
if not script_content.is_empty():
    line_count = script_content.split("\n").size()
```

### 2.5 类名冲突

**影响文件：** `script_tools_native_new.gd`（已删除）

**问题：** `script_tools_native_new.gd` 和 `script_tools_native.gd` 都声明了 `class_name ScriptToolsNative`，导致Godot解析器报错 `Could not resolve class "ScriptToolsNative"`。

**修复：** 删除 `script_tools_native_new.gd`。

### 2.6 Array[int] 类型不匹配

**影响文件：** `mcp_server_core.gd`

**问题：** `_request_timestamps[client_id] = []` 创建无类型Array，赋值给 `Array[int]` 变量报错。

```gdscript
# 修复前（错误）
_request_timestamps[client_id] = []
var timestamps: Array[int] = _request_timestamps[client_id]

# 修复后（正确）
var new_timestamps: Array[int] = []
_request_timestamps[client_id] = new_timestamps
var timestamps: Array[int] = _request_timestamps[client_id]
```

---

## 三、功能Bug修复

### 3.1 资源读取双重包装

**影响文件：** `mcp_server_core.gd`

**问题：** `_handle_resource_read` 中，资源函数已返回 `{"contents": [...]}` 格式，但处理器又包了一层，导致响应格式错误。

```gdscript
# 修复前（错误）- 总是包装
var result: Dictionary = {
    "contents": [{"uri": uri, "mimeType": resource.mime_type, "text": content.get("text", "")}]
}

# 修复后（正确）- 检查是否已有contents
if content.has("contents"):
    result = content
else:
    result = {"contents": [{"uri": uri, "mimeType": resource.mime_type, "text": content.get("text", "")}]}
```

### 3.2 get_property_list() 返回类型错误

**影响文件：** `project_tools_native.gd`

**问题：** `ProjectSettings.get_property_list()` 返回 `Array[Dictionary]`，不是 `PackedStringArray`。

```gdscript
# 修复前（错误）
var all_settings: PackedStringArray = ProjectSettings.get_property_list()
for setting_name in all_settings:

# 修复后（正确）
var all_properties: Array = ProjectSettings.get_property_list()
for property_info in all_properties:
    var setting_name: String = property_info.get("name", "")
```

### 3.3 await 在静态函数中不可用

**影响文件：** `editor_tools_native.gd`

**问题：** `await` 在静态函数中不可用，且未使用 `scene_path` 参数。

**修复：** 移除 `await`，添加 `play_custom_scene()` 支持。

### 3.4 RefCounted 无 _exit_tree 方法

**影响文件：** `mcp_server_core.gd`

**问题：** `_exit_tree()` 是Node的方法，`MCPServerCore` 继承 `RefCounted` 没有此方法。

**修复：** 重命名为 `cleanup()`。

### 3.5 NodePath 序列化问题

**影响文件：** `mcp_server_native.gd`

**问题：** `node.get_path()` 返回 `NodePath` 类型，不能直接放入Dictionary。

```gdscript
# 修复前（错误）
editor_state["selected_nodes"].append(node.get_path())

# 修复后（正确）
editor_state["selected_nodes"].append(str(node.get_path()))
```

---

## 四、线程安全修复

### 4.1 is_layout_rtl() 线程错误（79条报错）

**根因：** `_stdin_listen_loop()` 在后台线程运行，日志信号在后台线程发射，回调中直接操作UI控件。

**调用链：**
```
后台线程 (_stdin_listen_loop)
  → _log_error() / _log_info()
    → log_message.emit()          ← 信号在后台线程发射
      → _on_log_message()         ← 回调在后台线程执行
        → _bottom_panel.update_log()
          → TextEdit.text += ...  ← UI操作在非主线程 💥
```

**修复（三层防御）：**

**第1层：`mcp_server_core.gd` — 信号发射延迟到主线程**
```gdscript
# 修复前
log_message.emit("ERROR", message)

# 修复后
call_deferred("emit_signal", "log_message", "ERROR", message)
```

**第2层：`mcp_server_native.gd` — 信号回调线程检查**
```gdscript
func _on_server_started() -> void:
    if _bottom_panel and _bottom_panel.has_method("refresh"):
        if Thread.is_main_thread():
            _bottom_panel.refresh()
        else:
            _bottom_panel.call_deferred("refresh")
```

**第3层：`mcp_panel_native.gd` — UI操作入口线程安全**
```gdscript
func update_log(message: String) -> void:
    if not _log_text_edit:
        return
    if Thread.is_main_thread():
        _append_log(message)
    else:
        call_deferred("_append_log", message)

func _append_log(message: String) -> void:
    _log_text_edit.text += message + "\n"
    _log_text_edit.scroll_vertical = _log_text_edit.get_line_count()
```

### 4.2 _send_error 在后台线程调用

**影响文件：** `mcp_server_core.gd`

**问题：** `_parse_and_queue_message` 在后台线程调用 `_send_error`，后者发射 `response_sent` 信号。

**修复：** `call_deferred("_send_error", ...)` 延迟到主线程。

---

## 五、API弃用迁移

### 5.1 add_control_to_bottom_panel → EditorDock + add_dock

**影响文件：** `mcp_server_native.gd`

**问题：** `add_control_to_bottom_panel()` 在Godot 4.5+中标记为deprecated。

```gdscript
# 修复前（弃用）
add_control_to_bottom_panel(_bottom_panel, "MCP Server")
remove_control_from_bottom_panel(_bottom_panel)

# 修复后（新API）
var _dock: EditorDock = null

func _create_ui_panel() -> void:
    _dock = EditorDock.new()
    _dock.title = "MCP Server"
    _dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
    _dock.add_child(_bottom_panel)
    add_dock(_dock)

func _exit_tree() -> void:
    if _dock:
        remove_dock(_dock)
        _dock.queue_free()
```

### 5.2 缺失方法补充

**影响文件：** `mcp_server_core.gd`、`mcp_server_native.gd`

| 新增方法 | 所在文件 | 用途 |
|----------|----------|------|
| `get_tools_count()` | mcp_server_core.gd | 面板显示工具数量 |
| `get_resources_count()` | mcp_server_core.gd | 面板显示资源数量 |
| `get_registered_tools()` | mcp_server_core.gd | 面板工具管理列表 |
| `set_tool_enabled()` | mcp_server_core.gd | 面板启用/禁用工具 |
| `get_native_server()` | mcp_server_native.gd | 面板获取服务器核心引用 |

---

## 六、MCP协议通信修复

### 6.1 stdout/stderr 分离

**问题：** 所有 `print()` 输出到stdout，MCP客户端无法区分协议响应和日志输出。

**修复：**
| 输出类型 | 修复前 | 修复后 | 原因 |
|----------|--------|--------|------|
| MCP协议响应 | `print()` | `print()` | stdout专用于协议 |
| 日志/调试信息 | `print()` | `printerr()` | 日志输出到stderr |

### 6.2 stdout 缓冲区刷新

**问题：** `printraw()` 不自动刷新缓冲区，MCP响应留在缓冲区中无法送达客户端。

**修复：**
- `project.godot` 添加 `run/flush_stdout_on_print=true`
- `mcp_server_core.gd` 的 `start()` 中动态设置 `ProjectSettings.set_setting("application/run/flush_stdout_on_print", true)`
- 使用 `print()` 替代 `printraw()`（`print()` 受flush设置影响）

### 6.3 Windows console可执行文件

**问题：** Windows上 `Godot_v4.x-stable_win64.exe` 是GUI子系统程序，stdout不会连接到父进程的管道，MCP客户端收不到响应。

**修复：** 必须使用 `Godot_v4.x-stable_console_win64.exe`（控制台子系统版本）。

**MCP配置修正：**
```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "Godot_v4.x-stable_console_win64.exe",
      "args": ["--headless", "--editor", "--path", "项目路径", "--", "--mcp-server"]
    }
  }
}
```

### 6.4 --mcp-server 参数检测

**问题：** `--mcp-server` 不是Godot内置参数，需要放在 `--` 之后通过 `OS.get_cmdline_user_args()` 获取。原代码无条件启动服务器。

```gdscript
# 修复后
var _mcp_server_mode: bool = false

func _enter_tree() -> void:
    _mcp_server_mode = "--mcp-server" in OS.get_cmdline_user_args()
    
    if _mcp_server_mode:
        _start_native_server()
    elif auto_start:
        _start_native_server()
    else:
        _log_info("MCP server not auto-started.")
```

---

## 七、实例生命周期修复（关键Bug）

### 7.1 工具实例被垃圾回收导致Callable失效

**根因：** 所有6个工具文件（30个工具）的 `register_tools` 和 `_register_*` 方法是 `static`，每次注册创建局部实例，函数返回后实例被GC回收，`Callable.is_valid()` 返回 `false`，所有工具被 `is_valid()` 过滤掉。

**影响：** MCP客户端收到 `"tools":[]` 空工具列表。

```gdscript
# 修复前（错误）
static func _register_create_node(server_core: RefCounted) -> void:
    var instance = NodeToolsNative.new()  # ← 局部变量，函数返回后被GC
    server_core.register_tool(..., Callable(instance, "_tool_create_node"), ...)

# 修复后（正确）
func _register_create_node(server_core: RefCounted) -> void:
    server_core.register_tool(..., Callable(self, "_tool_create_node"), ...)  # ← self不会被GC
```

**完整修复方案：**

1. **所有工具文件**：`static func register_tools` → `func register_tools`
2. **所有工具文件**：`static func _register_*` → `func _register_*`
3. **所有工具文件**：`Callable(instance, ...)` → `Callable(self, ...)`
4. **所有工具文件**：添加 `var _editor_interface`、`func initialize()`、`func _get_editor_interface()`
5. **mcp_server_native.gd**：添加 `var _tool_instances: Dictionary = {}`，创建实例并保持引用

```gdscript
func _register_all_tools() -> void:
    _tool_instances["NodeToolsNative"] = NodeToolsNative.new()
    _tool_instances["ScriptToolsNative"] = ScriptToolsNative.new()
    # ... 其他工具
    
    _tool_instances["NodeToolsNative"].initialize(_editor_interface)
    # ... 其他初始化
    
    _tool_instances["NodeToolsNative"].register_tools(_native_server)
    # ... 其他注册
```

---

## 八、其他修复

### 8.1 重复代码清理

**影响文件：** `mcp_server_native.gd`

- 删除重复的服务器配置代码（6行）
- 删除6个无用的TODO方法（`_register_node_tools`等）

### 8.2 UI面板tscn冲突

**影响文件：** `mcp_panel_native.tscn`

**问题：** tscn文件定义了UI元素，但脚本也在 `_create_ui()` 中动态创建，导致冲突。

**修复：** 简化tscn为只包含根节点，让脚本处理所有UI创建。

### 8.3 test_runner.gd 修复

**影响文件：** `test_runner.gd`

- 4空格缩进 → Tab缩进
- `validate_path()` 返回值误用为bool → 正确使用 `result["valid"]`

---

## 九、修复后验证清单

| 验证项 | 预期结果 | 状态 |
|--------|----------|------|
| Godot编辑器加载插件无解析错误 | 无红色错误 | ✅ |
| `--mcp-server` 模式启动无崩溃 | 正常启动 | ✅ |
| MCP客户端连接成功 | 收到initialize响应 | ✅ |
| tools/list 返回30个工具 | 非空工具列表 | ✅ |
| 无 `is_layout_rtl()` 线程错误 | 无79条报错 | ✅ |
| 日志输出到stderr不污染stdout | MCP协议通道干净 | ✅ |
| EditorDock API正常工作 | 底部面板显示 | ✅ |
| 工具调用Callable有效 | 工具可正常执行 | ✅ |

---

## 十、MCP配置参考

### Windows（必须使用console版本）

```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "C:\\Godot\\Godot_v4.6.1-stable_console_win64.exe",
      "args": ["--headless", "--editor", "--path", "F:\\gitProjects\\Godot-MCP", "--", "--mcp-server"],
      "env": {}
    }
  }
}
```

### Linux

```json
{
  "mcpServers": {
    "godot-mcp-native": {
      "command": "/usr/bin/godot",
      "args": ["--headless", "--editor", "--path", "/home/user/Godot-MCP", "--", "--mcp-server"]
    }
  }
}
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `--headless` | 无头模式，不显示编辑器窗口，确保stdin/stdout正确连接 |
| `--editor` | 强制编辑器模式启动，加载EditorPlugin |
| `--path` | Godot-MCP项目路径 |
| `--` | 分隔Godot引擎参数和用户自定义参数 |
| `--mcp-server` | 自定义参数，插件检测后自动启动MCP服务器 |

**⚠️ Windows注意：** 必须使用 `console_win64.exe`，普通 `win64.exe` 是GUI子系统，stdout不会连接到管道。
