# 旧版 Commands vs 新版 Tools 功能对比分析

**分析日期**: 2026-05-02
**旧版路径**: `addons/godot_mcp/commands/` (8个文件, WebSocket协议)
**新版路径**: `addons/godot_mcp/tools/` (7个文件, MCP协议)

---

## 架构差异

| 维度 | 旧版 Commands | 新版 Tools |
|------|-------------|-----------|
| 通信协议 | WebSocket (自定义JSON) | MCP (JSON-RPC 2.0) |
| 基类 | `MCPBaseCommandProcessor` (extends Node) | 各模块独立 (extends RefCounted) |
| 注册方式 | `process_command()` match 分发 | `register_tools()` + Callable |
| 响应格式 | `{status, result/commandId}` | MCP 标准 `{content, structuredContent, isError}` |
| 插件访问 | `Engine.get_meta("GodotMCPPlugin")` | `EditorInterface` 注入 + 回退 |
| 路径安全 | 无验证 | `PathValidator` 验证 + 清理 |
| 属性过滤 | 仅跳过 `_` 前缀 | 跳过 `__` 前缀 + CATEGORY/GROUP/SUBGROUP |
| 值序列化 | 直接 `str()` | `_serialize_value()` 递归处理 Vector/Color 等 |
| 值反序列化 | `_parse_property_value()` (Expression) | `_convert_value_for_property()` (类型匹配) + JSON.parse_string |
| Undo/Redo | ✅ 使用 `EditorUndoRedoManager` | ❌ 直接 `set()` 无撤销 |
| 场景标记 | `_mark_scene_as_unsaved()` | `editor_interface.mark_scene_as_unsaved()` |

---

## 功能对比总表

### Node 操作

| 功能 | 旧版 (node_commands.gd) | 新版 (node_tools_native.gd) | 差异 |
|------|------------------------|---------------------------|------|
| create_node | ✅ | ✅ | 新版有 PathValidator + friendly_path |
| delete_node | ✅ | ✅ | 新版有 friendly_path |
| update_node_property | ✅ | ✅ | 见下方详细对比 |
| get_node_properties | ✅ | ✅ | 见下方详细对比 |
| list_nodes | ✅ | ✅ | 新版支持 recursive 参数 |
| get_scene_tree | ❌ | ✅ | **新版新增** |

### Scene 操作

| 功能 | 旧版 (scene_commands.gd) | 新版 (scene_tools_native.gd) | 差异 |
|------|-------------------------|----------------------------|------|
| create_scene | ✅ | ✅ | 新版有 PathValidator |
| save_scene | ✅ | ✅ | 新版有 PathValidator + 场景操作锁 |
| open_scene | ✅ | ✅ | 新版有 PathValidator + 场景操作锁 |
| get_current_scene | ✅ | ✅ | 新版返回更多字段 (node_count, is_modified) |
| get_scene_structure | ✅ | ✅ | 新版使用 friendly_path |
| list_project_scenes | ❌ | ✅ | **新版新增** |

### Script 操作

| 功能 | 旧版 (script_commands.gd) | 新版 (script_tools_native.gd) | 差异 |
|------|--------------------------|------------------------------|------|
| create_script | ✅ | ✅ | 见下方详细对比 |
| edit_script | ✅ (全量替换) | ✅ (modify_script, 支持行替换) | 新版支持行号替换 |
| get_script | ✅ | ✅ (read_script) | 新版有 PathValidator |
| get_script_metadata | ✅ | ❌ | **新版缺失** |
| get_current_script | ✅ | ❌ | **新版缺失** |
| create_script_template | ✅ | ✅ (template参数) | 新版集成到 create_script |
| list_project_scripts | ❌ | ✅ | **新版新增** |
| analyze_script | ❌ | ✅ | **新版新增** |

### Editor 操作

| 功能 | 旧版 (editor_commands.gd) | 新版 (editor_tools_native.gd) | 差异 |
|------|--------------------------|------------------------------|------|
| get_editor_state | ✅ | ✅ | 新版有 friendly_path |
| get_selected_node | ✅ (含属性) | ✅ (get_selected_nodes, 仅路径) | 见下方详细对比 |
| create_resource | ✅ | ✅ (project_tools) | 新版有 PathValidator |
| run_project | ❌ | ✅ | **新版新增** |
| stop_project | ❌ | ✅ | **新版新增** |
| set_editor_setting | ❌ | ✅ | **新版新增** |

### Debug 操作

| 功能 | 旧版 (debug_commands.gd) | 新版 (debug_tools_native.gd) | 差异 |
|------|-------------------------|------------------------------|------|
| read_logs | ✅ (editor + runtime) | ✅ (get_editor_logs, 仅MCP日志) | 见下方详细对比 |
| execute_script | ❌ | ✅ | **新版新增** |
| get_performance_metrics | ❌ | ✅ | **新版新增** |
| debug_print | ❌ | ✅ | **新版新增** |

### Project 操作

| 功能 | 旧版 (project_commands.gd) | 新版 (project_tools_native.gd) | 差异 |
|------|---------------------------|------------------------------|------|
| get_project_info | ✅ | ✅ | 新版有 ResourceUID 解析 |
| list_project_files | ✅ | ❌ | **新版缺失** (被 list_project_resources 替代) |
| get_project_structure | ✅ | ❌ | **新版缺失** |
| get_project_settings | ✅ (结构化) | ✅ (filter参数) | 新版更灵活但无结构化 |
| list_project_resources | ✅ (分类) | ✅ (扩展名过滤) | 见下方详细对比 |

### EditorScript 操作

| 功能 | 旧版 (editor_script_commands.gd) | 新版 | 差异 |
|------|--------------------------------|------|------|
| execute_editor_script | ✅ (完整脚本执行) | ❌ | **新版缺失** (被 execute_script 部分替代) |

---

## 🔴 新版缺失的功能 (需补充) — 已全部实现 ✅

### 1. Undo/Redo 支持 (P0 - 严重) — ✅ 已实现

**旧版**: `update_node_property` 使用 `EditorUndoRedoManager`:
```gdscript
undo_redo.create_action("Update Property: " + property_name)
undo_redo.add_do_property(node, property_name, parsed_value)
undo_redo.add_undo_property(node, property_name, old_value)
undo_redo.commit_action()
```

**新版 (已修复)**: 在 `_tool_update_node_property` 中恢复了 UndoRedo 支持:
```gdscript
var undo_redo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
if undo_redo:
    undo_redo.create_action("Update Property: " + property_name)
    undo_redo.add_do_property(target_node, property_name, converted_value)
    undo_redo.add_undo_property(target_node, property_name, old_value)
    undo_redo.commit_action()
else:
    target_node.set(property_name, converted_value)
```

### 2. get_script_metadata (P1) — ✅ 已通过 analyze_script + get_current_script 实现

**旧版**: 返回脚本的元数据信息:
- `class_name` (通过正则提取)
- `extends` (通过正则提取)
- `methods` 列表 (通过正则提取)
- `signals` 列表 (通过正则提取)
- `language` (gdscript/csharp)

**新版**: `analyze_script` 提供了类似功能但不完全相同:
- 有 `functions` 和 `signals`
- 有 `has_class_name` 和 `extends_from`
- 缺少 `language` 字段
- 缺少 `properties` 列表 (旧版也没有，但 analyze_script 声明了却返回空数组)

**建议**: 完善 `analyze_script` 的 `properties` 提取，添加 `language` 字段。

### 3. get_current_script (P1) — ✅ 已实现

**旧版**: 获取编辑器中当前正在编辑的脚本:
```gdscript
var script_editor = editor_interface.get_script_editor()
var current_script = script_editor.get_current_script()
```

**新版**: 完全缺失此功能。

**建议**: 在 `script_tools_native.gd` 中添加 `get_current_script` 工具。

### 4. read_logs 的 runtime 日志源 (P1) — ✅ 已实现

**旧版**: 支持两种日志源:
- `source: "editor"` — 编辑器日志 (通过 plugin.get_editor_log_entries())
- `source: "runtime"` — 运行时日志 (读取 `user://logs/godot.log`)

还支持:
- `type` 过滤 (Error/Warning/General)
- `count` + `offset` 分页
- `order` 排序 (asc/desc)

**新版**: `get_editor_logs` 仅返回 MCP 服务器自身的日志缓冲区 (`_log_buffer`)，不支持:
- 运行时日志
- 类型过滤
- 分页和排序

**建议**: 增强 `get_editor_logs` 支持 `source`、`type`、`count`、`offset`、`order` 参数。

### 5. execute_editor_script (P2) — ✅ 已实现

**旧版**: 完整的脚本执行环境:
- 创建临时 Node + GDScript
- 替换 `print()` 为 `custom_print()` 捕获输出
- 支持 `await` 异步执行
- 通过 `execution_completed` 信号获取结果
- 支持访问 `get_tree().edited_scene_root`

**新版**: `execute_script` 使用 `Expression` 类:
- 仅支持表达式，不支持语句
- 绑定了 11 个单例
- 不支持 `await`
- 不支持多行脚本
- 不支持 `print()` 输出捕获

**建议**: 保留 `execute_script` 用于简单表达式，新增 `execute_editor_script` 用于完整脚本执行。

### 6. list_project_files (P2)

**旧版**: 列出项目文件，支持扩展名过滤:
```gdscript
_list_project_files(client_id, {"extensions": [".tscn", ".gd"]}, command_id)
```

**新版**: `list_project_resources` 提供了类似功能但使用不同的参数格式。

**建议**: 功能已被 `list_project_resources` 替代，无需单独添加。

### 7. get_project_structure (P2) — ✅ 已实现

**旧版**: 返回项目目录结构:
```json
{
  "directories": ["res://addons/", "res://scenes/"],
  "file_counts": {".gd": 15, ".tscn": 8},
  "total_files": 42
}
```

**新版**: 完全缺失此功能。

**建议**: 在 `project_tools_native.gd` 中添加 `get_project_structure` 工具。

### 8. get_selected_node 详细信息 (P2) — ✅ 已实现

**旧版**: `get_selected_node` 返回:
- `name`, `type`, `path`
- `script_path` (如果有)
- `properties` (position, rotation, scale, visible, modulate, z_index)

**新版**: `get_selected_nodes` 仅返回路径列表。

**建议**: 在 `get_selected_nodes` 响应中添加 `type` 和 `script_path` 字段。

### 9. create_script 的脚本附加功能 (P2) — ✅ 已实现

**旧版**: `create_script` 支持:
- `node_path` 参数 — 创建后自动附加到节点
- 自动在编辑器中打开脚本 (`editor_interface.edit_script()`)
- 文件系统刷新 (`editor_interface.get_resource_filesystem().scan()`)

**新版**: 仅创建文件，不附加到节点，不自动打开。

**建议**: 添加可选的 `attach_to_node` 参数。

---

## 🟢 新版新增的功能 (旧版没有)

| 功能 | 模块 | 说明 |
|------|------|------|
| get_scene_tree | node_tools | 获取完整场景树结构 |
| list_project_scenes | scene_tools | 列出所有 .tscn 文件 |
| list_project_scripts | script_tools | 列出所有 .gd 文件 |
| analyze_script | script_tools | 分析脚本结构 |
| run_project | editor_tools | 运行项目 |
| stop_project | editor_tools | 停止运行 |
| set_editor_setting | editor_tools | 设置编辑器属性 |
| execute_script | debug_tools | 执行 GDScript 表达式 |
| get_performance_metrics | debug_tools | 获取性能指标 |
| debug_print | debug_tools | 输出调试信息 |
| MCP 资源系统 | resource_tools | 7个 MCP Resource 端点 |
| PathValidator | 全局 | 路径安全验证 |
| structuredContent | mcp_server_core | MCP 协议结构化响应 |
| outputSchema + annotations | 全部工具 | MCP 工具元数据 |
| friendly_path | node/scene/editor | 用户友好的节点路径 |
| 场景操作锁 | scene_tools | 防止并发场景操作 |
| JSON.parse_string | node_tools | 正确处理 MCP 客户端传来的字符串值 |

---

## 🟡 行为差异 (需注意)

### 1. update_node_property 值解析

| 方面 | 旧版 | 新版 |
|------|------|------|
| 方法 | `_parse_property_value()` — 用 Expression 执行字符串 | `_convert_value_for_property()` — 类型匹配 + JSON.parse_string |
| Vector3 | `"Vector3(1,2,3)"` → Expression 执行 | `{"x":1,"y":2,"z":3}` → Dictionary 解析 |
| 安全性 | Expression 可执行任意代码 | 类型匹配更安全 |
| 兼容性 | 支持 Godot 类型字符串 | 需要客户端传 JSON 格式 |

### 2. get_node_properties 过滤

| 方面 | 旧版 | 新版 |
|------|------|------|
| 内部属性 | 跳过 `_` 前缀 | 跳过 `__` 前缀 |
| 分类属性 | 不过滤 | 过滤 CATEGORY(128)/GROUP(64)/SUBGROUP(256) |
| 结果 | 包含分类标题 | 更干净，无分类标题 |

### 3. get_project_settings 格式

| 方面 | 旧版 | 新版 |
|------|------|------|
| 格式 | 结构化 (display/physics/rendering/input_map) | 扁平 (所有设置平铺) |
| 过滤 | 无 | 支持 `filter` 前缀参数 |
| 值类型 | 保留原始类型 | 全部转为 `str()` |

### 4. list_project_resources 分类

| 方面 | 旧版 | 新版 |
|------|------|------|
| 分类 | 按6类分 (scenes/scripts/textures/audio/models/resources) | 按扩展名过滤，平铺列表 |
| 灵活性 | 固定分类 | 自定义扩展名 |

---

## 优先级建议 — 全部已完成 ✅

| 优先级 | 功能 | 状态 | 实现方式 |
|--------|------|------|----------|
| **P0** | Undo/Redo 支持 | ✅ 已实现 | `node_tools_native.gd` 使用 `EditorUndoRedoManager` |
| **P1** | get_current_script | ✅ 已实现 | `script_tools_native.gd` 新增工具 |
| **P1** | read_logs 增强 | ✅ 已实现 | `debug_tools_native.gd` 支持 source/type/count/offset/order |
| **P1** | analyze_script 完善 | ✅ 已实现 | 添加 `properties` 提取 + `language` 字段 |
| **P2** | execute_editor_script | ✅ 已实现 | `debug_tools_native.gd` 新增完整脚本执行工具 |
| **P2** | get_project_structure | ✅ 已实现 | `project_tools_native.gd` 新增工具 |
| **P2** | get_selected_nodes 增强 | ✅ 已实现 | `editor_tools_native.gd` 添加 type + script_path |
| **P2** | create_script 附加到节点 | ✅ 已实现 | `script_tools_native.gd` 添加 `attach_to_node` 参数 |

### 修复的Bug

| Bug | 文件 | 修复 |
|-----|------|------|
| `set_source_code()` 返回 void，不能赋值给 Error | `debug_tools_native.gd:513` | 改为直接调用，不赋值 |
| `_scan_directory` 的 `total_files` 传值不累加 | `project_tools_native.gd` | 改为从 `file_counts` 字典计算 |
| `node.get_script()` 返回 Variant 可能为 null，赋值给 `Script` 类型出错 | `editor_tools_native.gd` | 改为 `var node_script: Variant = node.get_script()` + `is Script` 检查 |

---

## 🔴 关键Bug：Available tools: 0 (2026-05-03 修复)

### 现象

MCP 插件启动后，所有工具注册失败，客户端获取工具列表返回 0 个工具：

```
ERROR: [MCP][INFO] Tools list requested. Available tools: 0
ERROR: [MCP Server][INFO] Tools list requested. Available tools: 0
```

GUT 单元测试全部通过（226/226），说明代码逻辑本身没有问题，但编辑器运行时工具注册失败。

### 根本原因

**`Callable(self, "static_method")` 在 Godot 4.x 编辑器中 `is_valid()` 返回 `false`**

工具注册流程：
1. `_enter_tree()` → `_register_all_tools()`
2. 各模块 `register_tools(server_core)` → `server_core.register_tool(name, desc, schema, Callable(self, "_tool_xxx"))`
3. `register_tool()` 内部调用 `tool.is_valid()` → 检查 `callable.is_valid()`

问题在于：`static` 方法属于类本身而非实例，当使用 `Callable(self, "static_method")` 创建 Callable 时，Godot 4.x 的 `Callable.is_valid()` 返回 `false`，导致工具被静默拒绝注册。

**受影响的方法**（全部使用了 `static func _tool_xxx` + `Callable(self, "_tool_xxx")` 模式）：

| 文件 | static 工具方法 |
|------|----------------|
| `debug_tools_native.gd` | `_tool_get_performance_metrics`, `_tool_debug_print` |
| `script_tools_native.gd` | `_tool_list_project_scripts`, `_tool_read_script`, `_tool_create_script`, `_tool_modify_script`, `_tool_analyze_script` + 辅助方法 `_collect_scripts`, `_get_editor_interface_static`, `_resolve_node_path_static`, `_get_script_template` |
| `project_tools_native.gd` | `_tool_get_project_info`, `_tool_get_project_settings`, `_tool_list_project_resources`, `_tool_create_resource`, `_tool_get_project_structure` + 辅助方法 `_collect_resources`, `_scan_directory` |
| `scene_tools_native.gd` | `_tool_create_scene`, `_tool_list_project_scenes` + 辅助方法 `_collect_scenes` |

### 修复方案

#### 1. 将所有 `static` 工具方法改为实例方法

```gdscript
# 修复前（Callable.is_valid() 返回 false）
static func _tool_get_performance_metrics(params: Dictionary) -> Dictionary:
    ...
# 注册时: Callable(self, "_tool_get_performance_metrics") → is_valid() = false

# 修复后（Callable.is_valid() 返回 true）
func _tool_get_performance_metrics(params: Dictionary) -> Dictionary:
    ...
# 注册时: Callable(self, "_tool_get_performance_metrics") → is_valid() = true
```

同时清理了 `script_tools_native.gd` 中重复的方法：
- 移除 `_get_editor_interface_static()`（与 `_get_editor_interface()` 功能重复）
- `_resolve_node_path_static()` 重命名为 `_resolve_node_path()`

#### 2. `register_tool()` 添加详细诊断日志

**文件**: `mcp_server_core.gd`

```gdscript
# 修复前：静默失败
if not tool.is_valid():
    _log_error("Invalid tool definition: " + name)
    return

# 修复后：输出具体失败原因
if not tool.is_valid():
    var reason: String = "unknown"
    if name.is_empty():
        reason = "name is empty"
    elif description.is_empty():
        reason = "description is empty"
    elif not callable.is_valid():
        reason = "callable is invalid (method may not exist or object is freed)"
    _log_error("Invalid tool definition: " + name + " (reason: " + reason + ")")
    printerr("[MCP][DIAG] Tool '%s' rejected: callable.is_valid()=%s, callable=%s" % [name, str(callable.is_valid()), str(callable)])
    return
```

#### 3. `_register_all_tools()` 添加错误隔离和诊断日志

**文件**: `mcp_server_native.gd`

```gdscript
# 修复前：一个模块失败导致整个函数中止
_tool_instances["NodeToolsNative"] = NodeToolsNative.new()  # 如果这里崩溃，后续全部不执行
_tool_instances["ScriptToolsNative"] = ScriptToolsNative.new()
...

# 修复后：每个模块独立注册 + 详细日志
func _register_all_tools() -> void:
    ...
    _register_tool_module("NodeToolsNative", NodeToolsNative.new())
    _register_tool_module("ScriptToolsNative", ScriptToolsNative.new())
    ...

func _register_tool_module(module_name: String, instance: RefCounted) -> void:
    # 每个模块独立处理，失败不影响其他模块
    printerr("[MCP Plugin][DIAG] Instance created: " + module_name + " OK")
    _tool_instances[module_name] = instance
    if instance.has_method("initialize"):
        instance.initialize(_editor_interface)
    var tools_before: int = _native_server.get_tools_count()
    if instance.has_method("register_tools"):
        instance.register_tools(_native_server)
    var tools_after: int = _native_server.get_tools_count()
    printerr("[MCP Plugin][DIAG] Registered: %s (added %d tools, total now %d)" % [module_name, tools_after - tools_before, tools_after])
```

### 经验教训

| 教训 | 说明 |
|------|------|
| **不要对工具方法使用 `static`** | `Callable(self, "static_method")` 在 Godot 4.x 中 `is_valid()` 返回 `false`，应使用实例方法 |
| **辅助方法可以保留 `static`** | 不通过 Callable 注册的辅助方法（如 `_make_friendly_path`, `_serialize_value`）可以安全使用 `static` |
| **GUT 通过 ≠ 编辑器正常** | GUT 在 headless 模式下运行，`class_name` 不可用，测试用 `load()` 方式创建实例，与编辑器环境不同 |
| **关键路径需要诊断日志** | `register_tool()` 的 `is_valid()` 检查失败时静默返回，导致问题难以定位 |
| **错误隔离很重要** | `_register_all_tools()` 中一个模块失败不应阻止其他模块注册 |
