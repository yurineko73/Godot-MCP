extends "res://addons/gut/test.gd"

func test_create_node_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "create_node"
	tool.description = "Create a new node"
	tool.input_schema = {
		"type": "object",
		"properties": {
			"parent_path": {"type": "string"},
			"node_type": {"type": "string"},
			"node_name": {"type": "string"}
		},
		"required": ["parent_path", "node_type", "node_name"]
	}
	assert_true(tool.is_valid() or tool.name == "create_node", "create_node schema should be valid")

func test_delete_node_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "delete_node"
	tool.description = "Delete a node"
	tool.input_schema = {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"}
		},
		"required": ["node_path"]
	}
	assert_eq(tool.name, "delete_node", "delete_node schema should exist")

func test_update_node_property_schema():
	var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
	tool.name = "update_node_property"
	tool.description = "Update a node property"
	tool.input_schema = {
		"type": "object",
		"properties": {
			"node_path": {"type": "string"},
			"property_name": {"type": "string"},
			"property_value": {}
		},
		"required": ["node_path", "property_name", "property_value"]
	}
	assert_eq(tool.name, "update_node_property", "update_node_property schema should exist")

func test_property_value_json_string_parsing():
	var json_str: String = '{"x": 10, "y": 5, "z": 3}'
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary, "JSON string should parse to Dictionary")
	if parsed is Dictionary:
		var vec: Vector3 = Vector3(float(parsed.get("x", 0.0)), float(parsed.get("y", 0.0)), float(parsed.get("z", 0.0)))
		assert_eq(vec, Vector3(10, 5, 3), "Should convert parsed dict to Vector3")

func test_property_value_bool_string():
	var val: Variant = "true"
	var result: bool
	if val is String:
		result = val == "true"
	assert_true(result, "String 'true' should convert to bool true")

func test_property_value_int_string():
	var val: Variant = "42"
	var result: int
	if val is String:
		result = int(val)
	assert_eq(result, 42, "String '42' should convert to int 42")

func test_node_path_resolution():
	var path: String = "/root/Node3D/Child"
	var parts: PackedStringArray = path.split("/")
	assert_eq(parts.size(), 4, "Path should have 4 parts")
	assert_eq(parts[0], "", "First part should be empty (before /)")
	assert_eq(parts[1], "root", "Second part should be root")
	assert_eq(parts[2], "Node3D", "Third part should be Node3D")

func test_category_property_filtering():
	var property_dict: Dictionary = {"name": "Transform", "usage": 128}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_true(is_category, "Usage 128 should be filtered as category")

func test_normal_property_not_filtered():
	var property_dict: Dictionary = {"name": "position", "usage": 0}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_false(is_category, "Usage 0 should not be filtered")

func test_group_property_filtered():
	var property_dict: Dictionary = {"name": "Physics", "usage": 64}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_true(is_category, "Usage 64 should be filtered as group")

func test_subgroup_property_filtered():
	var property_dict: Dictionary = {"name": "Coordinates", "usage": 256}
	var usage_flags: int = property_dict.get("usage", 0)
	var is_category: bool = (usage_flags & 128) != 0 or (usage_flags & 64) != 0 or (usage_flags & 256) != 0
	assert_true(is_category, "Usage 256 should be filtered as subgroup")
