# mcp_server_native.gd - 原生MCP服务器插件主类
# 根据godot-dev-guide优化，添加完整的类型提示和@export变量

@tool
extends EditorPlugin

# ============================================================================
# 配置变量（根据godot-dev-guide使用@export）
# ============================================================================

@export var auto_start: bool = false:
	set(value):
		auto_start = value
		notify_property_list_changed()

@export_range(0, 3, 1) var log_level: int = 2:  # 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG (默认2=INFO，便于测试)
	set(value):
		log_level = value
		if _native_server:
			_native_server.set_log_level(value)
		notify_property_list_changed()

@export var security_level: int = 1:  # 0=PERMISSIVE, 1=STRICT
	set(value):
		security_level = value
		if _native_server:
			_native_server.set_security_level(value)
		notify_property_list_changed()

@export var rate_limit: int = 100:
	set(value):
		rate_limit = value
		if _native_server:
			_native_server.set_rate_limit(value)
		notify_property_list_changed()

# ============================================================================
# 内部变量（使用完整类型提示 - 根据godot-dev-guide）
# ============================================================================

var _native_server: RefCounted = null
var _dock: EditorDock = null
var _bottom_panel: Control = null
var _editor_interface: EditorInterface = null
var _mcp_server_mode: bool = false
var _tool_instances: Dictionary = {}

# ============================================================================
# 生命周期方法
# ============================================================================

func _enter_tree() -> void:
	printerr("[MCP Plugin] GODOT-NATIVE-MCP PLUGIN LOADING...")

	_log_info("Godot Native MCP Plugin entering tree...")

	Engine.set_meta("GodotMCPPlugin", self)

	_editor_interface = get_editor_interface()
	if not _editor_interface:
		_log_error("Failed to get EditorInterface")
		printerr("[MCP Plugin] ERROR: Failed to get EditorInterface")
		return

	printerr("[MCP Plugin] EditorInterface obtained")

	_native_server = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
	
	if not _native_server:
		_log_error("Failed to create MCP Server Core instance")
		printerr("[MCP Plugin] ERROR: Failed to create server core")
		return
		
	printerr("[MCP Plugin] Server core created successfully")
	
	# 配置服务器
	_native_server.set_log_level(log_level)
	_native_server.set_security_level(security_level)
	_native_server.set_rate_limit(rate_limit)
	
	# 连接信号（根据godot-dev-guide信号模式）
	_native_server.server_started.connect(_on_server_started)
	_native_server.server_stopped.connect(_on_server_stopped)
	_native_server.message_received.connect(_on_message_received)
	_native_server.response_sent.connect(_on_response_sent)
	_native_server.tool_execution_started.connect(_on_tool_started)
	_native_server.tool_execution_completed.connect(_on_tool_completed)
	_native_server.tool_execution_failed.connect(_on_tool_failed)
	_native_server.log_message.connect(_on_log_message)
	
	# 注册所有工具
	_register_all_tools()
	
	# 注册所有资源
	_register_all_resources()
	
	# 创建UI面板
	_create_ui_panel()
	
	# 检测是否以MCP服务器模式启动
	_mcp_server_mode = "--mcp-server" in OS.get_cmdline_user_args()
	
	if _mcp_server_mode:
		_log_info("MCP server mode detected via --mcp-server argument")
		_start_native_server()
	elif auto_start:
		_log_info("Auto-start enabled, starting MCP server")
		_start_native_server()
	else:
		_log_info("MCP server not auto-started. Use Start button or --mcp-server flag.")
	
	_log_info("Godot Native MCP Plugin initialized")

func _exit_tree() -> void:
	_log_info("Godot Native MCP Plugin exiting tree...")
	
	# 停止服务器
	if _native_server and _native_server.is_running():
		_native_server.stop()
	
	# 清理UI
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null
		_bottom_panel = null
	
	# 清理服务器实例
	_native_server = null
	
	_log_info("Godot Native MCP Plugin shutdown complete")

# ============================================================================
# 插件配置（根据godot-dev-guide优化）
# ============================================================================

func _get_plugin_name() -> String:
	return "Godot Native MCP Server"

func get_native_server() -> RefCounted:
	return _native_server

func _has_settings() -> bool:
	return true

func _get_property_list() -> Array:
	var properties: Array = []
	
	# 添加属性分组（根据godot-dev-guide）
	properties.append({
		"name": "MCP Settings",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY
	})
	
	properties.append({
		"name": "auto_start",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "log_level",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "ERROR,WARN,INFO,DEBUG",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "security_level",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "PERMISSIVE,STRICT",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	properties.append({
		"name": "rate_limit",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "10,1000,10",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	
	return properties

# ============================================================================
# 公共API
# ============================================================================

func start_server() -> bool:
	return _start_native_server()

func stop_server() -> void:
	_stop_native_server()

func is_server_running() -> bool:
	if _native_server:
		return _native_server.is_running()
	return false

func get_server_status() -> Dictionary:
	if not _native_server:
		return {"status": "not_initialized"}
	
	return {
		"status": "running" if _native_server.is_running() else "stopped",
		"log_level": log_level,
		"security_level": security_level,
		"rate_limit": rate_limit,
		"tools_count": _get_tools_count(),
		"resources_count": _get_resources_count()
	}

# ============================================================================
# 私有方法 - 服务器管理
# ============================================================================

func _start_native_server() -> bool:
	if not _native_server:
		_log_error("MCP Server instance not available")
		return false
	
	if _native_server.is_running():
		_log_warn("MCP Server already running")
		return false
	
	_log_info("Starting native MCP server...")
	var success: bool = _native_server.start()
	
	if success:
		_log_info("Native MCP Server started - listening on stdio")
	else:
		_log_error("Failed to start MCP Server")
	
	return success

func _stop_native_server() -> void:
	if not _native_server:
		return
	
	if not _native_server.is_running():
		_log_warn("MCP Server not running")
		return
	
	_log_info("Stopping native MCP server...")
	_native_server.stop()
	_log_info("Native MCP Server stopped")

func _get_tools_count() -> int:
	if not _native_server:
		return 0
	# 这里需要添加一个方法到MCPServerCore来获取工具数量
	return _native_server.get_tools_count() if _native_server.has_method("get_tools_count") else 0

func _get_resources_count() -> int:
	if not _native_server:
		return 0
	# 这里需要添加一个方法到MCPServerCore来获取资源数量
	return _native_server.get_resources_count() if _native_server.has_method("get_resources_count") else 0

# ============================================================================
# 私有方法 - 工具注册（根据mcp-builder优化）
# ============================================================================

func _register_all_tools() -> void:
	_log_info("Registering all MCP tools...")
	
	if not _native_server:
		_log_error("MCP Server instance not available")
		return
	
	_tool_instances["NodeToolsNative"] = NodeToolsNative.new()
	_tool_instances["ScriptToolsNative"] = ScriptToolsNative.new()
	_tool_instances["SceneToolsNative"] = SceneToolsNative.new()
	_tool_instances["EditorToolsNative"] = EditorToolsNative.new()
	_tool_instances["DebugToolsNative"] = DebugToolsNative.new()
	_tool_instances["ProjectToolsNative"] = ProjectToolsNative.new()
	
	_tool_instances["NodeToolsNative"].initialize(_editor_interface)
	_tool_instances["ScriptToolsNative"].initialize(_editor_interface)
	_tool_instances["SceneToolsNative"].initialize(_editor_interface)
	_tool_instances["EditorToolsNative"].initialize(_editor_interface)
	_tool_instances["DebugToolsNative"].initialize(_editor_interface)
	_tool_instances["ProjectToolsNative"].initialize(_editor_interface)
	
	_tool_instances["NodeToolsNative"].register_tools(_native_server)
	_tool_instances["ScriptToolsNative"].register_tools(_native_server)
	_tool_instances["SceneToolsNative"].register_tools(_native_server)
	_tool_instances["EditorToolsNative"].register_tools(_native_server)
	_tool_instances["DebugToolsNative"].register_tools(_native_server)
	_tool_instances["ProjectToolsNative"].register_tools(_native_server)
	
	_log_info("All MCP tools registered successfully")

# ============================================================================
# 私有方法 - 资源注册（根据mcp-builder优化）
# ============================================================================

func _register_all_resources() -> void:
	_log_info("Registering all MCP resources...")
	
	if not _native_server:
		_log_error("MCP Server instance not available")
		return
	
	# 注册场景资源
	_register_scene_resources()
	
	# 注册脚本资源
	_register_script_resources()
	
	# 注册项目资源
	_register_project_resources()
	
	# 注册编辑器资源
	_register_editor_resources()
	
	_log_info("All MCP resources registered successfully")

func _register_scene_resources() -> void:
	# godot://scene/list
	_native_server.register_resource(
		"godot://scene/list",
		"Godot Scene List",
		"application/json",
		Callable(self, "_resource_scene_list"),
		"List of all .tscn scene files in the project"
	)
	
	# godot://scene/current
	_native_server.register_resource(
		"godot://scene/current",
		"Current Scene",
		"application/json",
		Callable(self, "_resource_scene_current"),
		"Structure of the currently open scene in the editor"
	)

func _register_script_resources() -> void:
	# godot://script/list
	_native_server.register_resource(
		"godot://script/list",
		"Godot Script List",
		"application/json",
		Callable(self, "_resource_script_list"),
		"List of all .gd script files in the project"
	)
	
	# godot://script/current
	_native_server.register_resource(
		"godot://script/current",
		"Current Script",
		"text/plain",
		Callable(self, "_resource_script_current"),
		"Content of the currently open script in the editor"
	)

func _register_project_resources() -> void:
	# godot://project/info
	_native_server.register_resource(
		"godot://project/info",
		"Project Info",
		"application/json",
		Callable(self, "_resource_project_info"),
		"Project name, version, and basic information"
	)
	
	# godot://project/settings
	_native_server.register_resource(
		"godot://project/settings",
		"Project Settings",
		"application/json",
		Callable(self, "_resource_project_settings"),
		"Project setting values and configuration"
	)

func _register_editor_resources() -> void:
	# godot://editor/state
	_native_server.register_resource(
		"godot://editor/state",
		"Editor State",
		"application/json",
		Callable(self, "_resource_editor_state"),
		"Current editor state and active tools"
	)

# ============================================================================
# 资源加载方法（实际实现）
# ============================================================================

func _resource_scene_list(params: Dictionary) -> Dictionary:
	var scenes: Array = []
	var dir = DirAccess.open("res://")

	if not dir:
		return {"contents": [{"uri": "godot://scene/list", "mimeType": "application/json", "text": "[]"}]}

	_find_files_recursive(dir, ".tscn", scenes)

	return {
		"contents": [{
			"uri": "godot://scene/list",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"scenes": scenes,
				"count": scenes.size(),
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

func _resource_scene_current(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://scene/current", "mimeType": "application/json", "text": "{}"}]}

	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if not scene_root:
		return {"contents": [{"uri": "godot://scene/current", "mimeType": "application/json", "text": "{}"}]}

	var scene_info: Dictionary = {
		"name": scene_root.name,
		"path": scene_root.scene_file_path,
		"type": scene_root.get_class(),
		"node_count": _count_nodes(scene_root),
		"children": _get_node_tree(scene_root, 2)
	}

	return {
		"contents": [{
			"uri": "godot://scene/current",
			"mimeType": "application/json",
			"text": JSON.stringify(scene_info, "\t", true)
		}]
	}

func _resource_script_list(params: Dictionary) -> Dictionary:
	var scripts: Array = []
	var dir = DirAccess.open("res://")

	if not dir:
		return {"contents": [{"uri": "godot://script/list", "mimeType": "application/json", "text": "[]"}]}

	_find_files_recursive(dir, ".gd", scripts)

	return {
		"contents": [{
			"uri": "godot://script/list",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"scripts": scripts,
				"count": scripts.size(),
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

func _resource_script_current(params: Dictionary) -> Dictionary:
	return {
		"contents": [{
			"uri": "godot://script/current",
			"mimeType": "text/plain",
			"text": "# Current script feature not yet implemented\n# Godot 4.x requires EditorPlugin or ScriptEditor to get current script"
		}]
	}

func _resource_project_info(params: Dictionary) -> Dictionary:
	var project_info: Dictionary = {
		"name": ProjectSettings.get_setting("application/config/name", "未命名项目"),
		"version": ProjectSettings.get_setting("application/config/version", "1.0"),
		"description": ProjectSettings.get_setting("application/config/description", ""),
		"author": ProjectSettings.get_setting("application/config/author", ""),
		"godot_version": _get_godot_version(),
		"timestamp": Time.get_unix_time_from_system()
	}

	return {
		"contents": [{
			"uri": "godot://project/info",
			"mimeType": "application/json",
			"text": JSON.stringify(project_info, "\t", true)
		}]
	}

func _resource_project_settings(params: Dictionary) -> Dictionary:
	var settings: Dictionary = {}
	var property_list: Array = ProjectSettings.get_property_list()

	# 只导出非内部的设置
	for property in property_list:
		var property_name: String = property.get("name", "")
		if property_name.begins_with("application/") or property_name.begins_with("display/") or property_name.begins_with("rendering/"):
			settings[property_name] = ProjectSettings.get_setting(property_name)

	return {
		"contents": [{
			"uri": "godot://project/settings",
			"mimeType": "application/json",
			"text": JSON.stringify({
				"settings": settings,
				"count": settings.size(),
				"timestamp": Time.get_unix_time_from_system()
			}, "\t", true)
		}]
	}

func _resource_editor_state(params: Dictionary) -> Dictionary:
	if not _editor_interface:
		return {"contents": [{"uri": "godot://editor/state", "mimeType": "application/json", "text": "{}"}]}

	var editor_state: Dictionary = {
		"current_scene": "",
		"selected_nodes": [],
		"timestamp": Time.get_unix_time_from_system()
	}

	var scene_root: Node = _editor_interface.get_edited_scene_root()
	if scene_root:
		editor_state["current_scene"] = scene_root.scene_file_path

	var selection = _editor_interface.get_selection()
	if selection:
		var selected_nodes: Array = selection.get_selected_nodes()
		for node in selected_nodes:
			editor_state["selected_nodes"].append(str(node.get_path()))

	return {
		"contents": [{
			"uri": "godot://editor/state",
			"mimeType": "application/json",
			"text": JSON.stringify(editor_state, "\t", true)
		}]
	}

# ============================================================================
# 资源加载辅助函数
# ============================================================================

static func _find_files_recursive(dir: DirAccess, extension: String, result: Array, base_path: String = "res://") -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		var full_path: String = base_path + file_name

		if dir.current_is_dir():
			# 递归进入子目录
			var sub_dir: DirAccess = DirAccess.open(full_path + "/")
			if sub_dir:
				_find_files_recursive(sub_dir, extension, result, full_path + "/")
		elif file_name.ends_with(extension):
			# 找到匹配的文件
			result.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

static func _count_nodes(node: Node) -> int:
	var count: int = 1  # 当前节点

	for child in node.get_children():
		count += _count_nodes(child)

	return count

static func _get_node_tree(node: Node, max_depth: int, current_depth: int = 0) -> Array:
	if current_depth >= max_depth:
		return []

	var result: Array = []

	for child in node.get_children():
		var child_info: Dictionary = {
			"name": child.name,
			"type": child.get_class(),
			"children": _get_node_tree(child, max_depth, current_depth + 1)
		}
		result.append(child_info)

	return result

static func _get_godot_version() -> Dictionary:
	return {
		"version": Engine.get_version_info()["string"],
		"major": Engine.get_version_info()["major"],
		"minor": Engine.get_version_info()["minor"],
		"patch": Engine.get_version_info()["patch"]
	}

# ============================================================================
# UI面板创建
# ============================================================================

func _create_ui_panel() -> void:
	_log_info("Creating UI panel...")
	
	var panel_scene: PackedScene = load("res://addons/godot_mcp/ui/mcp_panel_native.tscn")
	if not panel_scene:
		_log_error("Failed to load MCP panel scene")
		return
	
	_bottom_panel = panel_scene.instantiate()
	if not _bottom_panel:
		_log_error("Failed to instantiate MCP panel")
		return
	
	_dock = EditorDock.new()
	_dock.title = "MCP Server"
	_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	_dock.add_child(_bottom_panel)
	add_dock(_dock)
	
	if _bottom_panel.has_method("set_plugin"):
		_bottom_panel.set_plugin(self)
		_log_info("Plugin reference set to panel")
	
	if _native_server and _bottom_panel.has_method("set_server_core"):
		_bottom_panel.set_server_core(_native_server)
		_log_info("Server core reference set to panel")
	
	_log_info("UI panel created successfully")

# ============================================================================
# 信号回调
# ============================================================================

func _on_server_started() -> void:
	_log_info("MCP Server started")
	if _bottom_panel and _bottom_panel.has_method("refresh"):
		if Thread.is_main_thread():
			_bottom_panel.refresh()
		else:
			_bottom_panel.call_deferred("refresh")

func _on_server_stopped() -> void:
	_log_info("MCP Server stopped")
	if _bottom_panel and _bottom_panel.has_method("refresh"):
		if Thread.is_main_thread():
			_bottom_panel.refresh()
		else:
			_bottom_panel.call_deferred("refresh")

func _on_message_received(message: Dictionary) -> void:
	_log_debug("Message received: " + JSON.stringify(message))
	if _bottom_panel and _bottom_panel.has_method("update_log"):
		_bottom_panel.update_log("[RECV] " + JSON.stringify(message))

func _on_response_sent(response: Dictionary) -> void:
	_log_debug("Response sent: " + JSON.stringify(response))
	if _bottom_panel and _bottom_panel.has_method("update_log"):
		_bottom_panel.update_log("[SENT] " + JSON.stringify(response))

func _on_tool_started(tool_name: String, params: Dictionary) -> void:
	_log_info("Tool started: " + tool_name)

func _on_tool_completed(tool_name: String, result: Dictionary) -> void:
	_log_info("Tool completed: " + tool_name)

func _on_tool_failed(tool_name: String, error: String) -> void:
	_log_error("Tool failed: " + tool_name + " - " + error)

func _on_log_message(level: String, message: String) -> void:
	if _bottom_panel and _bottom_panel.has_method("update_log"):
		_bottom_panel.update_log("[" + level + "] " + message)
	
	match level:
		"ERROR":
			printerr("[MCP Server] " + message)
		"WARN", "INFO", "DEBUG":
			printerr("[MCP Server][" + level + "] " + message)

# ============================================================================
# 日志方法（根据godot-dev-guide优化）
# ============================================================================

func _log_error(message: String) -> void:
	if log_level >= 0:
		printerr("[MCP Plugin][ERROR] " + message)

func _log_warn(message: String) -> void:
	if log_level >= 1:
		printerr("[MCP Plugin][WARN] " + message)

func _log_info(message: String) -> void:
	if log_level >= 2:
		printerr("[MCP Plugin][INFO] " + message)

func _log_debug(message: String) -> void:
	if log_level >= 3:
		printerr("[MCP Plugin][DEBUG] " + message)

# ============================================================================
# 清理
# ============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_exit_tree()
