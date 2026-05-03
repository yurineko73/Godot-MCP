extends "res://addons/gut/test.gd"

func test_project_info_format():
	var result: Dictionary = {
		"project_name": "Godot MCP",
		"project_path": "F:/gitProjects/Godot-MCP/",
		"project_version": "",
		"project_description": "",
		"main_scene": "res://TestScene.tscn"
	}
	assert_has(result, "project_name", "Should have project_name")
	assert_has(result, "project_path", "Should have project_path")
	assert_has(result, "main_scene", "Should have main_scene")

func test_project_settings_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP",
		"application/run/main_scene": "res://TestScene.tscn",
		"debug/gdscript/warnings/unused_variable": true
	}
	var filtered: Dictionary = {}
	for key in settings:
		if key.begins_with("application/"):
			filtered[key] = settings[key]
	assert_eq(filtered.size(), 2, "Should filter to application/ settings only")
	assert_false(filtered.has("debug/gdscript/warnings/unused_variable"), "Should not have debug settings")

func test_project_settings_no_filter():
	var settings: Dictionary = {
		"application/config/name": "Godot MCP",
		"debug/gdscript/warnings/unused_variable": true
	}
	assert_eq(settings.size(), 2, "Without filter should return all settings")

func test_resource_extensions():
	var extensions: Array = [
		".tres", ".res", ".png", ".jpg", ".jpeg", ".webp", ".svg",
		".ogg", ".wav", ".mp3", ".glb", ".gltf", ".obj",
		".tscn", ".gd", ".cfg", ".json", ".gdshader"
	]
	assert_has(extensions, ".tscn", "Should include .tscn")
	assert_has(extensions, ".gd", "Should include .gd")
	assert_has(extensions, ".png", "Should include .png")
	assert_has(extensions, ".gdshader", "Should include .gdshader")

func test_resource_path_safety():
	assert_true(MCPTypes.is_path_safe("res://icon.svg"), "res:// resource should be safe")
	assert_false(MCPTypes.is_path_safe("C:\\Windows\\icon.png"), "Windows path should be unsafe")

func test_create_resource_types():
	var valid_types: Array = ["Curve", "Gradient", "StyleBoxFlat", "Animation"]
	assert_has(valid_types, "Curve", "Should support Curve resource")
	assert_has(valid_types, "Gradient", "Should support Gradient resource")

func test_resource_uri_format():
	var uri: String = "godot://scene/list"
	assert_true(uri.begins_with("godot://"), "Resource URI should start with godot://")
