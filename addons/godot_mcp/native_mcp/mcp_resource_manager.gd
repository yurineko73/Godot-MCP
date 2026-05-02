# mcp_resource_manager.gd
# MCP 资源管理器 - 负责注册和读取MCP资源
# 版本: 1.0
# 作者: AI Assistant
# 日期: 2026-05-01

class_name MCPResourceManager
extends RefCounted

# 信号
signal resource_registered(uri: String, name: String)
signal resource_read(uri: String, result: Dictionary)

# 常量
const JSONRPC_VERSION := "2.0"

# 资源注册表: uri -> {name, mimeType, load_callable}
var _resources: Dictionary = {}

# ===========================================
# 资源注册
# ===========================================

## 注册资源
func register_resource(uri: String, name: String, mime_type: String, load_callable: Callable) -> void:
	if _resources.has(uri):
		print("[MCPResourceManager] 警告: 资源已存在，将覆盖: " + uri)

	_resources[uri] = {
		"name": name,
		"mimeType": mime_type,
		"load": load_callable
	}

	resource_registered.emit(uri, name)
	print("[MCPResourceManager] 注册资源: " + uri + " (" + name + ")")

## 注销资源
func unregister_resource(uri: String) -> bool:
	if _resources.has(uri):
		_resources.erase(uri)
		print("[MCPResourceManager] 注销资源: " + uri)
		return true
	return false

## 获取资源列表
func list_resources() -> Array:
	var resource_list: Array = []

	for uri in _resources.keys():
		var resource_info: Dictionary = _resources[uri]
		resource_list.append({
			"uri": uri,
			"name": resource_info["name"],
			"mimeType": resource_info["mimeType"]
		})

	return resource_list

# ===========================================
# 资源读取
# ===========================================

## 读取资源
func read_resource(uri: String, params: Dictionary = {}) -> Dictionary:
	if not _resources.has(uri):
		return _error_response(null, -32602, "Resource not found: " + uri)

	var resource_info: Dictionary = _resources[uri]
	var load_callable: Callable = resource_info.get("load", Callable())

	if not load_callable.is_valid():
		return _error_response(null, -32603, "Resource load function not available")

	var result: Dictionary = load_callable.call(params)

	if result.has("error"):
		return _error_response(null, -32603, result.get("error"))

	return result

# ===========================================
# JSON-RPC 响应辅助函数
# ===========================================

## 成功响应
static func _success_response(id: Variant, result: Variant) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id,
		"result": result
	}

## 错误响应
static func _error_response(id: Variant, code: int, message: String) -> Dictionary:
	return {
		"jsonrpc": "2.0",
		"id": id,
		"error": {
			"code": code,
			"message": message
		}
	}

# ===========================================
# 调试功能
# ===========================================

## 获取注册的资源数量
func get_resource_count() -> int:
	return _resources.size()

## 打印所有注册的资源
func print_resources() -> void:
	print("[MCPResourceManager] 已注册的资源:")
	for uri in _resources.keys():
		var info: Dictionary = _resources[uri]
		print("  - " + uri + " (" + info["name"] + ")")
	print("  总计: " + str(_resources.size()) + " 个资源")
