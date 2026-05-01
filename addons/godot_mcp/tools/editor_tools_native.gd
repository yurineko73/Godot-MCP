# editor_tools_native.gd - Editor Tools原生实现
# 根据godot-dev-guide添加完整的类型提示

@tool
class_name EditorToolsNative
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

static func _tool_get_editor_state(params: Dictionary) -> Dictionary:
	# 获取编辑器接口
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 获取当前场景信息
	var scene_root: Node = editor_interface.get_edited_scene_root()
	var active_scene: String = scene_root.name if scene_root else ""
	
	# 获取选中节点
	var selected_nodes: Array[String] = []
	var selection: EditorSelection = editor_interface.get_selection()
	if selection:
		var selected: Array[Node] = selection.get_selected_nodes()
		for node in selected:
			selected_nodes.append(str(node.get_path()))
	
	# 获取编辑器模式（简化版本）
	var editor_mode: String = "editor"  # 默认值
	
	# 尝试判断是否在运行模式
	# 注意：Godot 4.x API可能没有直接获取运行模式的方法
	# 这里使用启发式判断
	
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

static func _tool_run_project(params: Dictionary) -> Dictionary:
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	var scene_path: String = params.get("scene_path", "")
	
	if not scene_path.is_empty():
		if not FileAccess.file_exists(scene_path):
			return {"error": "Scene file not found: " + scene_path}
		editor_interface.play_custom_scene(scene_path)
	else:
		editor_interface.play_current_scene()
	
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

static func _tool_stop_project(params: Dictionary) -> Dictionary:
	# 获取编辑器接口
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 停止项目
	editor_interface.stop_playing_scene()
	
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

static func _tool_get_selected_nodes(params: Dictionary) -> Dictionary:
	# 获取编辑器接口
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 获取选中节点
	var selected_nodes: Array[String] = []
	var selection: EditorSelection = editor_interface.get_selection()
	
	if selection:
		var selected: Array[Node] = selection.get_selected_nodes()
		for node in selected:
			selected_nodes.append(str(node.get_path()))
	
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
				"type": ["string", "number", "boolean"],
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

static func _tool_set_editor_setting(params: Dictionary) -> Dictionary:
	# 参数提取
	var setting_name: String = params.get("setting_name", "")
	var setting_value: Variant = params.get("setting_value", null)
	
	# 参数验证
	if setting_name.is_empty():
		return {"error": "Missing required parameter: setting_name"}
	if setting_value == null:
		return {"error": "Missing required parameter: setting_value"}
	
	# Godot 4.x: 通过EditorInterface获取EditorSettings
	var editor_interface: EditorInterface = Engine.get_meta("GodotMCPPlugin").get_editor_interface()
	if not editor_interface:
		return {"error": "Editor interface not available"}
	
	# 获取EditorSettings对象
	var editor_settings: EditorSettings = editor_interface.get_editor_settings()
	if not editor_settings:
		return {"error": "Failed to get EditorSettings"}
	
	# 获取旧值
	var old_value: Variant = editor_settings.get_setting(setting_name)
	
	# 设置新值
	editor_settings.set_setting(setting_name, setting_value)
	
	# 保存到配置
	editor_settings.save()
	
	return {
		"status": "success",
		"setting_name": setting_name,
		"old_value": str(old_value),
		"new_value": str(setting_value)
	}
