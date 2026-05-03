extends "res://addons/gut/test.gd"

var _plugin_script: GDScript = null

func before_each():
	_plugin_script = load("res://addons/godot_mcp/mcp_server_native.gd")

func after_each():
	_plugin_script = null

func test_plugin_script_loads():
	assert_ne(_plugin_script, null, "Plugin script should load successfully")

func test_plugin_has_enter_tree():
	assert_true(_plugin_script.has_method("_enter_tree") or _plugin_script.get_script_method_list().any(func(m): return m.name == "_enter_tree"), "Should have _enter_tree method")

func test_plugin_has_exit_tree():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_exit_tree"), "Should have _exit_tree method")

func test_plugin_has_start_server():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("start_server"), "Should have start_server method")

func test_plugin_has_stop_server():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("stop_server"), "Should have stop_server method")

func test_plugin_has_get_server_status():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("get_server_status"), "Should have get_server_status method")

func test_find_files_recursive():
	var result: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if dir:
		_plugin_script._find_files_recursive(dir, ".tscn", result)
		assert_true(result.size() > 0, "Should find at least one .tscn file in the project")

func test_find_files_recursive_gd():
	var result: Array = []
	var dir: DirAccess = DirAccess.open("res://")
	if dir:
		_plugin_script._find_files_recursive(dir, ".gd", result)
		assert_true(result.size() > 0, "Should find at least one .gd file in the project")

func test_count_nodes():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child"
	root.add_child(child)
	var count: int = _plugin_script._count_nodes(root)
	assert_eq(count, 2, "Should count root + 1 child")

func test_get_node_tree():
	var root: Node = Node.new()
	root.name = "Root"
	add_child_autofree(root)
	var child: Node = Node.new()
	child.name = "Child1"
	root.add_child(child)
	var tree: Array = _plugin_script._get_node_tree(root, 1)
	assert_eq(tree.size(), 1, "Should have 1 child")
	assert_eq(tree[0]["name"], "Child1", "Child name should match")

func test_get_godot_version():
	var version: Dictionary = _plugin_script._get_godot_version()
	assert_true(version.has("version"), "Should have version key")
	assert_true(version.has("major"), "Should have major key")
	assert_true(version["major"] >= 4, "Godot major should be >= 4")

func test_plugin_name():
	var methods: Array = _plugin_script.get_script_method_list()
	var method_names: Array = methods.map(func(m): return m["name"])
	assert_true(method_names.has("_get_plugin_name"), "Should have _get_plugin_name method")
	assert_true(method_names.has("_has_main_screen"), "Should have _has_main_screen method for main screen plugin")
	assert_true(method_names.has("_make_visible"), "Should have _make_visible method for main screen plugin")
	assert_true(method_names.has("_get_plugin_icon"), "Should have _get_plugin_icon method for main screen plugin")
	assert_true(method_names.has("_create_main_screen_panel"), "Should have _create_main_screen_panel method")

func test_export_variables():
	var script_props: Array = _plugin_script.get_script_property_list()
	var prop_names: Array = script_props.map(func(p): return p["name"])
	assert_true(prop_names.has("auto_start"), "Should have auto_start export")
	assert_true(prop_names.has("transport_mode"), "Should have transport_mode export")
	assert_true(prop_names.has("http_port"), "Should have http_port export")
	assert_true(prop_names.has("auth_enabled"), "Should have auth_enabled export")
	assert_true(prop_names.has("log_level"), "Should have log_level export")
