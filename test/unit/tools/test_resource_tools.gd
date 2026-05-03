extends "res://addons/gut/test.gd"

var _resource_tools: RefCounted = null

func before_each():
	_resource_tools = load("res://addons/godot_mcp/tools/resource_tools_native.gd").new()

func after_each():
	_resource_tools = null

func test_resource_scene_list_format():
	var result: Dictionary = _resource_tools._resource_scene_list({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"].size(), 1, "Should have one content item")
	assert_eq(result["contents"][0]["uri"], "godot://scene/list", "URI should be godot://scene/list")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")

func test_resource_scene_list_has_text():
	var result: Dictionary = _resource_tools._resource_scene_list({})
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed is Dictionary, "Parsed text should be a Dictionary")
	assert_true(parsed.has("scenes"), "Should have scenes key")
	assert_true(parsed.has("count"), "Should have count key")
	assert_true(parsed.has("timestamp"), "Should have timestamp key")

func test_resource_script_list_format():
	var result: Dictionary = _resource_tools._resource_script_list({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://script/list", "URI should be godot://script/list")
	assert_eq(result["contents"][0]["mimeType"], "application/json", "MIME type should be application/json")

func test_resource_script_list_has_text():
	var result: Dictionary = _resource_tools._resource_script_list({})
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed.has("scripts"), "Should have scripts key")
	assert_true(parsed.has("count"), "Should have count key")

func test_resource_project_info_format():
	var result: Dictionary = _resource_tools._resource_project_info({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/info", "URI should be godot://project/info")
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed.has("name"), "Should have name key")
	assert_true(parsed.has("version"), "Should have version key")
	assert_true(parsed.has("godot_version"), "Should have godot_version key")

func test_resource_project_settings_format():
	var result: Dictionary = _resource_tools._resource_project_settings({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://project/settings", "URI should be godot://project/settings")
	var text: String = result["contents"][0]["text"]
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed != null, "Text should be valid JSON")
	assert_true(parsed.has("settings"), "Should have settings key")
	assert_true(parsed.has("count"), "Should have count key")

func test_resource_scene_current_no_editor():
	var result: Dictionary = _resource_tools._resource_scene_current({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://scene/current", "URI should be godot://scene/current")

func test_resource_script_current_no_editor():
	var result: Dictionary = _resource_tools._resource_script_current({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://script/current", "URI should be godot://script/current")

func test_resource_editor_state_no_editor():
	var result: Dictionary = _resource_tools._resource_editor_state({})
	assert_true(result.has("contents"), "Should have contents key")
	assert_eq(result["contents"][0]["uri"], "godot://editor/state", "URI should be godot://editor/state")

func test_count_nodes():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child1: Node = Node.new()
	child1.name = "Child1"
	var child2: Node = Node.new()
	child2.name = "Child2"
	root.add_child(child1)
	root.add_child(child2)
	var count: int = _resource_tools._count_nodes(root)
	assert_eq(count, 3, "Should count root + 2 children")

func test_count_nodes_nested():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	var grandchild: Node = Node.new()
	grandchild.name = "GrandChild"
	root.add_child(child)
	child.add_child(grandchild)
	var count: int = _resource_tools._count_nodes(root)
	assert_eq(count, 3, "Should count root + child + grandchild")

func test_get_node_tree():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child1"
	root.add_child(child)
	var tree: Array = _resource_tools._get_node_tree(root, 1)
	assert_eq(tree.size(), 1, "Should have 1 child at depth 1")
	assert_eq(tree[0]["name"], "Child1", "Child name should be Child1")
	assert_eq(tree[0]["type"], "Node", "Child type should be Node")

func test_get_node_tree_max_depth():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)
	var tree: Array = _resource_tools._get_node_tree(root, 0)
	assert_eq(tree.size(), 0, "Should have 0 children at depth 0 (max_depth=0)")

func test_get_godot_version():
	var version: Dictionary = _resource_tools._get_godot_version()
	assert_true(version.has("version"), "Should have version key")
	assert_true(version.has("major"), "Should have major key")
	assert_true(version.has("minor"), "Should have minor key")
	assert_true(version.has("patch"), "Should have patch key")
	assert_true(version["major"] >= 4, "Godot major version should be >= 4")

func test_register_resources():
	var server_core: RefCounted = load("res://addons/godot_mcp/native_mcp/mcp_server_core.gd").new()
	_resource_tools.register_resources(server_core)
	assert_eq(server_core.get_resources_count(), 7, "Should register 7 resources")
