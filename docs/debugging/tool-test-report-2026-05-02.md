# MCP 工具摸底测试报告

**测试日期**: 2026-05-02
**测试环境**: Godot 4.6, Windows, HTTP 模式 (端口 9080)
**测试方法**: 第一轮通过 curl, 第二轮通过 Trae CN MCP 客户端直接调用
**测试场景**: TestScene.tscn (Node3D 根节点, 包含 "A test node" 和 "VerifyNode")

---

## 测试总览

### 第一轮测试 (修复前, curl)

| 类别 | 工具数 | 通过 | 失败 | 部分通过 |
|------|--------|------|------|----------|
| Node Tools | 6 | 6 | 0 | 0 |
| Script Tools | 5 | 4 | 0 | 1 |
| Scene Tools | 6 | 6 | 0 | 0 |
| Editor Tools | 5 | 5 | 0 | 0 |
| Debug Tools | 4 | 3 | 0 | 1 |
| Project Tools | 4 | 4 | 0 | 0 |
| **合计** | **30** | **28** | **0** | **2** |

### 第二轮测试 (修复后, Trae CN MCP 客户端)

| 类别 | 工具数 | 通过 | 失败 | 部分通过 |
|------|--------|------|------|----------|
| Node Tools | 6 | 6 | 0 | 0 |
| Script Tools | 5 | 5 | 0 | 0 |
| Scene Tools | 6 | 6 | 0 | 0 |
| Editor Tools | 5 | 5 | 0 | 0 |
| Debug Tools | 4 | 4 | 0 | 0 |
| Project Tools | 4 | 4 | 0 | 0 |
| **合计** | **30** | **30** | **0** | **0** |

**第二轮通过率: 100% (30/30)**

### 修复验证结果

| 问题 | 修复状态 | 验证状态 |
|------|----------|----------|
| structuredContent 缺失 (Trae CN 显示[]) | ✅ 已修复 | ✅ 已验证 |
| isError 标志始终为 false | ✅ 已修复 | ✅ 已验证 |
| read_script 中文乱码 | ✅ 已修复 | ✅ 已验证 (中文正常显示) |
| execute_script 无法访问单例 | ✅ 已修复 | ✅ 已验证 (OS.get_name()="Windows") |
| 场景树返回内部编辑器路径 | ✅ 已修复 | ✅ 已验证 (/root/Node3D) |
| get_node_properties 包含分组标题 | ✅ 已修复 | ✅ 已验证 (分组标题已过滤) |
| list_project_resources 结果偏少 | ✅ 已修复 | ✅ 已验证 (2→512个资源) |
| get_selected_nodes 返回内部路径 | ✅ 已修复 | ✅ 已验证 (/root/Node3D) |
| HTTP Content-Length 字符数/字节数不匹配 | ✅ 已修复 | ✅ 已验证 |
| update_node_property Vector3 设置不生效 | ✅ 已修复 | ✅ 已验证 (position=(10,5,3)) |

---

## 第一轮测试详细结果

### Node Tools (6/6 通过)

| # | 工具名 | 状态 | 测试参数 | 返回结果摘要 |
|---|--------|------|----------|-------------|
| 1 | create_node | ✅ 通过 | parent_path="/root/Node3D", node_type="Node3D", node_name="TestNode_MCP" | 成功创建, node_path="/root/Node3D/TestNode_MCP" |
| 2 | delete_node | ✅ 通过 | node_path="/root/Node3D/TestNode_MCP" | 成功删除, deleted_node="TestNode_MCP" |
| 3 | update_node_property | ✅ 通过 | node_path="/root/Node3D/TestNode_MCP", property_name="position", property_value={"x":5,"y":3,"z":1} | 成功更新, old_value="(0,0,0)", new_value="(5,3,1)" |
| 4 | update_node_property (bool) | ✅ 通过 | node_path="/root/Node3D", property_name="visible", property_value=false | 成功更新, old_value="true", new_value="false" |
| 5 | get_node_properties | ✅ 通过 | node_path="/root/Node3D" | 返回完整属性列表, node_type="Node3D" |
| 6 | list_nodes | ✅ 通过 | parent_path="/root/Node3D", recursive=true | 返回5个节点 |
| 7 | get_scene_tree | ✅ 通过 | (无参数) | 返回完整场景树, total_nodes=5 |

### Script Tools (4/5 通过, 1 部分通过)

| # | 工具名 | 状态 | 测试参数 | 返回结果摘要 |
|---|--------|------|----------|-------------|
| 8 | list_project_scripts | ✅ 通过 | (无参数) | 返回36个脚本文件 |
| 9 | read_script | ⚠️ 部分通过 | script_path="res://test_mcp_native.gd" | 内容返回但**中文字符乱码** |
| 10 | create_script | ✅ 通过 | script_path="res://test_mcp_created.gd", content="extends Node..." | 成功创建, line_count=5 |
| 11 | modify_script | ✅ 通过 | script_path="res://test_mcp_created.gd", content="...", line_number=2 | 成功修改, line_count=12 |
| 12 | analyze_script | ✅ 通过 | script_path="res://test_mcp_native.gd" | 正确识别4个函数, extends SceneTree |

### Scene Tools (6/6 通过)

| # | 工具名 | 状态 | 测试参数 | 返回结果摘要 |
|---|--------|------|----------|-------------|
| 13 | create_scene | ✅ 通过 | scene_path="res://test_mcp_scene.tscn", root_node_type="Node2D" | 成功创建 |
| 14 | save_scene | ✅ 通过 | (无参数) | 成功保存, saved_path="res://TestScene.tscn" |
| 15 | open_scene | ✅ 通过 | scene_path="res://TestScene.tscn" | 成功打开, root_node_type="Node3D" |
| 16 | get_current_scene | ✅ 通过 | (无参数) | scene_name="Node3D", node_count=5 |
| 17 | get_scene_structure | ✅ 通过 | (无参数) | 返回完整场景结构, total_nodes=5 |
| 18 | list_project_scenes | ✅ 通过 | (无参数) | 返回3个场景文件 |

### Editor Tools (5/5 通过)

| # | 工具名 | 状态 | 测试参数 | 返回结果摘要 |
|---|--------|------|----------|-------------|
| 19 | get_editor_state | ✅ 通过 | (无参数) | active_scene="Node3D", 1个选中节点 |
| 20 | run_project | ✅ 通过 | (无参数) | mode="playing" |
| 21 | stop_project | ✅ 通过 | (无参数) | mode="editor" |
| 22 | get_selected_nodes | ✅ 通过 | (无参数) | 返回1个选中节点 |
| 23 | set_editor_setting | ✅ 通过 | setting_name="debug/gdscript/warnings/unused_variable", setting_value=false | 成功设置 |

### Debug Tools (3/4 通过, 1 部分通过)

| # | 工具名 | 状态 | 测试参数 | 返回结果摘要 |
|---|--------|------|----------|-------------|
| 24 | get_editor_logs | ✅ 通过 | max_lines=10 | 返回10条日志, total_available=98 |
| 25 | execute_script (简单) | ✅ 通过 | code="1 + 2" | result="3" |
| 26 | execute_script (复杂) | ⚠️ 部分通过 | code="OS.get_name()" | **执行失败**: 无法访问单例对象 |
| 27 | debug_print | ✅ 通过 | message="MCP tool test message", category="TEST" | 成功打印 |

### Project Tools (4/4 通过)

| # | 工具名 | 状态 | 测试参数 | 返回结果摘要 |
|---|--------|------|----------|-------------|
| 28 | get_project_info | ✅ 通过 | (无参数) | project_name="Godot MCP" |
| 29 | get_project_settings | ✅ 通过 | filter="application/" | 返回36个设置项 |
| 30 | list_project_resources | ✅ 通过 | (无参数) | 返回2个资源文件 |
| 31 | create_resource | ✅ 通过 | resource_path="res://test_mcp_curve.tres", resource_type="Curve" | 成功创建 |

---

## 错误处理测试

| # | 测试场景 | 预期行为 | 实际行为 | 状态 |
|---|----------|----------|----------|------|
| 1 | get_node_properties 不存在的节点 | 返回错误 | {"error":"Node not found: /root/NonExistentNode"} | ✅ 正确 |
| 2 | read_script 不存在的文件 | 返回错误 | {"error":"Failed to open file: res://nonexistent.gd"} | ✅ 正确 |
| 3 | create_node 无效节点类型 | 返回错误 | {"error":"Invalid node type: InvalidNodeType"} | ✅ 正确 |
| 4 | 错误响应 isError 标志 | isError=true | **isError=false** | ❌ Bug → ✅ 已修复 |

---

## 发现的问题及修复

### 🔴 P0 严重问题

#### 问题 1: 工具错误响应 `isError` 标志始终为 false → ✅ 已修复

**位置**: `mcp_server_core.gd` → `_handle_tool_call()`
**现象**: 当工具返回 `{"error": "..."}` 时, MCP 协议响应中 `isError` 字段始终为 `false`
**根因**: `_handle_tool_call()` 中构建响应时硬编码 `"isError": false`, 未检查工具返回结果是否包含错误
**修复**: 添加 `has_error` 检查, 当 result 包含 "error" 键时设置 `isError: true`

```gdscript
var has_error: bool = result is Dictionary and result.has("error")
var response_result: Dictionary = {
    "content": [{"type": "text", "text": JSON.stringify(result)}],
    "isError": has_error
}
```

#### 问题 2: 缺少 structuredContent 导致 Trae CN 显示 [] → ✅ 已修复

**位置**: `mcp_server_core.gd` → `_handle_tool_call()`
**现象**: Trae CN MCP 客户端调用所有工具时显示 `[]` (空数组)
**根因**: Trae CN 客户端日志显示 "Tool X has an output schema but did not return structured content"。MCP 协议 2025-03-26+ 规定, 当工具定义了 `outputSchema` 时, 响应中必须包含 `structuredContent` 字段, 否则客户端无法解析结果
**修复**: 当工具有 output_schema 且结果无错误时, 添加 `structuredContent` 字段

```gdscript
if not has_error and tool.output_schema.size() > 0:
    response_result["structuredContent"] = result
```

**验证**: 修复后 curl 测试确认响应中包含 `structuredContent` 字段

#### 问题 3: read_script 中文字符乱码 → ✅ 已修复 (需重启验证)

**位置**: `script_tools_native.gd` → `_tool_read_script()` + `mcp_http_server.gd`
**现象**: 读取包含中文注释的 GDScript 文件时, 中文字符显示为乱码
**根因分析**:
1. `FileAccess.get_line()` 逐行读取可能存在编码处理问题 → 改用 `get_as_text()`
2. HTTP `Content-Type` 未指定 `charset=utf-8` → 已添加
3. **关键**: `Content-Length` 使用字符数 (`json_string.length()`) 而非字节数 (`json_bytes.size()`), 导致 UTF-8 多字节字符的响应被截断 → 已修复

**修复内容**:
- `script_tools_native.gd`: 改用 `file.get_as_text()` 替代逐行读取
- `mcp_http_server.gd`: `Content-Type` 添加 `; charset=utf-8`
- `mcp_http_server.gd`: `Content-Length` 使用 `json_bytes.size()` 替代 `json_string.length()`
- `mcp_http_server.gd`: 分离 header 和 body 字节, 避免 UTF-8 编码问题

### 🟡 P1 中等问题

#### 问题 4: execute_script 无法访问 Godot 单例 → ✅ 已修复

**位置**: `debug_tools_native.gd` → `_tool_execute_script()`
**现象**: `OS.get_name()` 等访问 Godot 单例的表达式执行失败
**根因**: `Expression.execute()` 绑定的 base_instance 是 `self` (DebugToolsNative), 无法访问全局单例
**修复**: 将常用 Godot 单例 (OS, Engine, Input, Time, JSON, ClassDB, Performance, ResourceLoader, ResourceSaver, EditorInterface, ProjectSettings) 绑定为 Expression 变量

```gdscript
var singletons: Dictionary = {
    "OS": OS, "Engine": Engine, "Input": Input,
    "Time": Time, "JSON": JSON, "ClassDB": ClassDB,
    "Performance": Performance, "ResourceLoader": ResourceLoader,
    "ResourceSaver": ResourceSaver, "EditorInterface": EditorInterface,
    "ProjectSettings": ProjectSettings,
}
for singleton_name in singletons:
    bind_names.append(singleton_name)
    bind_values.append(singletons[singleton_name])
expression.parse(code, bind_names)
expression.execute(bind_values, self, true)
```

**验证**: `OS.get_name()` 成功返回 "Windows"

#### 问题 5: 场景树/选中节点返回内部编辑器路径 → ✅ 已修复

**位置**: `node_tools_native.gd`, `scene_tools_native.gd`, `editor_tools_native.gd`
**现象**: 节点路径返回 `/root/@EditorNode@18065/@Panel@14/.../Node3D` 而非 `/root/Node3D`
**根因**: `node.get_path()` 返回节点在完整场景树中的路径, 包含编辑器内部节点
**修复**: 在三个文件中添加 `_make_friendly_path()` 静态方法, 将内部路径转换为友好路径

```gdscript
static func _make_friendly_path(node: Node, scene_root: Node) -> String:
    if not scene_root:
        return str(node.get_path())
    if node == scene_root:
        return "/root/" + scene_root.name
    var node_path: String = str(node.get_path())
    var root_path: String = str(scene_root.get_path())
    if node_path.begins_with(root_path + "/"):
        return "/root/" + scene_root.name + node_path.substr(root_path.length())
    return node_path
```

**验证**: `get_scene_tree` 和 `list_nodes` 现在返回 `/root/Node3D/...` 格式的友好路径

### 🟢 P2 轻微问题

#### 问题 6: get_node_properties 包含分组标题 → ✅ 已修复

**位置**: `node_tools_native.gd` → `_tool_get_node_properties()`
**根因**: Godot 4.x 中 `PROPERTY_USAGE_CATEGORY = 128`, `PROPERTY_USAGE_GROUP = 64`, `PROPERTY_USAGE_SUBGROUP = 256`。GDScript 中 `PROPERTY_USAGE_CATEGORY` 常量在 `get_property_list()` 返回的字典中不是标准枚举，需要用硬编码值过滤。
**修复**: 使用硬编码值过滤三种分组标记

```gdscript
var usage_flags: int = property_dict.get("usage", 0)
if usage_flags & 128 or usage_flags & 64 or usage_flags & 256:
    continue
```

#### 问题 7: list_project_resources 结果偏少 → ✅ 已修复

**位置**: `project_tools_native.gd` → `_tool_list_project_resources()`
**修复**: 扩展默认资源扩展名列表, 添加 `.tscn`, `.gd`, `.cfg`, `.json`, `.gdshader`, `.fbx`, `.import` 等

#### 问题 8: get_selected_nodes 返回内部路径 → ✅ 已修复

**位置**: `editor_tools_native.gd` → `_tool_get_selected_nodes()` 和 `_tool_get_editor_state()`
**修复**: 使用 `_make_friendly_path()` 转换路径

#### 问题 9: update_node_property Vector3/Vector2/Color 等复合属性设置不生效 → ✅ 已修复

**位置**: `node_tools_native.gd` → `_tool_update_node_property()`
**现象**: 通过 MCP 客户端调用 `update_node_property` 设置 `position` 等 Vector3 属性时, 值始终为 (0,0,0), 设置不生效
**根因**: MCP 客户端传入的 `property_value` 参数 (如 `{"x": 10, "y": 5, "z": 3}`) 被序列化为 **字符串类型** (typeof=4, 即 TYPE_STRING), 而非 Dictionary。这是因为工具 schema 中 `property_value` 没有指定 `"type"` 字段, MCP 协议将其默认为 string。`_convert_value_for_property` 中的 `TYPE_VECTOR3` 分支只处理 Dictionary 和 String 格式, 但传入的字符串是 JSON 格式 (`{"x": 10, "y": 5, "z": 3}`), 不是 Vector3 字符串格式 (`(10, 5, 3)`)
**修复**: 在调用 `_convert_value_for_property` 前, 如果 `property_value` 是 String 类型, 尝试用 `JSON.parse_string()` 解析为 Dictionary/Array

```gdscript
var actual_value: Variant = property_value
if property_value is String:
    var parsed: Variant = JSON.parse_string(property_value)
    if parsed != null:
        actual_value = parsed
var converted_value: Variant = _convert_value_for_property(target_node, property_name, actual_value)
```

**验证**: `position = {"x": 10, "y": 5, "z": 3}` 成功设置为 `(10.0, 5.0, 3.0)`

---

## 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `native_mcp/mcp_server_core.gd` | 添加 structuredContent, 修复 isError |
| `native_mcp/mcp_http_server.gd` | 修复 Content-Length 字节数, 添加 charset=utf-8, 分离 header/body 字节 |
| `tools/script_tools_native.gd` | 改用 get_as_text() 读取文件 |
| `tools/debug_tools_native.gd` | 绑定 Godot 单例到 Expression |
| `tools/node_tools_native.gd` | 添加 _make_friendly_path, 过滤分组属性(128/64/256), 修复 property_value JSON 字符串解析 |
| `tools/scene_tools_native.gd` | 添加 _make_friendly_path |
| `tools/editor_tools_native.gd` | 添加 _make_friendly_path |
| `tools/project_tools_native.gd` | 扩展资源扩展名列表 |

---

## Trae CN 客户端兼容性

### 根因分析

Trae CN MCP 客户端日志 (`MCP Servers Host.log`) 显示:

```
[error] MCPServerManager#callTool (get_editor_state) failed: 
  Tool get_editor_state has an output schema but did not return structured content
```

**根因**: MCP 协议 2025-03-26+ 规定, 当工具定义了 `outputSchema` 时, 响应中必须包含 `structuredContent` 字段。我们的服务器只返回了 `content` (text 格式), 缺少 `structuredContent`, 导致 Trae CN 客户端无法解析工具结果, 显示为 `[]`。

**修复**: 在 `_handle_tool_call()` 中, 当工具有 `output_schema` 时添加 `structuredContent` 字段, 值为工具返回的原始 Dictionary。

---

## 待验证项 (需重启 Godot 编辑器)

以下修复需要重启 Godot 编辑器才能生效:

1. **read_script 中文编码** - Content-Length 字节数修复 + get_as_text() 改用
2. **get_node_properties 分组过滤** - PROPERTY_USAGE_CATEGORY 过滤
3. **list_project_resources** - 扩展名列表扩展

---

## 测试中创建的临时文件

以下文件是测试过程中创建的, 需要手动清理:

| 文件路径 | 用途 |
|----------|------|
| `res://test_mcp_created.gd` | create_script / modify_script 测试 |
| `res://test_mcp_curve.tres` | create_resource 测试 |
| `res://test_mcp_scene.tscn` | create_scene 测试 |

---

## 附录: 测试命令示例

```bash
# 测试 get_project_info
curl.exe -s -X POST http://localhost:9080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"get_project_info","arguments":{}},"id":1}'

# 测试 create_node
curl.exe -s -X POST http://localhost:9080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"create_node","arguments":{"parent_path":"/root/Node3D","node_type":"Node3D","node_name":"TestNode"}},"id":2}'

# 测试 execute_script (含单例访问)
curl.exe -s -X POST http://localhost:9080/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"execute_script","arguments":{"code":"OS.get_name()"}},"id":3}'
```
