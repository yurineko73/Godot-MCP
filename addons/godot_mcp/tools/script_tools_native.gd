# script_tools_native.gd - Script Tools原生实现（简化版）
# 根据godot-dev-guide添加完整的类型提示

@tool
class_name ScriptToolsNative
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
	_register_list_project_scripts(server_core)
	_register_read_script(server_core)
	_register_create_script(server_core)
	_register_modify_script(server_core)
	_register_analyze_script(server_core)
	_register_get_current_script(server_core)

# ============================================================================
# list_project_scripts - 列出所有脚本
# ============================================================================

func _register_list_project_scripts(server_core: RefCounted) -> void:
	var tool_name: String = "list_project_scripts"
	var description: String = "List all GDScript files (.gd) in the project. Returns paths relative to res://."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"search_path": {
				"type": "string",
				"description": "Optional subpath to search (e.g. 'res://scripts/'). Default is 'res://'.",
				"default": "res://"
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scripts": {
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
						  Callable(self, "_tool_list_project_scripts"),
						  output_schema, annotations)

func _tool_list_project_scripts(params: Dictionary) -> Dictionary:
	# 参数提取
	var search_path: String = params.get("search_path", "res://")
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_directory_path(search_path)
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	search_path = validation["sanitized"]
	
	# 使用DirAccess递归查找所有.gd文件
	var scripts: Array = []
	_collect_scripts(search_path, scripts)
	
	# 排序
	scripts.sort()
	
	return {
		"scripts": scripts,
		"count": scripts.size()
	}

# 辅助函数：递归收集脚本文件
func _collect_scripts(directory_path: String, result: Array) -> void:
	var dir: DirAccess = DirAccess.open(directory_path)
	
	if not dir:
		return
	
	# 列出所有文件和目录
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while not file_name.is_empty():
		# 跳过特殊目录
		if file_name != "." and file_name != "..":
			var full_path: String = directory_path
			if not full_path.ends_with("/"):
				full_path += "/"
			full_path += file_name
			
			if dir.current_is_dir():
				# 递归处理子目录
				_collect_scripts(full_path, result)
			elif file_name.ends_with(".gd"):
				# 添加脚本文件
				result.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# ============================================================================
# read_script - 读取脚本内容
# ============================================================================

func _register_read_script(server_core: RefCounted) -> void:
	var tool_name: String = "read_script"
	var description: String = "Read the content of a GDScript file (.gd). Returns the complete script source code."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file (e.g. 'res://scripts/player.gd')"
			}
		},
		"required": ["script_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {"type": "string"},
			"content": {"type": "string"},
			"line_count": {"type": "integer"}
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
						  Callable(self, "_tool_read_script"),
						  output_schema, annotations)

func _tool_read_script(params: Dictionary) -> Dictionary:
	# 参数提取
	var script_path: String = params.get("script_path", "")
	
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	script_path = validation["sanitized"]
	
	# 验证文件是否存在
	
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	
	if not file:
		return {"error": "Failed to open file: " + script_path}
	
	# 读取内容
	var content: String = file.get_as_text()
	file.close()

	var line_count: int = content.split("\n").size()
	
	return {
		"script_path": script_path,
		"content": content,
		"line_count": line_count
	}

# ============================================================================
# create_script - 创建新脚本
# ============================================================================

func _register_create_script(server_core: RefCounted) -> void:
	var tool_name: String = "create_script"
	var description: String = "Create a new GDScript file with optional template. GDScript files are complete programs, not resource files."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path where the script will be saved (e.g. 'res://scripts/player.gd')"
			},
			"content": {
				"type": "string",
				"description": "Optional initial content for the script. If not provided, creates an empty script."
			},
			"template": {
				"type": "string",
				"description": "Optional template to use: 'empty', 'node', 'characterbody2d', 'characterbody3d', 'area2d', 'area3d'. Default is 'empty'."
			},
			"attach_to_node": {
				"type": "string",
				"description": "Optional node path to attach the script to after creation (e.g. '/root/MainScene/Player')."
			}
		},
		"required": ["script_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"script_path": {"type": "string"},
			"line_count": {"type": "integer"}
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
						  Callable(self, "_tool_create_script"),
						  output_schema, annotations)

func _tool_create_script(params: Dictionary) -> Dictionary:
	var script_path: String = params.get("script_path", "")
	var content: String = params.get("content", "")
	var template: String = params.get("template", "empty")
	var attach_to_node: String = params.get("attach_to_node", "")

	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}

	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}

	script_path = validation["sanitized"]

	if FileAccess.file_exists(script_path):
		return {"error": "File already exists: " + script_path}

	if content.is_empty():
		content = _get_script_template(template)

	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to create file: " + script_path}

	file.store_string(content)
	file.close()

	var line_count: int = content.split("\n").size()
	var result: Dictionary = {
		"status": "success",
		"script_path": script_path,
		"line_count": line_count
	}

	if not attach_to_node.is_empty():
		var editor_interface: EditorInterface = _get_editor_interface()
		if editor_interface:
			var node: Node = _resolve_node_path(editor_interface, attach_to_node)
			if node:
				var script_res: Script = load(script_path)
				if script_res:
					node.set_script(script_res)
					result["attached_to"] = attach_to_node
					editor_interface.get_resource_filesystem().scan()
				else:
					result["attach_warning"] = "Script created but failed to load for attachment"
			else:
				result["attach_warning"] = "Node not found: " + attach_to_node
		else:
			result["attach_warning"] = "Editor interface not available for script attachment"

	return result

func _resolve_node_path(editor_interface: EditorInterface, path: String) -> Node:
	var edited_scene: Node = editor_interface.get_edited_scene_root()
	if not edited_scene:
		return null
	if path == str(edited_scene.get_path()) or path == "/root/" + edited_scene.name:
		return edited_scene
	if path.begins_with("/root/" + edited_scene.name + "/"):
		var relative: String = path.substr(("/root/" + edited_scene.name + "/").length())
		return edited_scene.get_node_or_null(relative)
	return edited_scene.get_node_or_null(path)

# 辅助函数：获取脚本模板
func _get_script_template(template_name: String) -> String:
	if template_name == "node":
		return """@tool
extends Node

# Called when the node enters the scene tree
func _ready() -> void:
	pass

# Called every frame
func _process(delta: float) -> void:
	pass
"""
	elif template_name == "characterbody2d":
		return """@tool
extends CharacterBody2D

func _physics_process(delta: float) -> void:
	move_and_slide()
"""
	elif template_name == "characterbody3d":
		return """@tool
extends CharacterBody3D

func _physics_process(delta: float) -> void:
	move_and_slide()
"""
	else:
		return ""

# ============================================================================
# modify_script - 修改脚本内容
# ============================================================================

func _register_modify_script(server_core: RefCounted) -> void:
	var tool_name: String = "modify_script"
	var description: String = "Modify the content of an existing GDScript file. Can replace entire content or specific lines."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file to modify (e.g. 'res://scripts/player.gd')"
			},
			"content": {
				"type": "string",
				"description": "New content for the script (full replacement)"
			},
			"line_number": {
				"type": "integer",
				"description": "Optional line number to replace (1-indexed). If provided with 'content', replaces that line only."
			}
		},
		"required": ["script_path", "content"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"script_path": {"type": "string"},
			"line_count": {"type": "integer"}
		}
	}
	
	# annotations - destructiveHint = true
	var annotations: Dictionary = {
		"readOnlyHint": false,
		"destructiveHint": true,  # 会覆盖文件
		"idempotentHint": false,
		"openWorldHint": false
	}
	
	# 注册工具
	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_modify_script"),
						  output_schema, annotations)

func _tool_modify_script(params: Dictionary) -> Dictionary:
	# 参数提取
	var script_path: String = params.get("script_path", "")
	var new_content: String = params.get("content", "")
	var line_number: int = params.get("line_number", 0)
	
	# 参数验证
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}
	if new_content.is_empty():
		return {"error": "Missing required parameter: content"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	script_path = validation["sanitized"]
	
	# 验证文件是否存在
	if not FileAccess.file_exists(script_path):
		return {"error": "File not found: " + script_path}
	
	# 读取现有内容
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file for reading: " + script_path}
	
	var existing_lines: Array = []
	while not file.eof_reached():
		existing_lines.append(file.get_line())
	file.close()
	
	# 修改内容
	var final_content: String
	
	if line_number > 0 and line_number <= existing_lines.size():
		# 替换特定行
		existing_lines[line_number - 1] = new_content
		final_content = "\n".join(existing_lines)
	else:
		# 全量替换
		final_content = new_content
	
	# 写入文件
	file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to open file for writing: " + script_path}
	
	file.store_string(final_content)
	file.close()
	
	# 计算行数
	var line_count: int = final_content.split("\n").size()
	
	return {
		"status": "success",
		"script_path": script_path,
		"line_count": line_count
	}

# ============================================================================
# analyze_script - 分析脚本结构（完整版）
# ============================================================================

func _register_analyze_script(server_core: RefCounted) -> void:
	var tool_name: String = "analyze_script"
	var description: String = "Analyze the structure of a GDScript file. Returns functions, signals, properties, and more."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {
				"type": "string",
				"description": "Path to the script file to analyze (e.g. 'res://scripts/player.gd')"
			}
		},
		"required": ["script_path"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_path": {"type": "string"},
			"has_class_name": {"type": "boolean"},
			"extends_from": {"type": "string"},
			"functions": {"type": "array", "items": {"type": "string"}},
			"signals": {"type": "array", "items": {"type": "string"}},
			"properties": {"type": "array", "items": {"type": "string"}},
			"line_count": {"type": "integer"}
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
						  Callable(self, "_tool_analyze_script"),
						  output_schema, annotations)

func _tool_analyze_script(params: Dictionary) -> Dictionary:
	# 参数提取
	var script_path: String = params.get("script_path", "")
	
	# 参数验证
	if script_path.is_empty():
		return {"error": "Missing required parameter: script_path"}
	
	# 使用PathValidator验证路径安全性
	var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
	if not validation["valid"]:
		return {"error": "Invalid path: " + validation["error"]}
	
	# 使用清理后的路径
	script_path = validation["sanitized"]
	
	# 验证文件是否存在
	var line_count: int = 0
	var has_class_name: bool = false
	var extends_from: String = ""
	var functions: Array = []
	var signals: Array = []
	var properties: Array = []
	
	# 读取文件内容
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file: " + script_path}
	
	while not file.eof_reached():
		var line: String = file.get_line()
		line_count += 1
		
		# 简单解析
		var trimmed: String = line.strip_edges()
		
		if trimmed.begins_with("class_name "):
			has_class_name = true
		elif trimmed.begins_with("extends ") and extends_from.is_empty():
			extends_from = trimmed.split(" ")[1]
		elif trimmed.begins_with("func "):
			# 提取函数名
			var func_name: String = trimmed.replace("func ", "").split("(")[0]
			functions.append(func_name)
		elif trimmed.begins_with("signal "):
			var signal_name: String = trimmed.replace("signal ", "").split("(")[0]
			signals.append(signal_name)
		elif trimmed.begins_with("var ") and not trimmed.begins_with("var _"):
			var var_part: String = trimmed.replace("var ", "").split(":")[0].split("=")[0].strip_edges()
			if not var_part.is_empty():
				properties.append(var_part)
	
	file.close()
	
	return {
		"script_path": script_path,
		"has_class_name": has_class_name,
		"extends_from": extends_from,
		"language": "gdscript" if script_path.ends_with(".gd") else "csharp" if script_path.ends_with(".cs") else "unknown",
		"functions": functions,
		"signals": signals,
		"properties": properties,
		"line_count": line_count
	}

# ============================================================================
# get_current_script - 获取当前正在编辑的脚本
# ============================================================================

func _register_get_current_script(server_core: RefCounted) -> void:
	var tool_name: String = "get_current_script"
	var description: String = "Get the script currently being edited in the Godot script editor. Returns the script path and content."

	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}

	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"script_found": {"type": "boolean"},
			"script_path": {"type": "string"},
			"content": {"type": "string"},
			"line_count": {"type": "integer"}
		}
	}

	var annotations: Dictionary = {
		"readOnlyHint": true,
		"destructiveHint": false,
		"idempotentHint": true,
		"openWorldHint": false
	}

	server_core.register_tool(tool_name, description, input_schema,
						  Callable(self, "_tool_get_current_script"),
						  output_schema, annotations)

func _tool_get_current_script(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"script_found": false, "message": "Editor interface not available"}

	var script_editor: ScriptEditor = editor_interface.get_script_editor()
	if not script_editor:
		return {"script_found": false, "message": "Script editor not available"}

	var current_script: Script = script_editor.get_current_script()
	if not current_script:
		return {"script_found": false, "message": "No script is currently being edited in the script editor"}

	var script_path: String = current_script.resource_path
	if script_path.is_empty():
		return {"script_found": false, "message": "Current script has no file path (may be a built-in script)"}

	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"script_found": false, "message": "Failed to open script file: " + script_path}

	var content: String = file.get_as_text()
	file.close()

	var line_count: int = content.split("\n").size()

	return {
		"script_found": true,
		"script_path": script_path,
		"content": content,
		"line_count": line_count
	}
