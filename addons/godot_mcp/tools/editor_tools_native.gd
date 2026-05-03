# editor_tools_native.gd - Editor Tools原生实现
# 根据godot-dev-guide添加完整的类型提示

@tool
class_name EditorToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null
var _editor_operation_in_progress: bool = false

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

func _get_user_scene_root() -> Node:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return null
	
	var scene_root: Node = editor_interface.get_edited_scene_root()
	if scene_root and not scene_root.name.begins_with("@") and scene_root.get_class() != "PanelContainer":
		return scene_root
	
	var open_scenes: Array = editor_interface.get_open_scenes()
	for scene in open_scenes:
		if scene and not scene.name.begins_with("@") and scene.get_class() != "PanelContainer":
			return scene
	
	return scene_root

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

# ============================================================================
# 工具注册
# ============================================================================

func register_tools(server_core: RefCounted) -> void:
	# 注册get_editor_state工具
	_register_get_editor_state(server_core)
	
	# 注册run_project工具
	_register_run_project(server_core)
	
	# 注册stop_project工具
	_register_stop_project(server_core)
	
	# 注册get_selected_nodes工具
	_register_get_selected_nodes(server_core)
	
	# 注册set_editor_setting工具
	_register_set_editor_setting(server_core)

# ============================================================================
# get_editor_state - 获取编辑器状态
# ============================================================================

func _register_get_editor_state(server_core: RefCounted) -> void:
	var tool_name: String = "get_editor_state"
	var description: String = "Get the current state of the Godot editor, including active scene and selection info."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"active_scene": {"type": "string"},
			"selected_nodes": {
				"type": "array",
				"items": {"type": "string"}
			},
			"editor_mode": {"type": "string"},
			"viewport_camera": {"type": "object"}
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
						  Callable(self, "_tool_get_editor_state"),
						  output_schema, annotations)

func _tool_get_editor_state(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var scene_root: Node = _get_user_scene_root()
	var active_scene: String = scene_root.name if scene_root else ""
	
	var selected_nodes: Array[String] = []
	var selection: EditorSelection = editor_interface.get_selection()
	if selection:
		var selected: Array[Node] = selection.get_selected_nodes()
		for node in selected:
			selected_nodes.append(_make_friendly_path(node, scene_root))
	
	var editor_mode: String = "editor"
	
	return {
		"active_scene": active_scene,
		"selected_nodes": selected_nodes,
		"editor_mode": editor_mode,
		"selected_count": selected_nodes.size()
	}

# ============================================================================
# run_project - 运行项目
# ============================================================================

func _register_run_project(server_core: RefCounted) -> void:
	var tool_name: String = "run_project"
	var description: String = "Run the current project or a specific scene. Launches the game in play mode."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "Optional path to a specific scene to run. If not provided, runs the main scene."
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"mode": {"type": "string"}
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
						  Callable(self, "_tool_run_project"),
						  output_schema, annotations)

func _tool_run_project(params: Dictionary) -> Dictionary:
	if _editor_operation_in_progress:
		return {"error": "Editor operation in progress, please retry"}
	_editor_operation_in_progress = true
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		_editor_operation_in_progress = false
		return {"error": "Editor interface not available"}
	
	var scene_path: String = params.get("scene_path", "")
	
	if not scene_path.is_empty():
		if not FileAccess.file_exists(scene_path):
			_editor_operation_in_progress = false
			return {"error": "Scene file not found: " + scene_path}
		editor_interface.play_custom_scene(scene_path)
	else:
		editor_interface.play_current_scene()
	
	_editor_operation_in_progress = false
	
	return {
		"status": "success",
		"mode": "playing"
	}

# ============================================================================
# stop_project - 停止运行
# ============================================================================

func _register_stop_project(server_core: RefCounted) -> void:
	var tool_name: String = "stop_project"
	var description: String = "Stop the currently running project and return to editor mode."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"mode": {"type": "string"}
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
						  Callable(self, "_tool_stop_project"),
						  output_schema, annotations)

func _tool_stop_project(params: Dictionary) -> Dictionary:
	if _editor_operation_in_progress:
		return {"error": "Editor operation in progress, please retry"}
	_editor_operation_in_progress = true
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		_editor_operation_in_progress = false
		return {"error": "Editor interface not available"}
	
	editor_interface.stop_playing_scene()
	
	_editor_operation_in_progress = false
	
	return {
		"status": "success",
		"mode": "editor"
	}

# ============================================================================
# get_selected_nodes - 获取选中的节点
# ============================================================================

func _register_get_selected_nodes(server_core: RefCounted) -> void:
	var tool_name: String = "get_selected_nodes"
	var description: String = "Get the list of currently selected nodes in the editor."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"selected_nodes": {
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
						  Callable(self, "_tool_get_selected_nodes"),
						  output_schema, annotations)

func _tool_get_selected_nodes(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var selected_nodes: Array = []
	var selection: EditorSelection = editor_interface.get_selection()
	var scene_root: Node = _get_user_scene_root()
	
	if selection:
		var selected: Array[Node] = selection.get_selected_nodes()
		for node in selected:
			var node_info: Dictionary = {
				"path": _make_friendly_path(node, scene_root),
				"type": node.get_class()
			}
			var node_script: Variant = node.get_script()
			if node_script and node_script is Script:
				node_info["script_path"] = node_script.resource_path
			selected_nodes.append(node_info)
	
	return {
		"selected_nodes": selected_nodes,
		"count": selected_nodes.size()
	}

# ============================================================================
# set_editor_setting - 设置编辑器属性
# ============================================================================

func _register_set_editor_setting(server_core: RefCounted) -> void:
	var tool_name: String = "set_editor_setting"
	var description: String = "Set an editor setting value. Requires editor restart for some settings to take effect."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"setting_name": {
				"type": "string",
				"description": "Name of the setting (e.g. 'interface/theme/accent_color')"
			},
			"setting_value": {
				"description": "New value for the setting"
			}
		},
		"required": ["setting_name", "setting_value"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"setting_name": {"type": "string"},
			"old_value": {"type": "string"},
			"new_value": {"type": "string"}
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
						  Callable(self, "_tool_set_editor_setting"),
						  output_schema, annotations)

func _tool_set_editor_setting(params: Dictionary) -> Dictionary:
	var setting_name: String = params.get("setting_name", "")
	var setting_value: Variant = params.get("setting_value", null)
	
	if setting_name.is_empty():
		return {"error": "Missing required parameter: setting_name"}
	if setting_value == null:
		return {"error": "Missing required parameter: setting_value"}
	
	var editor_interface: EditorInterface = _get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var editor_settings: EditorSettings = editor_interface.get_editor_settings()
	if not editor_settings:
		return {"error": "Failed to get EditorSettings"}
	
	var old_value: Variant = null
	if editor_settings.has_setting(setting_name):
		old_value = editor_settings.get_setting(setting_name)
	editor_settings.set_setting(setting_name, setting_value)
	if editor_settings.has_method("save"):
		editor_settings.save()
	
	return {
		"status": "success",
		"setting_name": setting_name,
		"old_value": str(old_value) if old_value != null else "null",
		"new_value": str(setting_value)
	}
