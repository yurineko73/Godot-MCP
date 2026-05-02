# debug_tools_native.gd - Debug Tools原生实现

@tool
class_name DebugToolsNative
extends RefCounted

var _editor_interface: EditorInterface = null
var _log_buffer: Array[String] = []
var _max_log_lines: int = 1000
var _server_core: RefCounted = null
var _log_mutex: Mutex = Mutex.new()
var _execution_mutex: Mutex = Mutex.new()

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
	_server_core = server_core
	if server_core.has_signal("log_message"):
		server_core.log_message.connect(_on_log_message)
	
	_register_get_editor_logs(server_core)
	_register_execute_script(server_core)
	_register_get_performance_metrics(server_core)
	_register_debug_print(server_core)

func _on_log_message(level: String, message: String) -> void:
	var log_entry: String = "[%s] %s" % [level, message]
	_log_mutex.lock()
	_log_buffer.append(log_entry)
	if _log_buffer.size() > _max_log_lines:
		_log_buffer = _log_buffer.slice(_log_buffer.size() - _max_log_lines)
	_log_mutex.unlock()

# ============================================================================
# get_editor_logs - 获取编辑器日志
# ============================================================================

func _register_get_editor_logs(server_core: RefCounted) -> void:
	var tool_name: String = "get_editor_logs"
	var description: String = "Get recent editor log messages. Note: This captures output from the MCP server and print statements."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"max_lines": {
				"type": "integer",
				"description": "Maximum number of log lines to return. Default is 100.",
				"default": 100
			}
		}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"logs": {
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
						  Callable(self, "_tool_get_editor_logs"),
						  output_schema, annotations)

func _tool_get_editor_logs(params: Dictionary) -> Dictionary:
	var max_lines: int = params.get("max_lines", 100)
	
	_log_mutex.lock()
	if _log_buffer.is_empty():
		_log_mutex.unlock()
		return {
			"logs": [],
			"count": 0,
			"note": "No log messages captured yet. Logs are captured from MCP server activity."
		}
	
	var start_index: int = maxi(0, _log_buffer.size() - max_lines)
	var logs: Array = _log_buffer.slice(start_index)
	_log_mutex.unlock()
	
	return {
		"logs": logs,
		"count": logs.size(),
		"total_available": _log_buffer.size()
	}

# ============================================================================
# execute_script - 执行脚本代码
# ============================================================================

func _register_execute_script(server_core: RefCounted) -> void:
	var tool_name: String = "execute_script"
	var description: String = "Execute a GDScript expression or statement. Uses Godot's Expression class for safe evaluation."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"code": {
				"type": "string",
				"description": "GDScript code to execute (expression or statement)"
			},
			"bind_objects": {
				"type": "object",
				"description": "Optional dictionary of objects to bind to the expression"
			}
		},
		"required": ["code"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"result": {"type": "string"},
			"error": {"type": "string"}
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
						  Callable(self, "_tool_execute_script"),
						  output_schema, annotations)

func _tool_execute_script(params: Dictionary) -> Dictionary:
	var code: String = params.get("code", "")
	var bind_objects: Dictionary = params.get("bind_objects", {})
	
	if code.is_empty():
		return {"error": "Missing required parameter: code"}
	
	var expression: Expression = Expression.new()

	var bind_names: PackedStringArray = []
	var bind_values: Array = []
	var singletons: Dictionary = {
		"OS": OS,
		"Engine": Engine,
		"ProjectSettings": ProjectSettings,
		"Input": Input,
		"Time": Time,
		"JSON": JSON,
		"ClassDB": ClassDB,
		"Performance": Performance,
		"ResourceLoader": ResourceLoader,
		"ResourceSaver": ResourceSaver,
		"EditorInterface": EditorInterface,
	}
	for singleton_name in singletons:
		bind_names.append(singleton_name)
		bind_values.append(singletons[singleton_name])

	if not bind_objects.is_empty():
		for key in bind_objects:
			bind_names.append(key)
			bind_values.append(bind_objects[key])

	var parse_error: Error = expression.parse(code, bind_names)

	if parse_error != OK:
		return {
			"status": "error",
			"error": "Parse failed: " + expression.get_error_text()
		}

	var base_instance: RefCounted = self
	_execution_mutex.lock()
	var result: Variant = expression.execute(bind_values, base_instance, true)
	_execution_mutex.unlock()
	
	if expression.has_execute_failed():
		return {
			"status": "error",
			"error": "Execution failed: " + expression.get_error_text()
		}
	
	return {
		"status": "success",
		"result": str(result)
	}

# ============================================================================
# get_performance_metrics - 获取性能指标
# ============================================================================

func _register_get_performance_metrics(server_core: RefCounted) -> void:
	var tool_name: String = "get_performance_metrics"
	var description: String = "Get performance metrics including FPS, memory usage, and object counts."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {}
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"fps": {"type": "number"},
			"object_count": {"type": "integer"},
			"resource_count": {"type": "integer"},
			"memory_usage_mb": {"type": "number"}
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
						  Callable(self, "_tool_get_performance_metrics"),
						  output_schema, annotations)

static func _tool_get_performance_metrics(params: Dictionary) -> Dictionary:
	# 使用Performance单例获取性能指标
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var object_count: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var resource_count: int = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var memory_usage: int = Performance.get_monitor(Performance.MEMORY_STATIC)  # 静态内存
	
	# 转换为MB
	var memory_mb: float = memory_usage / 1024.0 / 1024.0
	
	return {
		"fps": fps,
		"object_count": object_count,
		"resource_count": resource_count,
		"memory_usage_mb": memory_mb
	}

# ============================================================================
# debug_print - 输出调试信息
# ============================================================================

func _register_debug_print(server_core: RefCounted) -> void:
	var tool_name: String = "debug_print"
	var description: String = "Print a debug message to the Godot output console."
	
	# inputSchema
	var input_schema: Dictionary = {
		"type": "object",
		"properties": {
			"message": {
				"type": "string",
				"description": "Message to print"
			},
			"category": {
				"type": "string",
				"description": "Optional category tag for the message (e.g. 'MCP', 'AI', 'Debug')"
			}
		},
		"required": ["message"]
	}
	
	# outputSchema
	var output_schema: Dictionary = {
		"type": "object",
		"properties": {
			"status": {"type": "string"},
			"printed_message": {"type": "string"}
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
						  Callable(self, "_tool_debug_print"),
						  output_schema, annotations)

static func _tool_debug_print(params: Dictionary) -> Dictionary:
	# 参数提取
	var message: String = params.get("message", "")
	var category: String = params.get("category", "")
	
	# 参数验证
	if message.is_empty():
		return {"error": "Missing required parameter: message"}
	
	# 构建打印消息
	var full_message: String
	if category.is_empty():
		full_message = "[MCP Debug] " + message
	else:
		full_message = "[" + category + "] " + message
	
	# 输出到Godot控制台
	printerr(full_message)
	
	return {
		"status": "success",
		"printed_message": full_message
	}
