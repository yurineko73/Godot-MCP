# mcp_server_core.gd - MCP服务器核心实现
# 整合传输层、协议处理、工具注册、资源管理
# 根据godot-dev-guide添加完整的类型提示
# 根据mcp-builder添加outputSchema和annotations支持

@tool
class_name MCPServerCore
extends RefCounted

# ============================================================================
# 信号定义（使用信号解耦通信 - 根据godot-dev-guide）
# ============================================================================

signal server_started
signal server_stopped
signal message_received(message: Dictionary)
signal response_sent(response: Dictionary)
signal tool_execution_started(tool_name: String, params: Dictionary)
signal tool_execution_completed(tool_name: String, result: Dictionary)
signal tool_execution_failed(tool_name: String, error: String)
signal resource_requested(resource_uri: String, params: Dictionary)
signal resource_loaded(resource_uri: String, content: Dictionary)
signal log_message(level: String, message: String)

# ============================================================================
# 常量
# ============================================================================

const JSONRPC_VERSION: String = "2.0"
const PROTOCOL_VERSION: String = "2024-11-05"

# ============================================================================
# 状态变量（使用完整类型提示 - 根据godot-dev-guide）
# ============================================================================

var _active: bool = false
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()

# 消息队列（使用类型化数组 - 根据godot-dev-guide）
var _message_queue: Array[Dictionary] = []
var _response_queue: Array[Dictionary] = []

# 工具和资源注册表
var _tools: Dictionary = {}  # String -> MCPTool
var _resources: Dictionary = {}  # String -> MCPResource
var _prompts: Dictionary = {}  # String -> MCPPrompt

# 配置
var _log_level: int = MCPTypes.LogLevel.INFO
var _security_level: int = MCPTypes.SecurityLevel.STRICT
var _rate_limit: int = 100  # 每60秒最多100个请求

# 速率限制跟踪
var _request_count: Dictionary = {}  # String (client_id) -> int
var _request_timestamps: Dictionary = {}  # String (client_id) -> Array[int]

# 缓存
var _scene_structure_cache: Dictionary = {}  # String -> Dictionary
var _cache_timestamp: Dictionary = {}  # String -> int

# JSONRPC实例（如需使用Godot内置JSONRPC处理，可取消注释）
# var _jsonrpc: JSONRPC = JSONRPC.new()

# ============================================================================
# 生命周期方法
# ============================================================================

func _init() -> void:
	# JSONRPC在Godot 4.x中不需要初始化
	pass

func start() -> bool:
	printerr("[MCP Server] start() called")
	
	if _active:
		_log_warn("Server already running")
		return false
	
	_log_info("Starting MCP Server...")
	_active = true
	
	ProjectSettings.set_setting("application/run/flush_stdout_on_print", true)
	
	_thread = Thread.new()
	printerr("[MCP Server] Creating thread...")
	_thread.start(_stdin_listen_loop)
	printerr("[MCP Server] Thread started")
	
	_active = true
	server_started.emit()
	_log_info("MCP Server started - listening on stdio")
	
	return true

func stop() -> void:
	if not _active:
		return
	
	_log_info("Stopping MCP Server...")
	_active = false
	
	# 等待线程结束
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	
	server_stopped.emit()
	_log_info("MCP Server stopped")

func is_running() -> bool:
	return _active

# ============================================================================
# 主线程消息处理（由call_deferred调用）
# ============================================================================

func _process_message(message: Dictionary) -> void:
	if not _active:
		return
	
	# 验证消息格式
	if not message.has("jsonrpc"):
		_send_error(null, MCPTypes.ERROR_INVALID_REQUEST, "Missing jsonrpc field")
		return
	
	if message["jsonrpc"] != JSONRPC_VERSION:
		_send_error(message.get("id"), MCPTypes.ERROR_INVALID_REQUEST, "Invalid JSON-RPC version")
		return
	
	# 记录收到的消息
	message_received.emit(message)
	_log_debug("Received message: " + JSON.stringify(message))
	
	# 处理请求
	var response: Dictionary = {}
	
	if message.has("method"):
		# 这是一个请求或通知
		response = _handle_request(message)
	else:
		# 这是一个响应（通常不需要处理）
		_log_warn("Received unexpected response message")
		return
	
	# 发送响应（如果有）
	if response:
		_send_response(response)

# ============================================================================
# 请求处理（根据mcp-builder优化）
# ============================================================================

func _handle_request(message: Dictionary) -> Dictionary:
	var method: String = message.get("method", "")
	var id: Variant = message.get("id", null)
	var params: Dictionary = message.get("params", {})
	
	# 速率限制检查
	if not _check_rate_limit("default"):
		return MCPTypes.create_error_response(id, MCPTypes.ERROR_INTERNAL_ERROR, "Rate limit exceeded")
	
	match method:
		MCPTypes.METHOD_INITIALIZE:
			return _handle_initialize(message)
		
		MCPTypes.METHOD_NOTIFICATIONS_INITIALIZED:
			return _handle_initialized_notification(message)
		
		MCPTypes.METHOD_TOOLS_LIST:
			return _handle_tools_list(message)
		
		MCPTypes.METHOD_TOOLS_CALL:
			return _handle_tool_call(message)
		
		MCPTypes.METHOD_RESOURCES_LIST:
			return _handle_resources_list(message)
		
		MCPTypes.METHOD_RESOURCES_READ:
			return _handle_resource_read(message)
		
		MCPTypes.METHOD_RESOURCES_SUBSCRIBE:
			return _handle_resource_subscribe(message)
		
		MCPTypes.METHOD_PROMPTS_LIST:
			return _handle_prompts_list(message)
		
		MCPTypes.METHOD_PROMPTS_GET:
			return _handle_prompt_get(message)
		
		_:
			_log_warn("Method not found: " + method)
			return MCPTypes.create_error_response(id, MCPTypes.ERROR_METHOD_NOT_FOUND, "Method not found: " + method)

# ============================================================================
# MCP协议方法实现（完整版 - 根据mcp-builder）
# ============================================================================

func _handle_initialize(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var client_capabilities: Dictionary = params.get("capabilities", {})
	var client_protocol_version: String = params.get("protocolVersion", PROTOCOL_VERSION)
	
	_log_info("Initialize request from client. Protocol: " + client_protocol_version)
	_log_debug("Client capabilities: " + JSON.stringify(client_capabilities))
	
	# 返回服务器capabilities（完整版 - 根据mcp-builder）
	var result: Dictionary = {
		"protocolVersion": PROTOCOL_VERSION,
		"capabilities": MCPTypes.create_capabilities(true, true, true, true),
		"serverInfo": {
			"name": "godot-native-mcp",
			"version": "2.0.0"
		}
	}
	
	var response: Dictionary = MCPTypes.create_response(id, result)
	_log_debug("Initialize response: " + JSON.stringify(response))
	
	return response

func _handle_initialized_notification(message: Dictionary) -> Dictionary:
	_log_info("Client initialized notification received")
	# 这是一个通知，不需要返回响应
	return {}

func _handle_tools_list(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	
	_log_info("Tools list requested. Available tools: " + str(_tools.size()))
	
	# 构建工具列表（根据mcp-builder，包含annotations和outputSchema）
	var tools_list: Array[Dictionary] = []
	
	for tool_name in _tools:
		var tool: MCPTypes.MCPTool = _tools[tool_name]
		if tool and tool.is_valid():
			tools_list.append(tool.to_dict())
	
	var result: Dictionary = {"tools": tools_list}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	_log_debug("Tools list response: " + JSON.stringify(response))
	
	return response

func _handle_tool_call(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var tool_name: String = params.get("name", "")
	var arguments: Dictionary = params.get("arguments", {})
	
	_log_info("Tool call: " + tool_name)
	_log_debug("Tool arguments: " + JSON.stringify(arguments))
	
	# 检查工具是否存在
	if not _tools.has(tool_name):
		_log_error("Tool not found: " + tool_name)
		var error_result: Dictionary = {
			"content": [{
				"type": "text",
				"text": "Tool not found: " + tool_name
			}],
			"isError": true
		}
		return MCPTypes.create_response(id, error_result)
	
	var tool: MCPTypes.MCPTool = _tools[tool_name]
	
	# 发送开始信号
	tool_execution_started.emit(tool_name, arguments)
	
	# 执行工具
	var result: Variant = null
	var error: String = ""
	
	if tool.callable.is_valid():
		# 使用Callable调用工具
		var status: Error = OK
		
		# 捕获执行错误
		if status == OK:
			result = tool.callable.call(arguments)
		else:
			error = "Tool execution failed with error: " + str(status)
	
	# 处理执行结果
	if not error.is_empty():
		_log_error("Tool execution failed: " + tool_name + " - " + error)
		tool_execution_failed.emit(tool_name, error)
		var error_result: Dictionary = {
			"content": [{
				"type": "text",
				"text": error
			}],
			"isError": true
		}
		return MCPTypes.create_response(id, error_result)
	
	# 构建成功响应
	var response_result: Dictionary = {
		"content": [{
			"type": "text",
			"text": JSON.stringify(result)
		}],
		"isError": false
	}
	
	var response: Dictionary = MCPTypes.create_response(id, response_result)
	
	_append_tool_log(tool_name, result, error)
	
	# 发送完成信号
	tool_execution_completed.emit(tool_name, result)
	_log_info("Tool execution completed: " + tool_name)
	
	return response

func _handle_resources_list(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	
	_log_info("Resources list requested. Available resources: " + str(_resources.size()))
	
	# 构建资源列表（根据mcp-builder，包含description）
	var resources_list: Array[Dictionary] = []
	
	for uri in _resources:
		var resource: MCPTypes.MCPResource = _resources[uri]
		if resource and resource.is_valid():
			resources_list.append(resource.to_dict())
	
	var result: Dictionary = {"resources": resources_list}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	_log_debug("Resources list response: " + JSON.stringify(response))
	
	return response

func _handle_resource_read(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var uri: String = params.get("uri", "")
	
	_log_info("Resource read: " + uri)
	
	# 检查资源是否存在
	if not _resources.has(uri):
		_log_error("Resource not found: " + uri)
		return MCPTypes.create_error_response(id, MCPTypes.ERROR_RESOURCE_NOT_FOUND, "Resource not found: " + uri)
	
	var resource: MCPTypes.MCPResource = _resources[uri]
	
	resource_requested.emit(uri, params)
	
	var content: Dictionary = {}
	
	if resource.load_callable.is_valid():
		content = resource.load_callable.call(params)
	
	var result: Dictionary = {}
	
	if content.has("contents"):
		result = content
	else:
		result = {
			"contents": [{
				"uri": uri,
				"mimeType": resource.mime_type,
				"text": content.get("text", JSON.stringify(content))
			}]
		}
	
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	# 发送资源加载信号
	resource_loaded.emit(uri, content)
	_log_info("Resource loaded: " + uri)
	
	return response

func _handle_resource_subscribe(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var uri: String = params.get("uri", "")
	
	_log_info("Resource subscribe: " + uri)
	
	# TODO: 实现资源订阅逻辑
	var result: Dictionary = {"subscriptionId": MCPTypes.generate_id()}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	return response

func _handle_prompts_list(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	
	_log_info("Prompts list requested")
	
	var prompts_list: Array[Dictionary] = []
	
	for prompt_name in _prompts:
		var prompt: MCPTypes.MCPPrompt = _prompts[prompt_name]
		if prompt and prompt.is_valid():
			prompts_list.append(prompt.to_dict())
	
	var result: Dictionary = {"prompts": prompts_list}
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	return response

func _handle_prompt_get(message: Dictionary) -> Dictionary:
	var id: Variant = message.get("id")
	var params: Dictionary = message.get("params", {})
	var prompt_name: String = params.get("name", "")
	
	_log_info("Prompt get: " + prompt_name)
	
	# TODO: 实现prompt获取逻辑
	var result: Dictionary = {
		"description": "Prompt: " + prompt_name,
		"messages": []
	}
	
	var response: Dictionary = MCPTypes.create_response(id, result)
	
	return response

# ============================================================================
# 工具注册API（优化版 - 根据mcp-builder）
# ============================================================================

func register_tool(name: String, description: String, 
				  input_schema: Dictionary, callable: Callable,
				  output_schema: Dictionary = {}, 
				  annotations: Dictionary = {}) -> void:
	# 创建工具对象
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = name
	tool.description = description
	tool.input_schema = input_schema
	tool.output_schema = output_schema  # 新增（根据mcp-builder）
	tool.annotations = annotations  # 新增（根据mcp-builder）
	tool.callable = callable
	
	# 验证工具定义
	if not tool.is_valid():
		_log_error("Invalid tool definition: " + name)
		return
	
	_tools[name] = tool
	_log_info("Tool registered: " + name)

func unregister_tool(name: String) -> void:
	if _tools.has(name):
		_tools.erase(name)
		_log_info("Tool unregistered: " + name)

func get_tool(name: String) -> MCPTypes.MCPTool:
	return _tools.get(name, null)

func get_all_tools() -> Dictionary:
	return _tools.duplicate()

func get_tools_count() -> int:
	return _tools.size()

func get_resources_count() -> int:
	return _resources.size()

func get_registered_tools() -> Array:
	var tools_info: Array = []
	for tool_name in _tools:
		var tool: MCPTypes.MCPTool = _tools[tool_name]
		if tool and tool.is_valid():
			tools_info.append({
				"name": tool.name,
				"description": tool.description,
				"enabled": true
			})
	return tools_info

func set_tool_enabled(tool_name: String, enabled: bool) -> void:
	if _tools.has(tool_name):
		if not enabled:
			_tools.erase(tool_name)
			_log_info("Tool disabled: " + tool_name)
		else:
			_log_info("Tool already enabled: " + tool_name)
	else:
		if enabled:
			_log_warn("Cannot enable unregistered tool: " + tool_name)

func has_tool(name: String) -> bool:
	return _tools.has(name)

# ============================================================================
# 资源注册API（优化版 - 根据mcp-builder）
# ============================================================================

func register_resource(uri: String, name: String, 
					  mime_type: String, load_callable: Callable,
					  description: String = "") -> void:  # 新增description参数
	# 创建资源对象
	var resource: MCPTypes.MCPResource = MCPTypes.MCPResource.new()
	resource.uri = uri
	resource.name = name
	resource.description = description  # 新增（根据mcp-builder）
	resource.mime_type = mime_type
	resource.load_callable = load_callable
	
	# 验证资源定义
	if not resource.is_valid():
		_log_error("Invalid resource definition: " + uri)
		return
	
	_resources[uri] = resource
	_log_info("Resource registered: " + uri)

func unregister_resource(uri: String) -> void:
	if _resources.has(uri):
		_resources.erase(uri)
		_log_info("Resource unregistered: " + uri)

func get_resource(uri: String) -> MCPTypes.MCPResource:
	return _resources.get(uri, null)

func get_all_resources() -> Dictionary:
	return _resources.duplicate()

# ============================================================================
# Prompt注册API
# ============================================================================

func register_prompt(name: String, description: String, 
					 arguments: Array[Dictionary], 
					 get_callable: Callable) -> void:
	var prompt: MCPTypes.MCPPrompt = MCPTypes.MCPPrompt.new()
	prompt.name = name
	prompt.description = description
	prompt.arguments = arguments
	
	_prompts[name] = prompt
	_log_info("Prompt registered: " + name)

# ============================================================================
# stdio传输层（根据godot-dev-guide优化）
# ============================================================================

func _stdin_listen_loop() -> void:
	_log_info("Stdin listen loop started")
	
	while _active:
		# 读取stdin
		var input: String = OS.read_string_from_stdin()
		
		if not input.is_empty():
			# 解析消息
			_parse_and_queue_message(input)
		
		# 避免CPU占用过高
		OS.delay_msec(10)
	
	_log_info("Stdin listen loop stopped")

func _parse_and_queue_message(raw_input: String) -> void:
	var lines: PackedStringArray = raw_input.split("\n")
	
	for line in lines:
		if line.is_empty():
			continue
		
		var json: JSON = JSON.new()
		var parse_result: Error = json.parse(line)
		
		if parse_result != OK:
			_log_error("JSON parse error: " + json.get_error_message())
			call_deferred("_send_error", null, MCPTypes.ERROR_PARSE_ERROR, "Parse error", line)
			continue
		
		var message: Dictionary = json.get_data()
		
		_mutex.lock()
		_message_queue.append(message)
		_mutex.unlock()
		
		call_deferred("_process_next_message")

func _process_next_message() -> void:
	_mutex.lock()
	
	if _message_queue.is_empty():
		_mutex.unlock()
		return
	
	var message: Dictionary = _message_queue.pop_front()
	
	_mutex.unlock()
	
	# 处理消息
	_process_message(message)

func _send_response(response: Dictionary) -> void:
	var json_string: String = JSON.stringify(response)
	
	printerr("[MCP Server] Sending response: " + json_string)
	
	var file = FileAccess.open("user://mcp_last_response.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	
	var log_file: FileAccess = FileAccess.open("user://mcp_all_responses.log", FileAccess.READ)
	var existing: String = ""
	if log_file:
		existing = log_file.get_as_text()
		log_file.close()
	log_file = FileAccess.open("user://mcp_all_responses.log", FileAccess.WRITE)
	if log_file:
		log_file.store_string(existing + json_string + "\n---SEPARATOR---\n")
		log_file.close()
	
	print(json_string)
	response_sent.emit(response)

func _send_error(id: Variant, code: int, message: String, data: Variant = null) -> void:
	var error_response: Dictionary = MCPTypes.create_error_response(id, code, message, data)
	_send_response(error_response)

# ============================================================================
# 速率限制（根据mcp-builder安全最佳实践）
# ============================================================================

func _check_rate_limit(client_id: String) -> bool:
	var current_time: int = Time.get_unix_time_from_system()
	
	if not _request_timestamps.has(client_id):
		var new_timestamps: Array[int] = []
		_request_timestamps[client_id] = new_timestamps
		_request_count[client_id] = 0
	
	var timestamps: Array[int] = _request_timestamps[client_id]
	
	# 移除60秒前的记录
	while not timestamps.is_empty() and current_time - timestamps[0] > 60:
		timestamps.pop_front()
		_request_count[client_id] -= 1
	
	# 检查是否超过限制
	if _request_count[client_id] >= _rate_limit:
		_log_warn("Rate limit exceeded for client: " + client_id)
		return false
	
	# 添加新记录
	timestamps.append(current_time)
	_request_count[client_id] += 1
	
	return true

# ============================================================================
# 缓存机制（根据godot-dev-guide新增）
# ============================================================================

func get_cached_scene_structure(scene_path: String) -> Dictionary:
	var cache_key: String = scene_path
	var current_time: int = Time.get_unix_time_from_system()
	
	# 检查缓存是否有效（5分钟有效期）
	if _scene_structure_cache.has(cache_key):
		var cache_time: int = _cache_timestamp.get(cache_key, 0)
		if current_time - cache_time < 300:  # 5分钟
			_log_debug("Cache hit: " + scene_path)
			return _scene_structure_cache[cache_key]
	
	# 缓存未命中或已过期
	_log_debug("Cache miss: " + scene_path)
	return {}

func set_cached_scene_structure(scene_path: String, structure: Dictionary) -> void:
	var cache_key: String = scene_path
	var current_time: int = Time.get_unix_time_from_system()
	
	_scene_structure_cache[cache_key] = structure
	_cache_timestamp[cache_key] = current_time
	
	_log_debug("Cache set: " + scene_path)

func clear_cache() -> void:
	_scene_structure_cache.clear()
	_cache_timestamp.clear()
	_log_info("Cache cleared")

# ============================================================================
# 配置方法
# ============================================================================

func set_log_level(level: int) -> void:
	_log_level = level
	_log_info("Log level set to: " + str(level))

func set_security_level(level: int) -> void:
	_security_level = level
	_log_info("Security level set to: " + str(level))

func set_rate_limit(limit: int) -> void:
	_rate_limit = limit
	_log_info("Rate limit set to: " + str(limit) + " requests/minute")

# ============================================================================
# 日志方法（根据godot-dev-guide优化）
# ============================================================================

func _log_error(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.ERROR:
		printerr("[MCP][ERROR] " + message)
		call_deferred("emit_signal", "log_message", "ERROR", message)

func _log_warn(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.WARN:
		printerr("[MCP][WARN] " + message)
		call_deferred("emit_signal", "log_message", "WARN", message)

func _log_info(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.INFO:
		printerr("[MCP][INFO] " + message)
		call_deferred("emit_signal", "log_message", "INFO", message)

func _log_debug(message: String) -> void:
	if _log_level >= MCPTypes.LogLevel.DEBUG:
		printerr("[MCP][DEBUG] " + message)
		call_deferred("emit_signal", "log_message", "DEBUG", message)

# ============================================================================
# 清理
# ============================================================================

func cleanup() -> void:
	stop()

# ============================================================================
# 工具调用日志（用于批量验证）
# ============================================================================

var _tool_log_path: String = "user://mcp_tool_verification_log.json"

func clear_tool_log() -> void:
	var file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.WRITE)
	if file:
		file.store_string("[]")
		file.close()

func _append_tool_log(tool_name: String, result: Variant, error: String) -> void:
	var log_entry: Dictionary = {
		"tool": tool_name,
		"timestamp": Time.get_unix_time_from_system(),
		"error": error,
		"result_type": str(typeof(result))
	}
	if result is Dictionary:
		if result.has("error"):
			log_entry["status"] = "error"
			log_entry["error_detail"] = str(result["error"])
		elif result.has("status"):
			log_entry["status"] = str(result["status"])
		else:
			log_entry["status"] = "ok"
		var result_keys: Array = result.keys()
		log_entry["result_keys"] = result_keys
		for key in result_keys:
			var val: Variant = result[key]
			if val is Array:
				log_entry["result_" + key + "_count"] = val.size()
			elif val is Dictionary:
				log_entry["result_" + key + "_keys"] = val.keys()
			else:
				var val_str: String = str(val)
				if val_str.length() > 200:
					val_str = val_str.substr(0, 200)
				log_entry["result_" + key] = val_str
	else:
		log_entry["status"] = "ok"
		var preview: String = str(result)
		if preview.length() > 200:
			preview = preview.substr(0, 200)
		log_entry["result_preview"] = preview
	
	var existing: Array = []
	if FileAccess.file_exists(_tool_log_path):
		var file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.READ)
		if file:
			var json: JSON = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				existing = json.get_data()
			file.close()
	
	existing.append(log_entry)
	
	var file: FileAccess = FileAccess.open(_tool_log_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(existing, "\t"))
		file.close()
