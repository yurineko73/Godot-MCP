extends "res://addons/gut/test.gd"

var _validator: PathValidator = null

func before_each():
	_validator = PathValidator.new()

func after_each():
	_validator = null

func test_validate_res_path():
	var result: Dictionary = PathValidator.validate_path("res://test.tscn")
	assert_true(result["valid"], "res:// path should be valid")
	assert_eq(result["sanitized"], "res://test.tscn", "Sanitized path should match")

func test_validate_res_subdir():
	var result: Dictionary = PathValidator.validate_path("res://scripts/player.gd")
	assert_true(result["valid"], "res:// subdirectory path should be valid")

func test_validate_user_path():
	var result: Dictionary = PathValidator.validate_path("user://save.dat")
	assert_true(result["valid"], "user:// path should be valid")

func test_reject_empty_path():
	var result: Dictionary = PathValidator.validate_path("")
	assert_false(result["valid"], "Empty path should be rejected")
	assert_ne(result["error"], "", "Should have error message")

func test_reject_path_traversal():
	var result: Dictionary = PathValidator.validate_path("res://../etc/passwd")
	assert_false(result["valid"], "Path traversal should be rejected")

func test_reject_absolute_linux_path():
	var result: Dictionary = PathValidator.validate_path("/etc/passwd")
	assert_false(result["valid"], "Absolute Linux path should be rejected")

func test_reject_windows_path():
	var result: Dictionary = PathValidator.validate_path("C:\\Windows\\System32")
	assert_false(result["valid"], "Windows path should be rejected")

func test_reject_home_directory():
	var result: Dictionary = PathValidator.validate_path("~/secret")
	assert_false(result["valid"], "Home directory path should be rejected")

func test_non_strict_allows_more():
	var result: Dictionary = PathValidator.validate_path("res://../escape.tscn", false)
	assert_true(result["valid"], "Non-strict mode should allow traversal patterns")

func test_validate_file_path_with_extension():
	var result: Dictionary = PathValidator.validate_file_path("res://script.gd", ["gd"])
	assert_true(result["valid"], "Allowed extension should pass")

func test_validate_file_path_wrong_extension():
	var result: Dictionary = PathValidator.validate_file_path("res://data.json", ["gd", "tscn"])
	assert_false(result["valid"], "Disallowed extension should be rejected")

func test_validate_directory_path():
	var result: Dictionary = PathValidator.validate_directory_path("res://scripts")
	assert_true(result["valid"], "Directory path should be valid")

func test_validate_directory_path_adds_slash():
	var result: Dictionary = PathValidator.validate_directory_path("res://scripts")
	assert_true(result["sanitized"].ends_with("/"), "Directory path should end with /")

func test_validate_paths_batch():
	var result: Dictionary = PathValidator.validate_paths([
		"res://test.tscn",
		"/etc/passwd",
		"user://save.dat"
	])
	assert_eq(result["valid"].size(), 2, "Should have 2 valid paths")
	assert_eq(result["invalid"].size(), 1, "Should have 1 invalid path")

func test_validate_path_with_signal_approved():
	watch_signals(_validator)
	_validator.set_strict_mode(true)
	var result: bool = _validator.validate_path_with_signal("res://test.tscn")
	assert_true(result, "Should return true for valid path")
	assert_signal_emitted(_validator, "path_approved")

func test_validate_path_with_signal_rejected():
	watch_signals(_validator)
	_validator.set_strict_mode(true)
	var result: bool = _validator.validate_path_with_signal("C:\\Windows")
	assert_false(result, "Should return false for invalid path")
	assert_signal_emitted(_validator, "path_rejected")

func test_set_strict_mode():
	_validator.set_strict_mode(false)
	assert_false(_validator._strict_mode, "Strict mode should be false")
	_validator.set_strict_mode(true)
	assert_true(_validator._strict_mode, "Strict mode should be true")

func test_add_allowed_extension():
	_validator.add_allowed_extension(".gd")
	assert_has(_validator._allowed_extensions, ".gd", "Should contain .gd")

func test_add_allowed_extension_no_duplicate():
	_validator.add_allowed_extension(".gd")
	_validator.add_allowed_extension(".gd")
	var count: int = 0
	for ext in _validator._allowed_extensions:
		if ext == ".gd":
			count += 1
	assert_eq(count, 1, "Should not have duplicates")

func test_clear_allowed_extensions():
	_validator.add_allowed_extension(".gd")
	_validator.clear_allowed_extensions()
	assert_eq(_validator._allowed_extensions.size(), 0, "Should be empty after clear")
