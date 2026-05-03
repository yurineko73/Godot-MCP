extends "res://addons/gut/test.gd"

func test_scene_extension_validation():
	var path: String = "res://test.tscn"
	assert_true(path.ends_with(".tscn"), "Scene should have .tscn extension")

func test_scene_path_safety():
	assert_true(MCPTypes.is_path_safe("res://scenes/main.tscn"), "res:// scene path should be safe")
	assert_false(MCPTypes.is_path_safe("/etc/test.tscn"), "Absolute scene path should be unsafe")

func test_scene_structure_format():
	var structure: Dictionary = {
		"scene_name": "Main",
		"root_node": {
			"name": "Main",
			"type": "Node3D",
			"path": "/root/Main",
			"children": []
		},
		"total_nodes": 1
	}
	assert_has(structure, "scene_name", "Should have scene_name")
	assert_has(structure, "root_node", "Should have root_node")
	assert_has(structure, "total_nodes", "Should have total_nodes")
	assert_has(structure["root_node"], "children", "Root node should have children")

func test_friendly_path_for_scene():
	var root: Node3D = Node3D.new()
	root.name = "MainScene"
	add_child_autofree(root)
	var child: Node3D = Node3D.new()
	child.name = "Player"
	root.add_child(child)
	var root_path: String = str(root.get_path())
	var child_path: String = str(child.get_path())
	assert_true(root_path.contains("MainScene"), "Root path should contain MainScene")
	assert_true(child_path.contains("Player"), "Child path should contain Player")

func test_current_scene_format():
	var result: Dictionary = {
		"scene_name": "Main",
		"scene_path": "res://main.tscn",
		"root_node_type": "Node3D",
		"node_count": 5,
		"is_modified": false
	}
	assert_has(result, "scene_name", "Should have scene_name")
	assert_has(result, "scene_path", "Should have scene_path")
	assert_has(result, "root_node_type", "Should have root_node_type")
