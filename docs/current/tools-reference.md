# 工具参考手册

本手册详细说明 Godot-MCP 项目的所有 42+ 个 MCP 工具，包括参数、返回值和使用示例。

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

Godot-MCP 实现了 **42+ 个工具**，分为 6 大类：

| 类别 | 工具数量 | 用途 |
|------|----------|------|
| [Node Tools](#node-tools) | 6 | 节点管理（创建、删除、修改属性） |
| [Script Tools](#script-tools) | 5 | 脚本管理（读取、创建、修改） |
| [Scene Tools](#scene-tools) | 6 | 场景管理（创建、保存、打开） |
| [Editor Tools](#editor-tools) | 5 | 编辑器操作（运行、停止、获取状态） |
| [Debug Tools](#debug-tools) | 4+ | 调试和日志 |
| [Project Tools](#project-tools) | 3 | 项目配置（信息、设置） |

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
    "status": "success",
    "data": { }
  },
  "id": 1
}
```

**错误响应**：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "error",
    "message": "Error description"
  },
  "id": 1
}
```

---

## Node Tools

### 1. create_node

在指定父节点下创建新节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `parent_path` | string | 是 | 父节点的路径（如 `/root/Player`） |
| `node_type` | string | 是 | 节点类型（如 `Node2D`、`Sprite2D`、`CollisionShape2D`） |
| `node_name` | string | 是 | 新节点的名称 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `node_path` | string | 新节点的完整路径 |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "create_node",
    "arguments": {
      "parent_path": "/root",
      "node_type": "Node2D",
      "node_name": "Player"
    }
  },
  "id": 1
}
```

**响应**：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "success",
    "node_path": "/root/Player",
    "message": "Node created: Player"
  },
  "id": 1
}
```

**错误情况**：
- 父节点路径无效 → 返回 `"status": "error"`, `"message": "Parent node not found"`
- 节点类型无效 → 返回 `"status": "error"`, `"message": "Invalid node type"`
- 节点名称已存在 → 返回 `"status": "error"`, `"message": "Node name already exists"`

---

### 2. delete_node

删除指定节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 要删除的节点路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "delete_node",
    "arguments": {
      "node_path": "/root/Player"
    }
  },
  "id": 2
}
```

---

### 3. update_node_property

更新节点的属性值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `property_name` | string | 是 | 属性名称（如 `position`、`rotation`、`visible`） |
| `property_value` | variant | 是 | 新的属性值 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "update_node_property",
    "arguments": {
      "node_path": "/root/Player",
      "property_name": "position",
      "property_value": {"x": 100, "y": 200}
    }
  },
  "id": 3
}
```

**注意**：
- 属性名称必须是 Godot 节点的有效属性
- 属性值必须与属性类型匹配
- 支持常见类型：`int`、`float`、`String`、`Vector2`、`Vector3`、`Color`、`bool`

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
| `status` | string | `"success"` 或 `"error"` |
| `properties` | Dictionary | 节点的所有属性键值对 |
| `node_type` | string | 节点类型 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_node_properties",
    "arguments": {
      "node_path": "/root/Player"
    }
  },
  "id": 4
}
```

**响应**：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "success",
    "node_type": "Node2D",
    "properties": {
      "position": {"x": 0, "y": 0},
      "rotation": 0.0,
      "scale": {"x": 1, "y": 1},
      "visible": true,
      "name": "Player"
    }
  },
  "id": 4
}
```

---

### 5. list_nodes

列出指定父节点下的所有子节点。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `parent_path` | string | 是 | 父节点路径 |
| `recursive` | boolean | 否 | 是否递归列出所有子节点（默认 `false`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `nodes` | Array[Dictionary] | 节点信息数组 |
| `count` | int | 节点数量 |

**每个节点信息包含**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `name` | string | 节点名称 |
| `type` | string | 节点类型 |
| `path` | string | 节点完整路径 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_nodes",
    "arguments": {
      "parent_path": "/root",
      "recursive": true
    }
  },
  "id": 5
}
```

---

### 6. get_scene_tree

获取当前场景的完整节点树。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `scene_tree` | Dictionary | 场景树结构（嵌套） |
| `root_node` | string | 根节点名称 |

**场景树结构**：
```json
{
  "name": "root",
  "type": "Node",
  "children": [
    {
      "name": "Player",
      "type": "Node2D",
      "children": []
    }
  ]
}
```

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_scene_tree",
    "arguments": {}
  },
  "id": 6
}
```

---

## Script Tools

### 7. list_project_scripts

列出项目中的所有脚本文件。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `scripts` | Array[string] | 脚本文件路径数组 |
| `count` | int | 脚本数量 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_project_scripts",
    "arguments": {}
  },
  "id": 7
}
```

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
| `status` | string | `"success"` 或 `"error"` |
| `content` | string | 脚本内容 |
| `line_count` | int | 行数 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "read_script",
    "arguments": {
      "script_path": "res://scripts/player.gd"
    }
  },
  "id": 8
}
```

---

### 9. create_script

创建新脚本文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |
| `template` | string | 否 | 脚本模板（`empty`、`node2d`、`area2d`等） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `script_path` | string | 创建的脚本路径 |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "create_script",
    "arguments": {
      "script_path": "res://scripts/enemy.gd",
      "template": "node2d"
    }
  },
  "id": 9
}
```

---

### 10. modify_script

修改现有脚本的内容。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |
| `mode` | string | 是 | 修改模式（`append`、`prepend`、`replace`、`insert_after`） |
| `content` | string | 是 | 要添加或修改的内容 |
| `line_number` | int | 否 | 行号（当 `mode=insert_after` 时使用） |

**修改模式**：
- `append`：在文件末尾追加
- `prepend`：在文件开头插入
- `replace`：替换整个文件
- `insert_after`：在指定行后插入

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "modify_script",
    "arguments": {
      "script_path": "res://scripts/player.gd",
      "mode": "append",
      "content": "\nfunc _ready():\n    print('Player ready')\n"
    }
  },
  "id": 10
}
```

---

### 11. analyze_script

分析脚本的代码结构（函数、变量、信号等）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `functions` | Array[string] | 函数列表 |
| `variables` | Array[string] | 成员变量列表 |
| `signals` | Array[string] | 信号列表 |
| `dependencies` | Array[string] | 依赖的脚本/类 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "analyze_script",
    "arguments": {
      "script_path": "res://scripts/player.gd"
    }
  },
  "id": 11
}
```

---

## Scene Tools

### 12. create_scene

创建新场景文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径（如 `res://scenes/level1.tscn`） |
| `root_type` | string | 是 | 根节点类型（如 `Node2D`、`Node3D`、`Control`） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `scene_path` | string | 创建的场景路径 |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "create_scene",
    "arguments": {
      "scene_path": "res://scenes/level1.tscn",
      "root_type": "Node2D"
    }
  },
  "id": 12
}
```

---

### 13. save_scene

保存当前打开的场景。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `scene_path` | string | 保存的场景路径 |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "save_scene",
    "arguments": {}
  },
  "id": 13
}
```

---

### 14. open_scene

打开指定场景文件。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `scene_path` | string | 打开的场景路径 |
| `root_node` | string | 根节点名称 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "open_scene",
    "arguments": {
      "scene_path": "res://scenes/level1.tscn"
    }
  },
  "id": 14
}
```

---

### 15. get_current_scene

获取当前打开的场景信息。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `scene_path` | string | 当前场景路径 |
| `root_node` | string | 根节点名称 |
| `node_count` | int | 节点总数 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_current_scene",
    "arguments": {}
  },
  "id": 15
}
```

---

### 16. get_scene_structure

获取指定场景的文件结构（不打开场景）。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `structure` | Dictionary | 场景结构（类似 `get_scene_tree` 的返回值） |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_scene_structure",
    "arguments": {
      "scene_path": "res://scenes/level1.tscn"
    }
  },
  "id": 16
}
```

---

### 17. list_project_scenes

列出项目中的所有场景文件。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `scenes` | Array[string] | 场景文件路径数组 |
| `count` | int | 场景数量 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_project_scenes",
    "arguments": {}
  },
  "id": 17
}
```

---

## Editor Tools

### 18. get_editor_state

获取 Godot Editor 的当前状态。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `current_scene` | string | 当前打开的场景路径 |
| `selected_nodes` | Array[string] | 选中的节点路径列表 |
| `editor_mode` | string | 编辑器模式（`2d`、`3d`、`script`、`assetlib`） |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_editor_state",
    "arguments": {}
  },
  "id": 18
}
```

---

### 19. run_project

运行当前项目（Play 按钮）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "run_project",
    "arguments": {}
  },
  "id": 19
}
```

---

### 20. stop_project

停止运行项目（Stop 按钮）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "stop_project",
    "arguments": {}
  },
  "id": 20
}
```

---

### 21. get_selected_nodes

获取当前选中的节点列表。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `selected_nodes` | Array[string] | 选中的节点路径列表 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_selected_nodes",
    "arguments": {}
  },
  "id": 21
}
```

---

### 22. set_editor_setting

修改 Godot Editor 的设置。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `setting_path` | string | 是 | 设置路径（如 `interface/editor/display_scale`） |
| `value` | variant | 是 | 新的设置值 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `message` | string | 成功或错误消息 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "set_editor_setting",
    "arguments": {
      "setting_path": "interface/editor/display_scale",
      "value": 1.25
    }
  },
  "id": 22
}
```

---

## Debug Tools

### 23. get_editor_logs

获取 Godot Editor 的输出日志。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `lines` | int | 否 | 要获取的日志行数（默认 50） |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `logs` | Array[string] | 日志行数组 |
| `count` | int | 日志行数 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_editor_logs",
    "arguments": {
      "lines": 100
    }
  },
  "id": 23
}
```

---

### 24. execute_script

在编辑器中执行 GDScript 代码。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `script_code` | string | 是 | 要执行的 GDScript 代码 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `output` | string | 执行输出 |
| `error` | string | 错误信息（如果有） |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "execute_script",
    "arguments": {
      "script_code": "print('Hello from AI')\nreturn 42"
    }
  },
  "id": 24
}
```

**注意**：此工具仅用于调试，不应执行不受信任的代码。

---

### 25. get_performance_metrics

获取项目运行的性能数据（FPS、内存、节点数等）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `fps` | float | 当前帧率 |
| `memory_usage` | int | 内存使用量（字节） |
| `node_count` | int | 节点总数 |
| `draw_calls` | int | 绘制调用次数 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_performance_metrics",
    "arguments": {}
  },
  "id": 25
}
```

---

### 26. debug_print

在 Godot Editor 输出面板中打印调试信息。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `message` | string | 是 | 要打印的消息 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "debug_print",
    "arguments": {
      "message": "AI debugging: Checking player position"
    }
  },
  "id": 26
}
```

---

## Project Tools

### 27. get_project_info

获取项目的基本信息。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `name` | string | 项目名称 |
| `version` | string | 项目版本 |
| `description` | string | 项目描述 |
| `author` | string | 作者 |
| `godot_version` | string | Godot 版本 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_project_info",
    "arguments": {}
  },
  "id": 27
}
```

**响应**：
```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "success",
    "name": "My Game",
    "version": "1.0",
    "description": "A 2D platformer game",
    "author": "Your Name",
    "godot_version": "4.3.stable"
  },
  "id": 27
}
```

---

### 28. get_project_settings

获取项目的设置值。

**参数**：
| 参数 | 类型 | 必需 | 描述 |
|------|------|------|------|
| `setting_path` | string | 否 | 设置路径（如 `display/window/size/viewport_width`）。如果省略，返回所有设置 |

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `settings` | Dictionary | 设置键值对 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "get_project_settings",
    "arguments": {
      "setting_path": "display/window/size"
    }
  },
  "id": 28
}
```

---

### 29. list_project_resources

列出项目中的所有资源文件（纹理、音频、模型等）。

**参数**：无

**返回值**：
| 字段 | 类型 | 描述 |
|------|------|------|
| `status` | string | `"success"` 或 `"error"` |
| `resources` | Array[string] | 资源文件路径数组 |
| `count` | int | 资源数量 |

**示例**：
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "list_project_resources",
    "arguments": {}
  },
  "id": 29
}
```

---

## 通用数据类型

### Vector2

```json
{
  "x": 0.0,
  "y": 0.0
}
```

### Vector3

```json
{
  "x": 0.0,
  "y": 0.0,
  "z": 0.0
}
```

### Color

```json
{
  "r": 1.0,
  "g": 1.0,
  "b": 1.0,
  "a": 1.0
}
```

### Rect2

```json
{
  "position": {"x": 0, "y": 0},
  "size": {"x": 100, "y": 100}
}
```

---

## 错误处理

### 常见错误代码

| 错误代码 | 描述 | 解决方案 |
|----------|------|----------|
| `node_not_found` | 节点路径无效 | 检查节点路径是否正确 |
| `invalid_node_type` | 节点类型不存在 | 使用 `ClassDB.class_exists()` 验证 |
| `script_not_found` | 脚本文件不存在 | 检查文件路径是否正确 |
| `scene_not_found` | 场景文件不存在 | 检查场景路径是否正确 |
| `invalid_argument` | 参数类型或值无效 | 检查参数格式和范围 |
| `permission_denied` | 权限不足（安全级别限制） | 降低 `security_level` 或修改操作 |
| `rate_limit_exceeded` | 超出速率限制 | 降低请求频率 |

### 错误响应示例

```json
{
  "jsonrpc": "2.0",
  "result": {
    "status": "error",
    "error_code": "node_not_found",
    "message": "Node not found: /root/NonExistent",
    "suggestion": "Use list_nodes to see available nodes"
  },
  "id": 1
}
```

---

## 总结

本手册详细说明了 Godot-MCP 项目的所有 42+ 个工具。每个工具都有清晰的参数说明、返回值描述和使用示例。

**提示**：
- 使用 `tools/list` 方法获取所有工具的实时列表
- 每个工具的完整 JSON Schema 可以通过 `tools/list` 的返回值查看
- 在实际使用中，建议先测试工具调用，确保参数正确

如有任何问题或建议，欢迎在 GitHub Issues 中提出。

**Happy Coding！** 🚀
