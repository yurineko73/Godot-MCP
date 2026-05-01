# Godot Native MCP 工具参考手册

## 简介

本文档详细说明了 Godot Native MCP 服务器提供的所有 MCP 工具。每个工具都包含：
- **功能描述**
- **输入参数**
- **返回结果**
- **使用示例**
- **可能错误**

---

## 工具分类

| 分类 | 工具数量 | 说明 |
|------|---------|------|
| **Node Tools** | 6 | 节点操作工具 |
| **Script Tools** | 5 | 脚本操作工具 |
| **Scene Tools** | 6 | 场景操作工具 |
| **Editor Tools** | 5 | 编辑器操作工具 |
| **Debug Tools** | 4 | 调试工具 |
| **Project Tools** | 4 | 项目操作工具 |
| **总计** | **30** | |

---

## Node Tools（节点工具）

### 1. `create_node`

**功能描述**：在指定父节点下创建新节点。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `parent_path` | string | 是 | 父节点路径（如 `/root/Main`） |
| `node_type` | string | 是 | 节点类型（如 `Node2D`、`CharacterBody2D`） |
| `node_name` | string | 是 | 新节点名称 |

**返回结果**：
```json
{
  "status": "success",
  "node_path": "/root/Main/Player",
  "node_type": "CharacterBody2D"
}
```

**使用示例**：
```json
{
  "tool": "create_node",
  "arguments": {
    "parent_path": "/root/Main",
    "node_type": "CharacterBody2D",
    "node_name": "Player"
  }
}
```

**可能错误**：
- `Parent node not found`：父节点路径不存在
- `Invalid node type`：节点类型不存在
- `Path traversal detected`：路径包含遍历攻击向量

---

### 2. `delete_node`

**功能描述**：删除指定路径的节点。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `node_path` | string | 是 | 要删除的节点路径 |

**返回结果**：
```json
{
  "status": "success",
  "deleted_node": "/root/Main/Enemy1"
}
```

**使用示例**：
```json
{
  "tool": "delete_node",
  "arguments": {
    "node_path": "/root/Main/Enemy1"
  }
}
```

**可能错误**：
- `Node not found`：节点路径不存在
- `Cannot delete root`：不能删除根节点
- `Path traversal detected`：路径包含遍历攻击向量

---

### 3. `update_node_property`

**功能描述**：更新节点的属性值。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `node_path` | string | 是 | 节点路径 |
| `property_name` | string | 是 | 属性名称（如 `position`、`visible`） |
| `property_value` | any | 是 | 新的属性值 |

**返回结果**：
```json
{
  "status": "success",
  "node_path": "/root/Main/Player",
  "property": "position",
  "old_value": "(0, 0)",
  "new_value": "(100, 50)"
}
```

**使用示例**：
```json
{
  "tool": "update_node_property",
  "arguments": {
    "node_path": "/root/Main/Player",
    "property_name": "position",
    "property_value": "(100, 50)"
  }
}
```

**可能错误**：
- `Node not found`：节点路径不存在
- `Property not found`：属性不存在
- `Invalid value type`：值类型不正确

---

### 4. `get_node_properties`

**功能描述**：获取节点的所有属性值。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `node_path` | string | 是 | 节点路径 |

**返回结果**：
```json
{
  "status": "success",
  "node_path": "/root/Main/Player",
  "properties": {
    "position": "(100, 50)",
    "visible": true,
    "name": "Player"
  }
}
```

**使用示例**：
```json
{
  "tool": "get_node_properties",
  "arguments": {
    "node_path": "/root/Main/Player"
  }
}
```

**可能错误**：
- `Node not found`：节点路径不存在

---

### 5. `list_nodes`

**功能描述**：列出指定节点的所有子节点。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `parent_path` | string | 是 | 父节点路径 |
| `recursive` | boolean | 否 | 是否递归列出所有子节点（默认 false） |

**返回结果**：
```json
{
  "status": "success",
  "parent_path": "/root/Main",
  "nodes": [
    {"name": "Player", "type": "CharacterBody2D", "path": "/root/Main/Player"},
    {"name": "Enemy", "type": "Area2D", "path": "/root/Main/Enemy"}
  ],
  "count": 2
}
```

**使用示例**：
```json
{
  "tool": "list_nodes",
  "arguments": {
    "parent_path": "/root/Main",
    "recursive": true
  }
}
```

**可能错误**：
- `Node not found`：父节点路径不存在

---

### 6. `get_scene_tree`

**功能描述**：获取整个场景树的层级结构。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `max_depth` | integer | 否 | 最大深度（默认 10） |

**返回结果**：
```json
{
  "status": "success",
  "scene_tree": [
    {
      "name": "Main",
      "type": "Node2D",
      "children": [
        {"name": "Player", "type": "CharacterBody2D", "children": []}
      ]
    }
  ]
}
```

**使用示例**：
```json
{
  "tool": "get_scene_tree",
  "arguments": {
    "max_depth": 3
  }
}
```

---

## Script Tools（脚本工具）

### 7. `list_project_scripts`

**功能描述**：列出项目中所有 GDScript 文件。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "scripts": ["res://scripts/player.gd", "res://scripts/enemy.gd"],
  "count": 2
}
```

**使用示例**：
```json
{
  "tool": "list_project_scripts",
  "arguments": {}
}
```

---

### 8. `read_script`

**功能描述**：读取指定脚本文件的内容。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径（如 `res://scripts/player.gd`） |

**返回结果**：
```json
{
  "status": "success",
  "script_path": "res://scripts/player.gd",
  "content": "extends CharacterBody2D\n\nfunc _ready():\n\tpass",
  "line_count": 4
}
```

**使用示例**：
```json
{
  "tool": "read_script",
  "arguments": {
    "script_path": "res://scripts/player.gd"
  }
}
```

**可能错误**：
- `File not found`：脚本文件不存在
- `Invalid file type`：文件不是 .gd 文件

---

### 9. `create_script`

**功能描述**：创建新的 GDScript 文件。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `script_path` | string | 是 | 新脚本文件路径 |
| `content` | string | 否 | 脚本内容（可选） |
| `extends_class` | string | 否 | 继承的基类（如 `Node2D`） |

**返回结果**：
```json
{
  "status": "success",
  "script_path": "res://scripts/new_script.gd",
  "created": true
}
```

**使用示例**：
```json
{
  "tool": "create_script",
  "arguments": {
    "script_path": "res://scripts/new_script.gd",
    "extends_class": "Node2D",
    "content": "extends Node2D\n\nfunc _ready():\n\tprint('Hello')"
  }
}
```

**可能错误**：
- `File already exists`：文件已存在
- `Invalid path`：路径不合法
- `Failed to create file`：文件创建失败

---

### 10. `modify_script`

**功能描述**：修改现有脚本文件的内容。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |
| `content` | string | 是 | 新的脚本内容 |
| `mode` | string | 否 | 修改模式：`replace`（替换）、`append`（追加）（默认 `replace`） |

**返回结果**：
```json
{
  "status": "success",
  "script_path": "res://scripts/player.gd",
  "modified": true,
  "line_count": 10
}
```

**使用示例**：
```json
{
  "tool": "modify_script",
  "arguments": {
    "script_path": "res://scripts/player.gd",
    "content": "extends CharacterBody2D\n\nfunc _ready():\n\tprint('Modified')",
    "mode": "replace"
  }
}
```

**可能错误**：
- `File not found`：脚本文件不存在
- `Failed to write file`：文件写入失败

---

### 11. `analyze_script`

**功能描述**：分析脚本结构（函数、变量、信号等）。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `script_path` | string | 是 | 脚本文件路径 |

**返回结果**：
```json
{
  "status": "success",
  "script_path": "res://scripts/player.gd",
  "analysis": {
    "functions": ["_ready", "_process", "move"],
    "variables": ["speed", "health"],
    "signals": ["died", "health_changed"],
    "classes": ["Player"]
  }
}
```

**使用示例**：
```json
{
  "tool": "analyze_script",
  "arguments": {
    "script_path": "res://scripts/player.gd"
  }
}
```

**可能错误**：
- `File not found`：脚本文件不存在
- `Parse error`：脚本语法错误

---

## Scene Tools（场景工具）

### 12. `create_scene`

**功能描述**：创建新的场景文件。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `scene_path` | string | 是 | 新场景文件路径 |
| `root_type` | string | 否 | 根节点类型（默认 `Node2D`） |

**返回结果**：
```json
{
  "status": "success",
  "scene_path": "res://scenes/new_scene.tscn",
  "created": true
}
```

**使用示例**：
```json
{
  "tool": "create_scene",
  "arguments": {
    "scene_path": "res://scenes/new_scene.tscn",
    "root_type": "Node3D"
  }
}
```

---

### 13. `save_scene`

**功能描述**：保存当前打开的场景。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "saved_path": "res://scenes/main.tscn"
}
```

**使用示例**：
```json
{
  "tool": "save_scene",
  "arguments": {}
}
```

**可能错误**：
- `No scene open`：没有打开的场景
- `Failed to save`：保存失败

---

### 14. `open_scene`

**功能描述**：打开指定场景文件。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `scene_path` | string | 是 | 场景文件路径 |

**返回结果**：
```json
{
  "status": "success",
  "opened_path": "res://scenes/main.tscn"
}
```

**使用示例**：
```json
{
  "tool": "open_scene",
  "arguments": {
    "scene_path": "res://scenes/main.tscn"
  }
}
```

---

### 15. `get_current_scene`

**功能描述**：获取当前打开场景的信息。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "scene_info": {
    "name": "Main",
    "path": "res://scenes/main.tscn",
    "root_type": "Node2D",
    "node_count": 15
  }
}
```

**使用示例**：
```json
{
  "tool": "get_current_scene",
  "arguments": {}
}
```

---

### 16. `get_scene_structure`

**功能描述**：获取当前场景的节点树结构。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `max_depth` | integer | 否 | 最大深度（默认 10） |

**返回结果**：
```json
{
  "status": "success",
  "scene_path": "res://scenes/main.tscn",
  "structure": {
    "name": "Main",
    "type": "Node2D",
    "children": [
      {"name": "Player", "type": "CharacterBody2D", "children": []}
    ]
  }
}
```

**使用示例**：
```json
{
  "tool": "get_scene_structure",
  "arguments": {
    "max_depth": 3
  }
}
```

---

### 17. `list_project_scenes`

**功能描述**：列出项目中所有场景文件。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "scenes": ["res://scenes/main.tscn", "res://scenes/level1.tscn"],
  "count": 2
}
```

**使用示例**：
```json
{
  "tool": "list_project_scenes",
  "arguments": {}
}
```

---

## Editor Tools（编辑器工具）

### 18. `get_editor_state`

**功能描述**：获取 Godot 编辑器当前状态。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "editor_state": {
    "main_screen": "3D",
    "current_scene": "res://scenes/main.tscn",
    "selected_nodes": ["/root/Main/Player"],
    "timestamp": 1714521600
  }
}
```

**使用示例**：
```json
{
  "tool": "get_editor_state",
  "arguments": {}
}
```

---

### 19. `run_project`

**功能描述**：运行当前项目。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "message": "Project running"
}
```

**使用示例**：
```json
{
  "tool": "run_project",
  "arguments": {}
}
```

---

### 20. `stop_project`

**功能描述**：停止运行当前项目。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "message": "Project stopped"
}
```

**使用示例**：
```json
{
  "tool": "stop_project",
  "arguments": {}
}
```

---

### 21. `get_selected_nodes`

**功能描述**：获取当前选中的节点列表。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "selected_nodes": [
    {"path": "/root/Main/Player", "type": "CharacterBody2D"},
    {"path": "/root/Main/Enemy", "type": "Area2D"}
  ],
  "count": 2
}
```

**使用示例**：
```json
{
  "tool": "get_selected_nodes",
  "arguments": {}
}
```

---

### 22. `set_editor_setting`

**功能描述**：设置 Godot 编辑器属性。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `setting_name` | string | 是 | 属性名称 |
| `setting_value` | any | 是 | 属性值 |

**返回结果**：
```json
{
  "status": "success",
  "setting_name": "interface/theme/accent_color",
  "setting_value": "#ff0000"
}
```

**使用示例**：
```json
{
  "tool": "set_editor_setting",
  "arguments": {
    "setting_name": "interface/theme/accent_color",
    "setting_value": "#ff0000"
  }
}
```

---

## Debug Tools（调试工具）

### 23. `get_editor_logs`

**功能描述**：获取 Godot 编辑器日志。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `max_lines` | integer | 否 | 最大行数（默认 100） |

**返回结果**：
```json
{
  "status": "success",
  "logs": [
    {"level": "INFO", "message": "Scene saved successfully"},
    {"level": "WARNING", "message": "Deprecated function used"}
  ],
  "count": 2
}
```

**使用示例**：
```json
{
  "tool": "get_editor_logs",
  "arguments": {
    "max_lines": 50
  }
}
```

---

### 24. `execute_script`

**功能描述**：在编辑器中执行 GDScript 代码。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `code` | string | 是 | 要执行的 GDScript 代码 |

**返回结果**：
```json
{
  "status": "success",
  "result": "Hello from executed script",
  "output": ["print output 1", "print output 2"]
}
```

**使用示例**：
```json
{
  "tool": "execute_script",
  "arguments": {
    "code": "print('Hello from executed script')\nreturn 42"
  }
}
```

**可能错误**：
- `Script execution error`：脚本执行错误
- `Security error`：代码包含危险操作

---

### 25. `get_performance_metrics`

**功能描述**：获取项目性能指标（FPS、内存等）。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "metrics": {
    "fps": 60,
    "memory_usage_mb": 128.5,
    "node_count": 150,
    "draw_calls": 42
  }
}
```

**使用示例**：
```json
{
  "tool": "get_performance_metrics",
  "arguments": {}
}
```

---

### 26. `debug_print`

**功能描述**：在编辑器输出窗口中打印调试信息。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `message` | string | 是 | 要打印的消息 |

**返回结果**：
```json
{
  "status": "success",
  "printed": true
}
```

**使用示例**：
```json
{
  "tool": "debug_print",
  "arguments": {
    "message": "Debug: Player position = (100, 50)"
  }
}
```

---

## Project Tools（项目工具）

### 27. `get_project_info`

**功能描述**：获取 Godot 项目基本信息。

**输入参数**：无

**返回结果**：
```json
{
  "status": "success",
  "project_info": {
    "name": "My Game",
    "version": "1.0",
    "description": "A 2D platformer game",
    "author": "Your Name",
    "godot_version": "4.3"
  }
}
```

**使用示例**：
```json
{
  "tool": "get_project_info",
  "arguments": {}
}
```

---

### 28. `get_project_settings`

**功能描述**：获取项目属性设置。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `category` | string | 否 | 属性类别（如 `application/`、`display/`） |

**返回结果**：
```json
{
  "status": "success",
  "settings": {
    "application/config/name": "My Game",
    "display/window/size/viewport_width": 1920,
    "display/window/size/viewport_height": 1080
  },
  "count": 3
}
```

**使用示例**：
```json
{
  "tool": "get_project_settings",
  "arguments": {
    "category": "application/"
  }
}
```

---

### 29. `list_project_resources`

**功能描述**：列出项目中的所有资源文件。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `extension` | string | 否 | 文件扩展名（如 `.png`、`.mesh`） |

**返回结果**：
```json
{
  "status": "success",
  "resources": ["res://assets/player.png", "res://assets/enemy.png"],
  "count": 2
}
```

**使用示例**：
```json
{
  "tool": "list_project_resources",
  "arguments": {
    "extension": ".png"
  }
}
```

---

### 30. `create_resource`

**功能描述**：创建新的资源文件（如材质、纹理等）。

**输入参数**：
| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `resource_path` | string | 是 | 资源文件路径 |
| `resource_type` | string | 是 | 资源类型（如 `StandardMaterial3D`、`GradientTexture2D`） |

**返回结果**：
```json
{
  "status": "success",
  "resource_path": "res://materials/new_material.tres",
  "created": true
}
```

**使用示例**：
```json
{
  "tool": "create_resource",
  "arguments": {
    "resource_path": "res://materials/new_material.tres",
    "resource_type": "StandardMaterial3D"
  }
}
```

---

## 错误代码参考

| 错误代码 | 说明 |
|---------|------|
| `-32600` | Invalid Request（无效的请求） |
| `-32601` | Method not found（方法不存在） |
| `-32602` | Invalid params（无效的参数） |
| `-32603` | Internal error（内部错误） |
| `-32700` | Parse error（解析错误） |

---

## 安全限制

### 路径白名单

原生实现使用路径白名单机制，仅允许访问以下路径：
- `res://`（项目目录）
- `user://`（用户目录）

任何尝试访问其他路径的操作都会被拒绝，并返回 `Path traversal detected` 错误。

### 危险操作确认

以下操作需要用户确认（如果启用了确认机制）：
- 删除节点（`delete_node`）
- 修改脚本（`modify_script`）
- 删除资源

---

## 性能建议

1. **避免频繁调用 `get_scene_tree`**：对于大型场景，获取完整场景树可能较慢。建议设置合理的 `max_depth` 参数。

2. **使用 `list_nodes` 代替 `get_scene_tree`**：如果只需要查看直接子节点，使用 `list_nodes` 性能更好。

3. **批量操作**：如果需要创建多个节点，尽量批量调用，减少往返次数。

4. **日志级别**：对于大型项目，建议将日志级别设置为 `INFO` 或 `WARN`，避免 `DEBUG` 级别产生大量日志输出。

---

**文档版本**：1.0  
**最后更新**：2026-05-01
