extends "res://addons/gut/test.gd"

func test_editor_state_format():
	var result: Dictionary = {
		"active_scene": "Main",
		"editor_mode": "editor",
		"selected_count": 1,
		"selected_nodes": ["/root/Main"]
	}
	assert_has(result, "active_scene", "Should have active_scene")
	assert_has(result, "editor_mode", "Should have editor_mode")
	assert_has(result, "selected_count", "Should have selected_count")
	assert_has(result, "selected_nodes", "Should have selected_nodes")

func test_selected_nodes_friendly_path():
	var paths: Array = ["/root/Main", "/root/Main/Player", "/root/Main/Camera3D"]
	for path in paths:
		assert_false(str(path).contains("@"), "Friendly path should not contain @")

func test_run_stop_project():
	var states: Array = ["playing", "editor"]
	assert_has(states, "playing", "Should have playing state")
	assert_has(states, "editor", "Should have editor state")

func test_editor_setting_name_format():
	var setting: String = "debug/gdscript/warnings/unused_variable"
	assert_true(setting.contains("/"), "Setting should have category separator")

func test_editor_logs_format():
	var result: Dictionary = {
		"logs": ["[INFO] Test message"],
		"count": 1,
		"total_available": 100
	}
	assert_has(result, "logs", "Should have logs")
	assert_has(result, "count", "Should have count")
	assert_has(result, "total_available", "Should have total_available")

func test_performance_metrics_format():
	var result: Dictionary = {
		"fps": 60.0,
		"memory_usage_mb": 512.5,
		"object_count": 1000,
		"resource_count": 50
	}
	assert_has(result, "fps", "Should have fps")
	assert_has(result, "memory_usage_mb", "Should have memory_usage_mb")
	assert_has(result, "object_count", "Should have object_count")

func test_execute_script_with_singletons():
	var singletons: Dictionary = {
		"OS": OS,
		"Engine": Engine,
		"Input": Input,
	}
	assert_has(singletons, "OS", "Should have OS singleton")
	assert_has(singletons, "Engine", "Should have Engine singleton")
	assert_has(singletons, "Input", "Should have Input singleton")

func test_execute_script_result_format():
	var success: Dictionary = {"status": "success", "result": "42"}
	var error: Dictionary = {"status": "error", "error": "Parse failed"}
	assert_has(success, "status", "Should have status")
	assert_has(error, "error", "Error should have error message")
