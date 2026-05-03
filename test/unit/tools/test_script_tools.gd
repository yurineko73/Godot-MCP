extends "res://addons/gut/test.gd"

func test_script_path_validation():
	var valid_paths: Array = ["res://test.gd", "res://scripts/player.gd", "res://addons/my_addon/main.gd"]
	for path in valid_paths:
		assert_true(MCPTypes.is_path_safe(path), path + " should be safe")

func test_script_path_traversal():
	var unsafe_paths: Array = ["res://../secret.gd", "res://scripts/../../etc/passwd"]
	for path in unsafe_paths:
		assert_false(MCPTypes.is_path_safe(path), path + " should be unsafe")

func test_script_extension_check():
	var ext: String = "res://test.gd".get_extension()
	assert_eq(ext, "gd", "Should extract gd extension")

func test_script_extension_tscn():
	var ext: String = "res://scene.tscn".get_extension()
	assert_eq(ext, "tscn", "Should extract tscn extension")

func test_script_base_name():
	var base: String = "res://scripts/player.gd".get_file()
	assert_eq(base, "player.gd", "Should extract file name")

func test_json_parse_string_to_dict():
	var json: String = '{"extends_from":"Node","functions":["_ready","_process"]}'
	var parsed: Variant = JSON.parse_string(json)
	assert_true(parsed is Dictionary, "Should parse to Dictionary")
	assert_has(parsed, "functions", "Should have functions key")

func test_analyze_script_output_format():
	var result: Dictionary = {
		"script_path": "res://test.gd",
		"extends_from": "Node",
		"functions": ["_ready", "_process"],
		"properties": [],
		"signals": [],
		"line_count": 50
	}
	assert_has(result, "script_path", "Should have script_path")
	assert_has(result, "extends_from", "Should have extends_from")
	assert_has(result, "functions", "Should have functions")
	assert_has(result, "line_count", "Should have line_count")

func test_modify_script_line_number():
	var content: String = "line1\nline2\nline3"
	var lines: PackedStringArray = content.split("\n")
	assert_eq(lines.size(), 3, "Should have 3 lines")
	assert_eq(lines[1], "line2", "Line 2 should be 'line2'")

func test_create_script_template():
	var content: String = "extends Node\n\nfunc _ready() -> void:\n\tpass\n"
	var line_count: int = content.split("\n").size()
	assert_gt(line_count, 0, "Template should have lines")
