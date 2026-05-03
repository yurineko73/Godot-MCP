# 工具参考手册

本手册详细说明 Godot-MCP 项目的所有 MCP 工具，包括参数、返回值和使用示例。

## 目录

1. [工具概述](#工具概述)
2. [Node Tools](#node-tools)
3. [Script Tools](#script-tools)
4. [Scene Tools](#scene-tools)
5. [Editor Tools](#editor-tools)
6. [Debug Tools](#debug-tools)
7. [Project Tools](#project-tools)
8. [通用数据类型](#通用数据类型)
9. [错误处理](#错误处理)

---

## 工具概述

Godot-MCP 实现了 **33 个工具**，分为 6 大类：

| 类别 | 工具数量 | 源文件 | 用途 |
|------|----------|--------|------|
| [Node Tools](#node-tools) | 6 | `node_tools_native.gd` | 节点管理（创建、删除、修改属性） |
| [Script Tools](#script-tools) | 6 | `script_tools_native.gd` | 脚本管理（读取、创建、修改、分析） |
| [Scene Tools](#scene-tools) | 6 | `scene_tools_native.gd` | 场景管理（创建、保存、打开） |
| [Editor Tools](#editor-tools) | 5 | `editor_tools_native.gd` | 编辑器操作（运行、停止、获取状态） |
| [Debug Tools](#debug-tools) | 5 | `debug_tools_native.gd` | 调试和日志 |
| [Project Tools](#project-tools) | 5 | `project_tools_native.gd` | 项目配置（信息、设置、结构） |

### 工具调用格式

```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "<tool_name>",
    "arguments": {
      "<param1>": "<value1>",
      "<param2>": "<value2>"
    }
  },
  "id": 1
}
```

### 通用响应格式

**成功响应**：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{...}"
      }
    ],
    "structuredContent": { }
  },
  "id": 1
}
```

**错误响应**（通过 `structuredContent` 中的 `error` 字段标识）：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"error\": \"Error description\"}"
      }
    ],
    "structuredContent": {
      "error": "Error description"
    }
  },
  "id": 1
}
```

### 工具注解 (Annotations)

每个工具都包含 MCP 标准注解，帮助客户端理解工具的行为：

| 注解 | 含义 |
|------|------|
| `readOnlyHint` | `true` 表示工具不会修改任何状态 |
| `destructiveHint` | `true` 表示工具可能造成不可逆的修改 |
| `idempotentHint` | `true` 表示相同参数重复调用结果一致 |
| `openWorldHint` | `true` 表示工具可能影响超出参数范围的状态 |

---

## Node Tools

### 1. create_node

在指定父节点下创建新节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `parent_path` | string | 是 | 父节点的路径（如 `/root/MainScene`） |
| `node_type` | string | 是 | 节点类型（如 `Node2D`、`Sprite2D`、`CharacterBody2D`） |
| `node_name` | string | 是 | 新节点的名称 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 新节点的友好路径（如 `/root/MainScene/Player`） |
| `node_type` | string | 实际创建的节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 2. delete_node

删除指定节点。此操作不可撤销。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 要删除的节点路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `deleted_node` | string | 被删除节点的名称 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

---

### 3. update_node_property

更新节点的属性值。支持 Undo/Redo（通过 `EditorUndoRedoManager`）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `property_name` | string | 是 | 属性名称（如 `position`、`visible`、`modulate`） |
| `property_value` | variant | 是 | 新的属性值（支持自动类型转换） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `node_path` | string | 节点路径 |
| `property_name` | string | 属性名称 |
| `old_value` | string | 修改前的值（字符串形式） |
| `new_value` | string | 修改后的值（字符串形式） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**值类型转换**：
- `Vector2` / `Vector2i`：传入 `{"x": 1, "y": 2}` 或字符串 `"(1, 2)"`
- `Vector3` / `Vector3i`：传入 `{"x": 1, "y": 2, "z": 3}` 或字符串 `"(1, 2, 3)"`
- `Color`：传入 `{"r": 1, "g": 0, "b": 0, "a": 1}` 或 `"#ff0000"`
- `bool`：传入 `true`/`false` 或字符串 `"true"`/`"false"`
- 字符串值会自动尝试 `JSON.parse_string()` 解析

---

### 4. get_node_properties

获取节点的所有属性。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `node_path` | string | 节点路径 |
| `node_type` | string | 节点类型 |
| `properties` | Dictionary | 节点的所有属性键值对（已序列化） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

**属性过滤规则**：
- 跳过 `__` 前缀的内部属性
- 跳过 `CATEGORY`(128)、`GROUP`(64)、`SUBGROUP`(256) 用途的属性
- `Vector2`/`Vector3`/`Color` 等类型自动序列化为 Dictionary

---

### 5. list_nodes

列出指定父节点下的所有子节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `parent_path` | string | 否 | 父节点路径。默认列出当前场景所有节点 |
| `recursive` | boolean | 否 | 是否递归列出所有子节点（默认 `true`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `nodes` | Array[string] | 节点友好路径数组 |
| `count` | int | 节点数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 6. get_scene_tree

获取当前场景的完整节点树。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_depth` | int | 否 | 最大遍历深度。`-1` 表示无限制（默认 `-1`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_name` | string | 场景名称 |
| `tree` | Dictionary | 场景树结构（嵌套） |
| `total_nodes` | int | 节点总数 |

**场景树节点结构**：
```json
{
  "name": "Player",
  "type": "Node2D",
  "path": "/root/MainScene/Player",
  "child_count": 2,
  "properties": {
    "visible": true,
    "position": {"x": 100, "y": 200}
  },
  "children": [...]
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## Script Tools

### 7. list_project_scripts

列出项目中的所有 GDScript 文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径（如 `res://scripts/`）。默认 `res://` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scripts` | Array[string] | 脚本文件路径数组 |
| `count` | int | 脚本数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 8. read_script

读取指定脚本的内容。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径（如 `res://scripts/player.gd`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_path` | string | 脚本路径 |
| `content` | string | 脚本完整内容 |
| `line_count` | int | 行数 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 9. create_script

创建新脚本文件，支持模板和自动附加到节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径（如 `res://scripts/player.gd`） |
| `content` | string | 否 | 初始内容。如不提供，使用模板 |
| `template` | string | 否 | 模板名称：`empty`（默认）、`node`、`characterbody2d`、`characterbody3d` |
| `attach_to_node` | string | 否 | 创建后自动附加到此节点路径（如 `/root/MainScene/Player`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `script_path` | string | 创建的脚本路径 |
| `line_count` | int | 行数 |
| `attached_to` | string | 附加到的节点路径（仅当 `attach_to_node` 成功时） |
| `attach_warning` | string | 附加警告信息（仅当附加失败时） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 10. modify_script

修改现有脚本的内容。支持全量替换和单行替换。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |
| `content` | string | 是 | 新内容（全量替换或单行内容） |
| `line_number` | int | 否 | 行号（1-indexed）。提供时仅替换该行，否则全量替换 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `script_path` | string | 脚本路径 |
| `line_count` | int | 修改后的行数 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

---

### 11. analyze_script

分析脚本的代码结构。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_path` | string | 脚本路径 |
| `has_class_name` | boolean | 是否声明了 `class_name` |
| `extends_from` | string | 继承的基类 |
| `language` | string | 脚本语言：`gdscript`、`csharp` 或 `unknown` |
| `functions` | Array[string] | 函数名列表 |
| `signals` | Array[string] | 信号名列表 |
| `properties` | Array[string] | 公有属性名列表（跳过 `_` 前缀的私有变量） |
| `line_count` | int | 行数 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 12. get_current_script

获取编辑器中当前正在编辑的脚本。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `script_found` | boolean | 是否找到正在编辑的脚本 |
| `script_path` | string | 脚本路径（仅当 `script_found=true`） |
| `content` | string | 脚本完整内容（仅当 `script_found=true`） |
| `line_count` | int | 行数（仅当 `script_found=true`） |
| `message` | string | 说明信息（仅当 `script_found=false`） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## Scene Tools

### 13. create_scene

创建新场景文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径（如 `res://scenes/level1.tscn`） |
| `root_node_type` | string | 否 | 根节点类型（默认 `Node`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `scene_path` | string | 创建的场景路径 |
| `root_node_type` | string | 根节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 14. save_scene

保存当前打开的场景。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `file_path` | string | 否 | 保存路径。如不提供，保存到当前场景路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `saved_path` | string | 保存的场景路径 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### 15. open_scene

打开指定场景文件。会关闭当前打开的场景。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `scene_path` | string | 打开的场景路径 |
| `root_node_type` | string | 根节点类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`

---

### 16. get_current_scene

获取当前打开的场景信息。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_name` | string | 场景名称 |
| `scene_path` | string | 场景文件路径 |
| `root_node_type` | string | 根节点类型 |
| `node_count` | int | 节点总数 |
| `is_modified` | boolean | 场景是否有未保存的修改 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 17. get_scene_structure

获取当前场景的完整树结构。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_depth` | int | 否 | 最大遍历深度。`-1` 表示无限制（默认 `-1`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scene_name` | string | 场景名称 |
| `root_node` | Dictionary | 根节点树结构（嵌套） |
| `total_nodes` | int | 节点总数 |

**节点结构**：
```json
{
  "name": "Player",
  "type": "Node2D",
  "path": "/root/MainScene/Player",
  "children": [...]
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 18. list_project_scenes

列出项目中的所有场景文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径（如 `res://scenes/`）。默认 `res://` |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `scenes` | Array[string] | 场景文件路径数组 |
| `count` | int | 场景数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## Editor Tools

### 19. get_editor_state

获取 Godot Editor 的当前状态。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `active_scene` | string | 当前打开的场景名称 |
| `selected_nodes` | Array[string] | 选中的节点路径列表 |
| `editor_mode` | string | 编辑器模式 |
| `selected_count` | int | 选中节点数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 20. run_project

运行当前项目（Play 按钮）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 否 | 指定要运行的场景路径。如不提供，运行主场景 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `mode` | string | `"playing"` |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 21. stop_project

停止运行项目（Stop 按钮）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `mode` | string | `"editor"` |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### 22. get_selected_nodes

获取当前选中的节点列表（含类型和脚本信息）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `selected_nodes` | Array[Dictionary] | 选中的节点信息数组 |
| `count` | int | 选中节点数量 |

**每个节点信息包含**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `path` | string | 节点的友好路径 |
| `type` | string | 节点类型（如 `Node2D`、`Sprite2D`） |
| `script_path` | string | 附加脚本的路径（仅当节点有脚本时） |

**示例响应**：
```json
{
  "selected_nodes": [
    {
      "path": "/root/MainScene/Player",
      "type": "CharacterBody2D",
      "script_path": "res://scripts/player.gd"
    }
  ],
  "count": 1
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 23. set_editor_setting

修改 Godot Editor 的设置。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `setting_name` | string | 是 | 设置名称（如 `interface/theme/accent_color`） |
| `setting_value` | variant | 是 | 新的设置值 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `setting_name` | string | 设置名称 |
| `old_value` | string | 修改前的值 |
| `new_value` | string | 修改后的值 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

**注意**：部分设置需要重启编辑器才能生效。

---

## Debug Tools

### 24. get_editor_logs

获取编辑器或运行时日志。支持过滤、分页和排序。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `source` | string | 否 | 日志源：`mcp`（MCP 服务器日志，默认）或 `runtime`（`user://logs/godot.log`） |
| `type` | Array[string] | 否 | 按类型过滤（如 `["Error", "Warning"]`）。仅对 MCP 源有效。空数组返回所有 |
| `count` | int | 否 | 返回的最大日志条数（默认 `100`） |
| `offset` | int | 否 | 跳过的日志条数（默认 `0`） |
| `order` | string | 否 | 排序：`desc`（最新优先，默认）或 `asc`（最旧优先） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `logs` | Array[Dictionary] | 日志条目数组 |
| `count` | int | 返回的日志条数 |
| `total_available` | int | 可用日志总数 |
| `source` | string | 日志源 |

**每条日志条目**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `index` | int | 日志索引 |
| `type` | string | 日志类型：`Error`、`Warning`、`Info`、`Debug` |
| `message` | string | 日志内容 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 25. execute_script

在编辑器中执行 GDScript 表达式。使用 Godot 的 `Expression` 类进行安全求值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `code` | string | 是 | GDScript 表达式代码 |
| `bind_objects` | Dictionary | 否 | 额外绑定到表达式的对象 |

**内置绑定单例**：`OS`、`Engine`、`ProjectSettings`、`Input`、`Time`、`JSON`、`ClassDB`、`Performance`、`ResourceLoader`、`ResourceSaver`、`EditorInterface`

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `result` | string | 执行结果（字符串形式） |
| `error` | string | 错误信息（仅失败时） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

**限制**：仅支持表达式求值，不支持多行语句、循环、条件判断和 `await`。

---

### 26. get_performance_metrics

获取项目运行的性能数据。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `fps` | float | 当前帧率 |
| `object_count` | int | 对象总数 |
| `resource_count` | int | 资源总数 |
| `memory_usage_mb` | float | 静态内存使用量（MB） |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 27. debug_print

在 Godot Editor 输出面板中打印调试信息。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `message` | string | 是 | 要打印的消息 |
| `category` | string | 否 | 消息分类标签（如 `MCP`、`AI`、`Debug`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `printed_message` | string | 实际打印的完整消息（含分类前缀） |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=true`

---

### 28. execute_editor_script

在编辑器上下文中执行完整的 GDScript 脚本。与 `execute_script` 不同，此工具支持多行语句、循环、条件判断等。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `code` | string | 是 | 完整的 GDScript 代码 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `success` | boolean | 是否执行成功 |
| `output` | Array[string] | 执行输出 |
| `error` | string | 错误信息（仅失败时） |

**注解**：`readOnlyHint=false`, `destructiveHint=true`, `idempotentHint=false`, `openWorldHint=true`

**特性**：
- 支持多行脚本、循环、条件判断
- 自动捕获 `print()` 输出
- 可访问 `edited_scene`（当前编辑的场景根节点）
- 脚本编译失败会返回明确的错误信息

**示例**：
```json
{
  "name": "execute_editor_script",
  "arguments": {
    "code": "var scene = edited_scene\nif scene:\n    _custom_print(scene.name)\n    _custom_print(str(scene.get_child_count()) + ' children')\nelse:\n    _custom_print('No scene open')"
  }
}
```

---

## Project Tools

### 29. get_project_info

获取项目的基本信息。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `project_name` | string | 项目名称 |
| `project_version` | string | 项目版本 |
| `project_description` | string | 项目描述 |
| `main_scene` | string | 主场景路径（自动解析 ResourceUID） |
| `project_path` | string | 项目在文件系统中的绝对路径 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 30. get_project_settings

获取项目的设置值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `filter` | string | 否 | 设置路径前缀过滤（如 `display/`、`input/`）。不提供则返回所有设置 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `settings` | Dictionary | 设置键值对（值均为字符串形式） |
| `count` | int | 设置数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 31. list_project_resources

列出项目中的所有资源文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `search_path` | string | 否 | 搜索子路径。默认 `res://` |
| `resource_types` | Array[string] | 否 | 文件扩展名过滤（如 `[".tres", ".png"]`）。不提供则返回所有常见资源类型 |

**默认搜索的扩展名**：`.tres`, `.res`, `.png`, `.jpg`, `.webp`, `.ogg`, `.wav`, `.mp3`, `.obj`, `.glb`, `.gltf`, `.material`, `.shader`, `.gdshader`, `.tscn`, `.gd`, `.cfg`, `.json`, `.ttf`, `.otf` 等

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `resources` | Array[string] | 资源文件路径数组 |
| `count` | int | 资源数量 |

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

### 32. create_resource

创建新的 Godot 资源文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `resource_path` | string | 是 | 资源保存路径（如 `res://resources/my_curve.tres`） |
| `resource_type` | string | 是 | 资源类型（如 `Curve`、`Gradient`、`StyleBoxFlat`、`Animation`） |
| `properties` | Dictionary | 否 | 要设置的属性键值对 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` |
| `resource_path` | string | 资源路径 |
| `resource_type` | string | 资源类型 |

**注解**：`readOnlyHint=false`, `destructiveHint=false`, `idempotentHint=false`

---

### 33. get_project_structure

获取项目的目录结构和文件类型统计。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `max_depth` | int | 否 | 最大目录遍历深度（默认 `3`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `directories` | Array[string] | 目录路径列表 |
| `file_counts` | Dictionary | 按扩展名统计的文件数量（如 `{"gd": 15, "tscn": 8}`） |
| `total_files` | int | 文件总数 |
| `total_directories` | int | 目录总数 |

**示例响应**：
```json
{
  "directories": ["res://", "res://addons/", "res://scenes/"],
  "file_counts": {"gd": 15, "tscn": 8, "png": 23},
  "total_files": 46,
  "total_directories": 3
}
```

**注解**：`readOnlyHint=true`, `destructiveHint=false`, `idempotentHint=true`

---

## 通用数据类型

### Vector2

```json
{"x": 0.0, "y": 0.0}
```

### Vector2i

```json
{"x": 0, "y": 0}
```

### Vector3

```json
{"x": 0.0, "y": 0.0, "z": 0.0}
```

### Vector3i

```json
{"x": 0, "y": 0, "z": 0}
```

### Vector4

```json
{"x": 0.0, "y": 0.0, "z": 0.0, "w": 0.0}
```

### Color

```json
{"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}
```

### Rect2

```json
{"x": 0, "y": 0, "w": 100, "h": 100}
```

### Transform2D

```json
{
  "rotation": 0.0,
  "origin": {"x": 0.0, "y": 0.0}
}
```

---

## 错误处理

### 错误响应格式

工具调用失败时，`structuredContent` 中会包含 `error` 字段：

```json
{
  "error": "Node not found: /root/NonExistent"
}
```

### 常见错误

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| `"Editor interface not available"` | 编辑器接口未注入 | 确保插件已正确加载 |
| `"Parent node not found: ..."` | 节点路径无效 | 使用 `list_nodes` 查看可用节点 |
| `"Invalid node type: ..."` | 节点类型不存在 | 使用 `ClassDB.class_exists()` 验证 |
| `"Node not found: ..."` | 节点路径无效 | 检查节点路径是否正确 |
| `"Property '...' not found on node ..."` | 属性不存在 | 使用 `get_node_properties` 查看可用属性 |
| `"Missing required parameter: ..."` | 缺少必需参数 | 检查参数是否完整 |
| `"Invalid path: ..."` | 路径安全验证失败 | 确保路径以 `res://` 开头且不包含 `..` |
| `"File not found: ..."` | 文件不存在 | 检查文件路径是否正确 |
| `"File already exists: ..."` | 文件已存在 | 使用不同的路径或先删除现有文件 |
| `"Failed to open file: ..."` | 文件无法打开 | 检查文件权限 |
| `"Invalid resource type: ..."` | 资源类型不存在 | 使用 `ClassDB.class_exists()` 验证 |
| `"Scene operation in progress, please retry"` | 场景操作锁 | 等待当前操作完成后重试 |
| `"No scene is currently open"` | 没有打开的场景 | 先使用 `open_scene` 打开场景 |
| `"Script compilation failed. Check syntax."` | 脚本编译失败 | 检查 GDScript 语法 |

### 路径安全 (PathValidator)

所有文件和目录路径都经过 `PathValidator` 验证：

- 路径必须以 `res://` 开头
- 不允许包含 `..`（防止路径遍历）
- 文件路径会验证扩展名（如 `.gd`、`.tscn`、`.tres`）
- 路径会被清理和规范化

---

## 总结

本手册详细说明了 Godot-MCP 项目的所有 33 个工具。每个工具都有清晰的参数说明、返回值描述和注解信息。

**提示**：
- 使用 `tools/list` 方法获取所有工具的实时列表和完整 JSON Schema
- 关注每个工具的注解（`readOnlyHint`、`destructiveHint` 等）来理解工具的行为
- `update_node_property` 支持 Undo/Redo，可通过 `Ctrl+Z` 撤销
- `execute_editor_script` 适合复杂脚本执行，`execute_script` 适合简单表达式求值
- 所有文件路径都经过 `PathValidator` 安全验证
