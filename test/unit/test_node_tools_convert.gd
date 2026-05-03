extends "res://addons/gut/test.gd"

var _node_tools: RefCounted = null

func before_each():
	_node_tools = load("res://addons/godot_mcp/tools/node_tools_native.gd").new()

func after_each():
	_node_tools = null

func test_make_friendly_path_with_scene_root():
	var root: Node3D = Node3D.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node3D = Node3D.new()
	child.name = "Child"
	root.add_child(child)
	var result: String = _node_tools._make_friendly_path(child, root)
	assert_eq(result, "/root/Root/Child", "Should return friendly path for child")

func test_make_friendly_path_root_itself():
	var root: Node3D = Node3D.new()
	root.name = "Root"
	add_child_autofree(root)
	var result: String = _node_tools._make_friendly_path(root, root)
	assert_eq(result, "/root/Root", "Should return friendly path for root")

func test_make_friendly_path_no_scene_root():
	var node: Node3D = Node3D.new()
	node.name = "TestNode"
	add_child_autofree(node)
	var result: String = _node_tools._make_friendly_path(node, null)
	assert_true(result.contains("TestNode"), "Should contain node name even without scene root")

func test_make_friendly_path_nested():
	var root: Node3D = Node3D.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node3D = Node3D.new()
	child.name = "Child"
	var grandchild: Node3D = Node3D.new()
	grandchild.name = "GrandChild"
	root.add_child(child)
	child.add_child(grandchild)
	var result: String = _node_tools._make_friendly_path(grandchild, root)
	assert_eq(result, "/root/Root/Child/GrandChild", "Should return friendly path for nested node")

func test_convert_value_for_property_vector3_from_dict():
	var node: Node3D = Node3D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "position", {"x": 1.0, "y": 2.0, "z": 3.0})
	assert_eq(result, Vector3(1, 2, 3), "Should convert dict to Vector3")
	node.free()

func test_convert_value_for_property_vector3_from_string():
	var node: Node3D = Node3D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "position", "(1, 2, 3)")
	assert_eq(result, Vector3(1, 2, 3), "Should convert string to Vector3")
	node.free()

func test_convert_value_for_property_vector2_from_dict():
	var node: Node2D = Node2D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "position", {"x": 5.0, "y": 10.0})
	assert_eq(result, Vector2(5, 10), "Should convert dict to Vector2")
	node.free()

func test_convert_value_for_property_color_from_dict():
	var node: Node2D = Node2D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "modulate", {"r": 1.0, "g": 0.5, "b": 0.0, "a": 1.0})
	assert_eq(result, Color(1, 0.5, 0, 1), "Should convert dict to Color")
	node.free()

func test_convert_value_for_property_bool():
	var node: Node3D = Node3D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "visible", true)
	assert_eq(result, true, "Should pass through bool value")
	node.free()

func test_convert_value_for_property_bool_from_string():
	var node: Node3D = Node3D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "visible", "true")
	assert_eq(result, true, "Should convert string 'true' to bool")
	node.free()

func test_convert_value_for_property_int():
	var node: Node3D = Node3D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "process_mode", 1)
	assert_eq(result, 1, "Should pass through int value")
	node.free()

func test_convert_value_for_property_float_from_int():
	var node: Node3D = Node3D.new()
	var result: Variant = _node_tools._convert_value_for_property(node, "process_priority", 5)
	assert_eq(result, 5, "Should convert int to appropriate type")
	node.free()
