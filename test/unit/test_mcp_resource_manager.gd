extends "res://addons/gut/test.gd"

var _manager: MCPResourceManager = null

func before_each():
	_manager = MCPResourceManager.new()

func after_each():
	_manager = null

func test_register_resource():
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {"scenes": []})
	assert_eq(_manager.get_resource_count(), 1, "Should have 1 resource")

func test_register_multiple_resources():
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {})
	_manager.register_resource("godot://script/list", "Script List", "application/json", func(params): return {})
	assert_eq(_manager.get_resource_count(), 2, "Should have 2 resources")

func test_register_resource_overwrite():
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {"v": 1})
	_manager.register_resource("godot://scene/list", "Scene List v2", "application/json", func(params): return {"v": 2})
	assert_eq(_manager.get_resource_count(), 1, "Should still have 1 resource (overwritten)")

func test_unregister_resource():
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {})
	var result: bool = _manager.unregister_resource("godot://scene/list")
	assert_true(result, "Should return true for existing resource")
	assert_eq(_manager.get_resource_count(), 0, "Should have 0 resources after unregister")

func test_unregister_nonexistent():
	var result: bool = _manager.unregister_resource("godot://nonexistent")
	assert_false(result, "Should return false for nonexistent resource")

func test_list_resources():
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {})
	_manager.register_resource("godot://script/list", "Script List", "application/json", func(params): return {})
	var list: Array = _manager.list_resources()
	assert_eq(list.size(), 2, "Should list 2 resources")

func test_list_resources_format():
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {})
	var list: Array = _manager.list_resources()
	var first: Dictionary = list[0]
	assert_has(first, "uri", "Resource should have uri")
	assert_has(first, "name", "Resource should have name")
	assert_has(first, "mimeType", "Resource should have mimeType")

func test_read_resource():
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {"scenes": ["test.tscn"]})
	var result: Dictionary = _manager.read_resource("godot://scene/list")
	assert_has(result, "scenes", "Should return resource data")

func test_read_nonexistent_resource():
	var result: Dictionary = _manager.read_resource("godot://nonexistent")
	assert_has(result, "error", "Should return error for nonexistent resource")

func test_read_resource_callable_error():
	_manager.register_resource("godot://broken", "Broken", "application/json", func(params): return {"error": "load failed"})
	var result: Dictionary = _manager.read_resource("godot://broken")
	assert_has(result, "error", "Should return error when callable returns error")

func test_get_resource_count_empty():
	assert_eq(_manager.get_resource_count(), 0, "Should be 0 when empty")

func test_resource_registered_signal():
	watch_signals(_manager)
	_manager.register_resource("godot://scene/list", "Scene List", "application/json", func(params): return {})
	assert_signal_emitted(_manager, "resource_registered")
