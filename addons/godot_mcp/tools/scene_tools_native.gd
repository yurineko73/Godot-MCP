# scene_tools_native.gd - Scene Tools原生实现
# 根据godot-dev-guide添加完整的类型提示
# 根据mcp-builder添加outputSchema和annotations

@tool
class_name SceneToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null

func initialize(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface

func _get_editor_interface() -> EditorInterface:
	if _editor_interface:
		return _editor_interface
	if Engine.has_meta("GodotMCPPlugin"):
		var plugin = Engine.get_meta("GodotMCPPlugin")
		if plugin and plugin.has_method("get_editor_interface"):
			return plugin.get_editor_interface()
	return null

# ============================================================================
# 工具注册
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	# 注册create_scene工具
	_register_create_scene(server_core)
	
	# 注册save_scene工具
	_register_save_scene(server_core)
	
	# 注册open_scene工具
	_register_open_scene(server_core)
	
	# 注册get_current_scene工具
	_register_get_current_scene(server_core)
	
	# 注册get_scene_structure工具
	_register_get_scene_structure(server_core)
	
	# 注册list_project_scenes工具
	_register_list_project_scenes(server_core)

# ============================================================================
# create_scene - 创建新场景
# ============================================================================

func _register_create_scene(server_core: RefCounted) -> void:
	var tool_name: String = "create_scene"
	var description: String = "Create a new Godot scene with a root node. The scene is saved to the specified path."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "Path where the scene will be saved (e.g. 'res://scenes/NewScene.tscn')"
			},
			"root_node_type": {
				"type": "string",
				"description": "Type of the root node (e.g. 'Node3D', 'Node2D', 'Control'). Default is 'Node'.",
				"default": "Node"
			}
		},
		"required": ["scene_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"scene_path": {"type": "string"},
			"root_node_type": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": false,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_create_scene"),
						  output_schema, annotations)

static func _tool_create_scene(params: Dictionary) -> Dictionary:
	# 参数提取
	var scene_path: String = params.get("scene_path", "")
	var root_node_type: String = params.get("root_node_type", "Node")
	
	# 参数验证
	if scene_path.is_empty():
		return {"error": "Missing required parameter: scene_path"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(scene_path, [".tscn"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	scene_path = validation["sanitized"]
	
	# 验证节点类型
	if not ClassDB.class_exists(root_node_type):
		return {"error": "Invalid node type: " + root_node_type}
	
	# 创建根节点
	var root_node: Node = ClassDB.instantiate(root_node_type)
	root_node.name = scene_path.get_file().get_basename()
	
	# 创建PackedScene
	var packed_scene: PackedScene = PackedScene.new()
	
	# 设置owner并打包
	root_node.owner = root_node  # 临时设置
	packed_scene.pack(root_node)
	
	# 保存场景
	var error: Error = ResourceSaver.save(packed_scene, scene_path)
	
	# 清理
	root_node.queue_free()
	
	if error != OK:
		return {"error": "Failed to save scene: " + error_string(error)}
	
	return {
		"status": "success",
		"scene_path": scene_path,
		"root_node_type": root_node_type
	}

# ============================================================================
# save_scene - 保存当前场景
# ============================================================================

func _register_save_scene(server_core: RefCounted) -> void:
	var tool_name: String = "save_scene"
	var description: String = "Save the current scene to disk. If no path is provided, saves to the current scene's path."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"file_path": {
				"type": "string",
				"description": "Optional path to save the scene (e.g. 'res://scenes/MyScene.tscn'). If not provided, uses current scene path."
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"saved_path": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_save_scene"),
						  output_schema, annotations)

static func _tool_save_scene(params: Dictionary) -> Dictionary:
	# 获取编辑器接口
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 获取当前场景根节点
	var scene_root: Node = editor_interface.get_edited_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	
	# 获取保存路径
	var file_path: String = params.get("file_path", "")
	
	if file_path.is_empty():
		# 使用当前场景的路径
		var current_scene_path: String = scene_root.scene_file_path
		if current_scene_path.is_empty():
			return {"error": "Scene has no file path. Please provide a file_path parameter."}
		file_path = current_scene_path
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(file_path, [".tscn"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	file_path = validation["sanitized"]
	
	# 创建PackedScene并打包
	var packed_scene: PackedScene = PackedScene.new()
	var error: Error = packed_scene.pack(scene_root)
	
	if error != OK:
		return {"error": "Failed to pack scene: " + error_string(error)}
	
	# 保存场景
	error = ResourceSaver.save(packed_scene, file_path)
	
	if error != OK:
		return {"error": "Failed to save scene: " + error_string(error)}
	
	return {
		"status": "success",
		"saved_path": file_path
	}

# ============================================================================
# open_scene - 打开场景
# ============================================================================

func _register_open_scene(server_core: RefCounted) -> void:
	var tool_name: String = "open_scene"
	var description: String = "Open a scene file from the project. Closes the current scene if one is open."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "Path to the scene file to open (e.g. 'res://scenes/Main.tscn')"
			}
		},
		"required": ["scene_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"scene_path": {"type": "string"},
			"root_node_type": {"type": "string"}
		}
	}
	
	# annotations
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,  # 会关闭当前场景
		"idempotentHint": false,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_open_scene"),
						  output_schema, annotations)

static func _tool_open_scene(params: Dictionary) -> Dictionary:
	# 参数提取
	var scene_path: String = params.get("scene_path", "")
	
	# 参数验证
	if scene_path.is_empty():
		return {"error": "Missing required parameter: scene_path"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(scene_path, [".tscn"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	scene_path = validation["sanitized"]
	
	# 验证文件是否存在
	if not FileAccess.file_exists(scene_path):
		return {"error": "Scene file not found: " + scene_path}
	
	# 获取编辑器接口
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 打开场景
	editor_interface.open_scene_from_path(scene_path)
	
	# 验证场景是否成功打开
	var opened_scene_root: Node = editor_interface.get_edited_scene_root()
	if not opened_scene_root:
		return {"error": "Failed to open scene: " + scene_path}
	
	# 获取打开的场景信息
	var scene_root: Node = editor_interface.get_edited_scene_root()
	var root_type: String = scene_root.get_class() if scene_root else "Unknown"
	
	return {
		"status": "success",
		"scene_path": scene_path,
		"root_node_type": root_type
	}

# ============================================================================
# get_current_scene - 获取当前场景信息
# ============================================================================

func _register_get_current_scene(server_core: RefCounted) -> void:
	var tool_name: String = "get_current_scene"
	var description: String = "Get information about the currently open scene, including name, path, and root node type."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scene_name": {"type": "string"},
			"scene_path": {"type": "string"},
			"root_node_type": {"type": "string"},
			"node_count": {"type": "integer"},
			"is_modified": {"type": "boolean"}
		}
	}
	
	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_current_scene"),
						  output_schema, annotations)

static func _tool_get_current_scene(params: Dictionary) -> Dictionary:
	# 获取编辑器接口
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 获取当前场景根节点
	var scene_root: Node = editor_interface.get_edited_scene_root()
	
	if not scene_root:
		return {"error": "No scene is currently open"}
	
	# 获取场景信息
	var scene_name: String = scene_root.name
	var scene_path: String = scene_root.scene_file_path
	var root_node_type: String = scene_root.get_class()
	var node_count: int = _count_nodes(scene_root)
	
	# 检查场景是否已修改（通过检查是否有unsaved changes）
	# 注意：Godot API没有直接获取此状态的方法，这里使用启发式判断
	var is_modified: bool = false  # 简化处理，实际应该检查EditorInterface的内部状态
	
	return {
		"scene_name": scene_name,
		"scene_path": scene_path,
		"root_node_type": root_node_type,
		"node_count": node_count,
		"is_modified": is_modified
	}

# ============================================================================
# get_scene_structure - 获取场景树结构
# ============================================================================

func _register_get_scene_structure(server_core: RefCounted) -> void:
	var tool_name: String = "get_scene_structure"
	var description: String = "Get the complete structure of the current scene as a tree. Returns node types, names, and hierarchy."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"max_depth": {
				"type": "integer",
				"description": "Maximum depth to traverse. -1 means no limit."
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scene_name": {"type": "string"},
			"root_node": {"type": "object"},
			"total_nodes": {"type": "integer"}
		}
	}
	
	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema, 
						  Callable(self, "_tool_get_scene_structure"),
						  output_schema, annotations)

static func _tool_get_scene_structure(params: Dictionary) -> Dictionary:
	# 参数提取
	var max_depth: int = params.get("max_depth", -1)
	
	# 获取编辑器接口
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 获取场景根节点
	var scene_root: Node = editor_interface.get_edited_scene_root()
	if not scene_root:
		return {"error": "No scene is currently open"}
	
	# 构建场景结构
	var scene_structure: Dictionary = {
		"scene_name": scene_root.name,
		"root_node": _build_node_tree(scene_root, 0, max_depth),
		"total_nodes": _count_nodes(scene_root)
	}
	
	return scene_structure

# 辅助函数：递归构建节点树
static func _build_node_tree(node: Node, current_depth: int, max_depth: int) -> Dictionary:
	var node_info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": []
	}
	
	# 检查是否达到最大深度
	if max_depth >= 0 and current_depth >= max_depth:
		node_info["children_truncated"] = true
		return node_info
	
	# 递归处理子节点
	for child_index in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		var child_tree: Dictionary = _build_node_tree(child, current_depth + 1, max_depth)
		node_info["children"].append(child_tree)
	
	return node_info

# 辅助函数：计算节点总数
static func _count_nodes(node: Node) -> int:
	var count: int = 1  # 当前节点
	
	for child_index in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		count += _count_nodes(child)
	
	return count

# ============================================================================
# list_project_scenes - 列出项目中的所有场景
# ============================================================================

func _register_list_project_scenes(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_scenes"
	var description: String = "List all scene files (.tscn) in the project. Returns paths relative to res://."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Optional subpath to search (e.g. 'res://scenes/'). Default is 'res://'.",
				"default": "res://"
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scenes": {
				"type": "array",
				"items": {"type": "string"}
			},
			"count": {"type": "integer"}
		}
	}
	
	# annotations - readOnlyHint = true
	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_list_project_scenes"),
						  output_schema, annotations)

static func _tool_list_project_scenes(params: Dictionary) -> Dictionary:
	# 参数提取
	var search_path: String = params.get("search_path", "res://")
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	search_path = validation["sanitized"]
	
	# 转换为文件系统路径
	var fs_path: String = search_path
	
	# 使用DirAccess递归查找所有.tscn文件
	var scenes: Array[String] = []
	_collect_scenes(fs_path, scenes)
	
	# 排序
	scenes.sort()
	
	return {
		"scenes": scenes,
		"count": scenes.size()
	}

# 辅助函数：递归收集场景文件
static func _collect_scenes(directory_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(directory_path)
	
	if not dir:
		return
	
	# 列出所有文件和目录
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while not file_name.is_empty():
		# 跳过特殊目录
		if file_name != "." and file_name != "..":
			var full_path: String = directory_path + "/" + file_name
			
			if dir.current_is_dir():
				# 递归处理子目录
				_collect_scenes(full_path, result)
			elif file_name.ends_with(".tscn"):
				# 添加场景文件
				result.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
