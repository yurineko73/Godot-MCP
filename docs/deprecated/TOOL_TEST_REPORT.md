# Godot Native MCP 工具测试报告

**测试日期**: 2026-05-01
**测试环境**: Windows 11, Godot 4.6.1-stable, Trae IDE MCP Client
**测试方法**: 通过 MCP 客户端调用每个工具，检查 `user://mcp_all_responses.log` 累积日志验证实际返回数据
**参考文档**: `docs/current/tools-reference-native.md`
**修复轮次**: 第 3 轮（最终验证）

---

## 测试结果总览

| 分类 | 工具数量 | 第1轮通过 | 第2轮通过 | 第3轮通过 |
|------|---------|-----------|-----------|-----------|
| **Node Tools** | 6 | 3 (50%) | 6 (100%) | 6 (100%) |
| **Script Tools** | 5 | 0 (0%) | 5 (100%) | 5 (100%) |
| **Scene Tools** | 6 | 1 (17%) | 6 (100%) | 6 (100%) |
| **Editor Tools** | 5 | 0 (0%) | 5 (100%) | 5 (100%) |
| **Debug Tools** | 4 | 2 (50%) | 4 (100%) | 4 (100%) |
| **Project Tools** | 4 | 2 (50%) | 4 (100%) | 4 (100%) |
| **总计** | **30** | **8 (26.7%)** | **30 (100%)** | **30 (100%)** |

---

## 第3轮测试详细结果

### Node Tools - 6/6 通过 ✅

| # | 工具名 | 结果 | 验证详情 |
|---|--------|------|----------|
| 1 | create_node | ✅ | node_path=/root/Node3D/TestNode2D, node_type=Node2D |
| 2 | delete_node | ✅ | deleted_node=TestNode2D |
| 3 | update_node_property | ✅ | position 属性设置成功，类型转换 Dictionary→Vector2 工作正常 |
| 4 | get_node_properties | ✅ | node_type=Node2D, properties=55keys |
| 5 | list_nodes | ✅ | count=6 |
| 6 | get_scene_tree | ✅ | scene_name=Node3D, total_nodes=6 |

### Script Tools - 5/5 通过 ✅

| # | 工具名 | 结果 | 验证详情 |
|---|--------|------|----------|
| 7 | list_project_scripts | ✅ | count=30, 路径格式正确 (res://addons/...) |
| 8 | read_script | ✅ | 返回完整脚本内容, line_count=578 |
| 9 | create_script | ✅ | script_path=res://test_v3_final_script.gd, line_count=11 |
| 10 | modify_script | ✅ | script_path=res://test_v3_final_script.gd, line_count=1 |
| 11 | analyze_script | ✅ | functions=18, has_class_name=True, extends_from=RefCounted |

### Scene Tools - 6/6 通过 ✅

| # | 工具名 | 结果 | 验证详情 |
|---|--------|------|----------|
| 12 | list_project_scenes | ✅ | count=9 |
| 13 | open_scene | ✅ | root_node_type=Node3D, scene_path=res://TestScene.tscn |
| 14 | get_current_scene | ✅ | scene_name=Node3D, root_node_type=Node3D, node_count=5 |
| 15 | get_scene_structure | ✅ | scene_name=Node3D, total_nodes=5 |
| 16 | save_scene | ✅ | saved_path=res://TestScene.tscn |
| 17 | create_scene | ✅ | scene_path=res://test_v3_final_scene.tscn, root_node_type=Node3D |

### Editor Tools - 5/5 通过 ✅

| # | 工具名 | 结果 | 验证详情 |
|---|--------|------|----------|
| 18 | get_editor_state | ✅ | active_scene=Node3D, editor_mode=editor |
| 19 | get_selected_nodes | ✅ | count=1 |
| 20 | set_editor_setting | ✅ | accent_color old=(0.337,0.62,1.0,1.0) new=0.5 |
| 21 | run_project | ✅ | mode=playing |
| 22 | stop_project | ✅ | mode=editor |

### Debug Tools - 4/4 通过 ✅

| # | 工具名 | 结果 | 验证详情 |
|---|--------|------|----------|
| 23 | get_editor_logs | ✅ | count=100, total_available=123 |
| 24 | execute_script | ✅ | result=3 (1+2=3) |
| 25 | get_performance_metrics | ✅ | fps=105, memory_usage_mb=1293, object_count=85854 |
| 26 | debug_print | ✅ | printed_message=[VERIFY] Final verification complete |

### Project Tools - 4/4 通过 ✅

| # | 工具名 | 结果 | 验证详情 |
|---|--------|------|----------|
| 27 | get_project_info | ✅ | project_name=Godot MCP, main_scene=res://TestScene.tscn |
| 28 | get_project_settings | ✅ | count=36 settings |
| 29 | list_project_resources | ✅ | count=30 resources |
| 30 | create_resource | ✅ | resource_type=Curve, resource_path=res://test_v3_final_curve.tres |

---

## 全部修复的 Bug 列表

### 第1-2轮修复的 Bug

| Bug ID | 描述 | 修复文件 |
|--------|------|----------|
| BUG-1 | PathValidator `//` 模式误判 | `utils/path_validator.gd` |
| BUG-2 | 静态方法中 Engine.get_meta 空引用崩溃 | `scene_tools_native.gd`, `editor_tools_native.gd` |
| BUG-3 | 场景定位错误 (MCP面板 vs 用户场景) | `node_tools_native.gd`, `scene_tools_native.gd`, `editor_tools_native.gd` |
| BUG-4 | 属性值类型转换缺失 | `node_tools_native.gd` |
| BUG-5 | debug_print 输出污染 stdout | `debug_tools_native.gd` |
| BUG-6 | get_editor_logs 返回静态文本 | `debug_tools_native.gd` |
| ISSUE-1 | get_project_info 返回值不准确 | `project_tools_native.gd` |
| ISSUE-2 | set_editor_setting inputSchema 类型错误 | `editor_tools_native.gd` |
| ISSUE-3 | execute_script print 污染 stdout | `debug_tools_native.gd` |
| ISSUE-4 | create_scene queue_free 问题 | `scene_tools_native.gd` |

### 第3轮修复的 Bug

| Bug ID | 描述 | 修复文件 |
|--------|------|----------|
| BUG-7 | execute_script Expression base instance 为 null | `debug_tools_native.gd` |
| BUG-8 | _append_tool_log typeof() as String 崩溃 | `mcp_server_core.gd` |
| BUG-9 | _get_user_scene_root 路径过滤过严 | `node_tools_native.gd`, `scene_tools_native.gd`, `editor_tools_native.gd` |
| BUG-10 | 节点路径解析错误 (用户路径 vs 内部路径) | `node_tools_native.gd` |
| BUG-11 | debug_commands.gd 空格缩进错误 | `commands/debug_commands.gd` |

---

## 第3轮修复详情

### BUG-7: execute_script Expression base instance 为 null

**问题**: `Expression.execute([], null, true)` 传入 null 作为 base instance，导致执行 `self` 相关代码时报错 "Instance is null, cannot use self"

**修复**: 将 `_tool_execute_script` 从 `static func` 改为 `func`，传递 `self` 作为 base instance

**文件**: `addons/godot_mcp/tools/debug_tools_native.gd`

### BUG-8: _append_tool_log typeof() as String 崩溃

**问题**: `typeof(result) as String` 在 GDScript 中无效（typeof 返回 int，不能 as String），导致静默崩溃；`str(val).left(200)` 在 GDScript 4 中不存在

**修复**: `typeof(result) as String` → `str(typeof(result))`；`str(val).left(200)` → `val_str.substr(0, 200)`

**文件**: `addons/godot_mcp/native_mcp/mcp_server_core.gd`

### BUG-9: _get_user_scene_root 路径过滤过严

**问题**: 添加了 `not root_path.contains("@EditorNode")` 检查，但 Godot 编辑器中用户场景根节点的路径总是包含 `@EditorNode`（场景在编辑器视口子树中），导致所有场景相关工具返回 "No scene is currently open"

**修复**: 移除路径中的 `@EditorNode` 和 `@Panel` 检查，只检查节点名称不以 `@` 开头且类型不是 `PanelContainer`

**文件**: `addons/godot_mcp/tools/node_tools_native.gd`, `addons/godot_mcp/tools/scene_tools_native.gd`, `addons/godot_mcp/tools/editor_tools_native.gd`

### BUG-10: 节点路径解析错误

**问题**: 用户传入 `/root/Node3D/TestNode2D`，但场景根节点 `Node3D` 的实际路径是 `/root/@EditorNode@.../Node3D`，`scene_root.get_node_or_null("Node3D/TestNode2D")` 会查找 `Node3D` 的子节点 `Node3D/TestNode2D`，找不到

**修复**: 添加 `_resolve_node_path()` 辅助方法，自动将用户路径中的场景根名称映射到实际场景根节点，然后查找相对路径

**文件**: `addons/godot_mcp/tools/node_tools_native.gd`

### BUG-11: debug_commands.gd 空格缩进错误

**问题**: 第111行之后使用了空格缩进而不是 Tab，导致 GDScript 解析错误

**修复**: 将空格缩进替换为 Tab 缩进

**文件**: `addons/godot_mcp/commands/debug_commands.gd`

---

## 修改文件完整清单

| 文件 | 修改内容 |
|------|---------|
| `utils/path_validator.gd` | 移除 `//` 危险模式，重写 `_sanitize_path()`，修复 `validate_directory_path()` |
| `tools/scene_tools_native.gd` | static→实例方法，添加 `_get_user_scene_root()`，`queue_free`→`free`，路径拼接修复 |
| `tools/editor_tools_native.gd` | static→实例方法，添加 `_get_user_scene_root()`，inputSchema 修复 |
| `tools/node_tools_native.gd` | 添加 `_get_user_scene_root()`，添加 `_convert_value_for_property()`，添加 `_resolve_node_path()`，友好路径返回 |
| `tools/debug_tools_native.gd` | 日志缓存实现，`print`→`printerr`，execute_script base instance 修复 |
| `tools/project_tools_native.gd` | `get_project_info` 返回值修复，路径拼接修复 |
| `tools/script_tools_native.gd` | 路径拼接修复 |
| `native_mcp/mcp_server_core.gd` | 错误响应格式修复（`isError: true`），累积响应日志，_append_tool_log 修复 |
| `commands/debug_commands.gd` | 空格缩进→Tab 缩进修复 |

---

**文档版本**: 3.0
**最后更新**: 2026-05-01
